import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;

  BoundingBox({
    required this.x, 
    required this.y, 
    required this.width, 
    required this.height, 
    required this.confidence
  });

  // Calculate Intersection over Union (IoU)
  double iou(BoundingBox other) {
    final double x1 = max(x, other.x);
    final double y1 = max(y, other.y);
    final double x2 = min(x + width, other.x + other.width);
    final double y2 = min(y + height, other.y + other.height);

    if (x2 < x1 || y2 < y1) return 0.0;

    final double intersection = (x2 - x1) * (y2 - y1);
    final double area1 = width * height;
    final double area2 = other.width * other.height;

    return intersection / (area1 + area2 - intersection);
  }
}

class LeafDetector {
  Interpreter? _interpreter;
  bool _isLoaded = false;

  Future<void> loadModel() async {
    if (_isLoaded) return;
    try {
      final options = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset(
        'assets/models/tomato_leaf.tflite', 
        options: options
      );
      _isLoaded = true;
      debugPrint("LeafDetector: Model loaded successfully.");
    } catch (e) {
      debugPrint("LeafDetector: Failed to load model: $e");
    }
  }

  void dispose() {
    _interpreter?.close();
    _isLoaded = false;
  }

  /// Run inference on a camera frame and return the best bounding box.
  /// The box coordinates are normalized [0.0, 1.0].
  Future<BoundingBox?> detect(CameraImage cameraImage) async {
    if (!_isLoaded || _interpreter == null) return null;

    // Run the heavy preprocessing and inference on an isolate
    return await compute(_processAndRunInference, {
      'image': cameraImage,
      'address': _interpreter!.address, // pass memory address for isolate
    });
  }

  static BoundingBox? _processAndRunInference(Map<String, dynamic> args) {
    final CameraImage cameraImage = args['image'];
    final int address = args['address'];
    final Interpreter interpreter = Interpreter.fromAddress(address);

    try {
      // 1. Convert CameraImage to RGB Image
      img.Image? image = _convertCameraImage(cameraImage);
      if (image == null) return null;

      // 2. Resize and pad (letterbox) to 320x320
      // For simplicity in live feed, we can just center crop or resize directly.
      // A direct resize to 320x320 is faster for live preview.
      final img.Image resized = img.copyResize(image, width: 320, height: 320);

      // 3. Normalize input to [1, 3, 320, 320] float32 array in NCHW format
      final Float32List inputTensor = Float32List(1 * 3 * 320 * 320);
      const int channelSize = 320 * 320;
      
      for (int y = 0; y < 320; y++) {
        for (int x = 0; x < 320; x++) {
          final pixel = resized.getPixel(x, y);
          final int spatialIndex = y * 320 + x;
          // YOLOv8 expects normalized [0, 1] RGB in NCHW format
          inputTensor[0 * channelSize + spatialIndex] = pixel.r / 255.0; // R
          inputTensor[1 * channelSize + spatialIndex] = pixel.g / 255.0; // G
          inputTensor[2 * channelSize + spatialIndex] = pixel.b / 255.0; // B
        }
      }
      final inputList = inputTensor.reshape([1, 3, 320, 320]);

      // 4. Output tensor setup. 
      // YOLOv8 typical output for 1 class is [1, 5, 2100] (xc, yc, w, h, conf)
      final outputTensorShape = interpreter.getOutputTensor(0).shape;
      final bool isTransposed = outputTensorShape[1] == 5; // [1, 5, 2100]
      final int numAnchors = isTransposed ? outputTensorShape[2] : outputTensorShape[1];

      final outputList = isTransposed 
          ? List.generate(1, (_) => List.generate(5, (_) => List.filled(numAnchors, 0.0)))
          : List.generate(1, (_) => List.generate(numAnchors, (_) => List.filled(5, 0.0)));

      // 5. Run inference
      interpreter.run(inputList, outputList);

      // 6. Decode and NMS
      List<BoundingBox> boxes = [];
      double maxConfSeen = 0.0;

      for (int i = 0; i < numAnchors; i++) {
        final double xc = isTransposed ? outputList[0][0][i] : outputList[0][i][0];
        final double yc = isTransposed ? outputList[0][1][i] : outputList[0][i][1];
        final double w = isTransposed ? outputList[0][2][i] : outputList[0][i][2];
        final double h = isTransposed ? outputList[0][3][i] : outputList[0][i][3];
        final double rawConf = isTransposed ? outputList[0][4][i] : outputList[0][i][4];

        // Apply Sigmoid if logits are raw (outside 0..1 range)
        final double conf = (rawConf > 1.0 || rawConf < 0.0) 
            ? (1.0 / (1.0 + exp(-rawConf))) 
            : rawConf;

        if (conf > maxConfSeen) maxConfSeen = conf;

        if (conf >= 0.80) { // Require 80%+ confidence for leaf detection
          // Normalize coordinates safely (handling both normalized 0..1 and pixel coords 0..320)
          final double normXc = xc > 1.0 ? (xc / 320.0) : xc;
          final double normYc = yc > 1.0 ? (yc / 320.0) : yc;
          final double normW = w > 1.0 ? (w / 320.0) : w;
          final double normH = h > 1.0 ? (h / 320.0) : h;

          final double left = (normXc - normW / 2.0).clamp(0.0, 1.0);
          final double top = (normYc - normH / 2.0).clamp(0.0, 1.0);
          final double boxWidth = normW.clamp(0.0, 1.0 - left);
          final double boxHeight = normH.clamp(0.0, 1.0 - top);

          boxes.add(BoundingBox(
            x: left,
            y: top,
            width: boxWidth,
            height: boxHeight,
            confidence: conf,
          ));
        }
      }

      if (boxes.isEmpty) {
        return null;
      }

      // Apply NMS (sort by confidence descending)
      boxes.sort((a, b) => b.confidence.compareTo(a.confidence));
      final List<BoundingBox> nmsBoxes = [];

      for (final box in boxes) {
        bool keep = true;
        for (final keptBox in nmsBoxes) {
          if (box.iou(keptBox) > 0.45) { // IOU Threshold
            keep = false;
            break;
          }
        }
        if (keep) {
          nmsBoxes.add(box);
        }
      }

      // Return the best box
      return nmsBoxes.isNotEmpty ? nmsBoxes.first : null;

    } catch (e) {
      debugPrint("LeafDetector error: $e");
      return null;
    }
  }

  static img.Image? _convertCameraImage(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888(image);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static img.Image _convertBGRA8888(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  static img.Image _convertYUV420(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image rgbImage = img.Image(width: width, height: height);

    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      int pY = y * image.planes[0].bytesPerRow;
      int pUV = (y >> 1) * uvRowStride;

      for (int x = 0; x < width; x++) {
        final int uvOffset = pUV + (x >> 1) * uvPixelStride;

        final int yValue = image.planes[0].bytes[pY];
        final int uValue = image.planes[1].bytes[uvOffset];
        final int vValue = image.planes[2].bytes[uvOffset];

        int r = (yValue + 1.402 * (vValue - 128)).toInt();
        int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).toInt();
        int b = (yValue + 1.772 * (uValue - 128)).toInt();

        rgbImage.setPixelRgb(
          x, y, 
          r.clamp(0, 255), 
          g.clamp(0, 255), 
          b.clamp(0, 255)
        );
        pY++;
      }
    }
    // Rotate image if needed on Android/iOS (usually portrait means rotating 90 degrees)
    // For live preview processing, we usually want to rotate it so it matches what we see
    return img.copyRotate(rgbImage, angle: 90);
  }
}
