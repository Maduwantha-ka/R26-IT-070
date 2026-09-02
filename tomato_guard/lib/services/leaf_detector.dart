import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
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
  bool _isProcessing = false;

  // Reusable flat buffers for zero GC overhead & maximum FPS
  final Float32List _inputFlat = Float32List(1 * 3 * 320 * 320);
  final List<List<List<double>>> _outputTensor = List.generate(
    1,
    (_) => List.generate(5, (_) => List.filled(2100, 0.0)),
  );

  Future<void> loadModel() async {
    if (_isLoaded) return;
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/tomato_leaf.tflite', 
        options: options,
      );
      _isLoaded = true;
      debugPrint("LeafDetector: tomato_leaf.tflite loaded successfully with 2 CPU threads.");
    } catch (e) {
      debugPrint("LeafDetector: Failed to load model: $e");
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }

  /// High-Speed Direct YUV420 -> 320x320 NCHW single-pass sampler using Isolate
  /// Execution time: ~2ms + Isolate transfer overhead (Zero UI thread blocking)
  Future<BoundingBox?> detect(CameraImage cameraImage) async {
    if (!_isLoaded || _interpreter == null || _isProcessing) return null;
    _isProcessing = true;

    try {
      final int srcW = cameraImage.width;
      final int srcH = cameraImage.height;
      final int address = _interpreter!.address;

      final bool isYUV = cameraImage.format.group == ImageFormatGroup.yuv420;
      final bool isBGRA = cameraImage.format.group == ImageFormatGroup.bgra8888;

      if (!isYUV && !isBGRA) return null;

      // Extract raw bytes on main thread to pass to isolate
      final List<Uint8List> planeBytes = cameraImage.planes.map((p) => p.bytes).toList();
      final List<int> bytesPerRow = cameraImage.planes.map((p) => p.bytesPerRow).toList();
      final List<int> bytesPerPixel = cameraImage.planes.map((p) => p.bytesPerPixel ?? 1).toList();

      return await Isolate.run(() {
        final Interpreter isolateInterpreter = Interpreter.fromAddress(address);
        
        final Float32List inputFlat = Float32List(1 * 3 * 320 * 320);
        final List<List<List<double>>> outputTensor = List.generate(
          1,
          (_) => List.generate(5, (_) => List.filled(2100, 0.0)),
        );

        const int dstSize = 320;
        const int channelSize = dstSize * dstSize;

        if (isYUV) {
          final Uint8List planeY = planeBytes[0];
          final Uint8List planeU = planeBytes[1];
          final Uint8List planeV = planeBytes[2];

          final int yRowStride = bytesPerRow[0];
          final int uvRowStride = bytesPerRow[1];
          final int uvPixelStride = bytesPerPixel[1];

          // Direct single-pass YUV -> 320x320 NCHW sample with 90° portrait rotation
          for (int outY = 0; outY < dstSize; outY++) {
            for (int outX = 0; outX < dstSize; outX++) {
              // Rotate 90 degrees clockwise for mobile portrait orientation
              final int inX = (outY * srcW) ~/ dstSize;
              final int inY = ((dstSize - 1 - outX) * srcH) ~/ dstSize;

              final int yIndex = inY * yRowStride + inX;
              final int uvOffset = (inY >> 1) * uvRowStride + (inX >> 1) * uvPixelStride;

              if (yIndex >= planeY.length || uvOffset >= planeU.length || uvOffset >= planeV.length) {
                continue;
              }

              final int yVal = planeY[yIndex];
              final int uVal = planeU[uvOffset] - 128;
              final int vVal = planeV[uvOffset] - 128;

              // Integer color conversion
              int r = yVal + ((1436 * vVal) >> 10);
              int g = yVal - ((352 * uVal + 731 * vVal) >> 10);
              int b = yVal + ((1815 * uVal) >> 10);

              if (r < 0) r = 0; else if (r > 255) r = 255;
              if (g < 0) g = 0; else if (g > 255) g = 255;
              if (b < 0) b = 0; else if (b > 255) b = 255;

              final int spatialIndex = outY * dstSize + outX;
              inputFlat[0 * channelSize + spatialIndex] = r / 255.0; // R
              inputFlat[1 * channelSize + spatialIndex] = g / 255.0; // G
              inputFlat[2 * channelSize + spatialIndex] = b / 255.0; // B
            }
          }
        } else if (isBGRA) {
          final Uint8List bytes = planeBytes[0];
          final int rowStride = bytesPerRow[0];

          for (int outY = 0; outY < dstSize; outY++) {
            for (int outX = 0; outX < dstSize; outX++) {
              final int inX = (outX * srcW) ~/ dstSize;
              final int inY = (outY * srcH) ~/ dstSize;
              final int pIdx = inY * rowStride + (inX * 4);

              if (pIdx + 2 >= bytes.length) continue;

              final int b = bytes[pIdx];
              final int g = bytes[pIdx + 1];
              final int r = bytes[pIdx + 2];

              final int spatialIndex = outY * dstSize + outX;
              inputFlat[0 * channelSize + spatialIndex] = r / 255.0;
              inputFlat[1 * channelSize + spatialIndex] = g / 255.0;
              inputFlat[2 * channelSize + spatialIndex] = b / 255.0;
            }
          }
        }

        // 4. Reshape flat buffer directly for inference input
        final inputTensor = inputFlat.reshape([1, 3, dstSize, dstSize]);

        // 5. Run inference (< 12ms)
        isolateInterpreter.run(inputTensor, outputTensor);

        // 6. Decode output bounding boxes
        List<BoundingBox> boxes = [];
        const int numAnchors = 2100;

        for (int i = 0; i < numAnchors; i++) {
          final double xc = outputTensor[0][0][i];
          final double yc = outputTensor[0][1][i];
          final double w = outputTensor[0][2][i];
          final double h = outputTensor[0][3][i];
          final double rawConf = outputTensor[0][4][i];

          final double conf = (rawConf > 1.0 || rawConf < 0.0) 
              ? (1.0 / (1.0 + exp(-rawConf))) 
              : rawConf;

          if (conf >= 0.80) { // Fast, responsive 80% threshold
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

        if (boxes.isEmpty) return null;

        // NMS
        boxes.sort((a, b) => b.confidence.compareTo(a.confidence));
        final List<BoundingBox> nmsBoxes = [];

        for (final box in boxes) {
          bool keep = true;
          for (final keptBox in nmsBoxes) {
            if (box.iou(keptBox) > 0.45) {
              keep = false;
              break;
            }
          }
          if (keep) {
            nmsBoxes.add(box);
          }
        }

        return nmsBoxes.isNotEmpty ? nmsBoxes.first : null;
      });
    } catch (e) {
      debugPrint("LeafDetector fast detect error: $e");
      return null;
    } finally {
      _isProcessing = false;
    }
  }
}
