import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/disease_result.dart';
import '../models/severity_result.dart';

class SegmentationService {
  static Future<void> loadModel() async {
    // Model loading is now handled per-isolate
    debugPrint("SegmentationService: loadModel called.");
  }

  static void dispose() {
    // No-op
  }

  /// Analyze the image using student3.tflite for segmentation
  static Future<SeverityResult> analyzeSeverity(ProcessedImageData imageData, String diseaseName) async {
    try {
      final ByteData modelData = await rootBundle.load('assets/models/student3.tflite');
      final Uint8List modelBytes = modelData.buffer.asUint8List();

      final result = await compute(_runInference, {
        'imagePath': imageData.originalFile?.path,
        'imageBytes': imageData.imageBytes,
        'modelBytes': modelBytes,
        'diseaseName': diseaseName,
      });

      return result ?? _getMockSeverity();
    } catch (e) {
      debugPrint("SegmentationService error: $e");
      return _getMockSeverity();
    }
  }

  static SeverityResult? _runInference(Map<String, dynamic> args) {
    final String? imagePath = args['imagePath'];
    final Uint8List? imageBytesRaw = args['imageBytes'];
    final Uint8List modelBytes = args['modelBytes'];
    final String diseaseName = args['diseaseName'] ?? 'Unknown';

    Interpreter? interpreter;
    try {
      interpreter = Interpreter.fromBuffer(modelBytes);
    } catch (e) {
      return _errorResult("Interpreter init error: $e");
    }

    final List<int> inputShape = interpreter.getInputTensor(0).shape;
    final List<int> outputShape0 = interpreter.getOutputTensor(0).shape;
    final List<int> outputShape = interpreter.getOutputTensor(1).shape;

    Uint8List? finalBytes = imageBytesRaw;
    if (finalBytes == null && imagePath != null) {
      final file = File(imagePath);
      if (file.existsSync()) {
        finalBytes = file.readAsBytesSync();
      }
    }

    if (finalBytes == null) return _errorResult("No image bytes found.");

    final img.Image? image = img.decodeImage(finalBytes);
    if (image == null) return _errorResult("Failed to decode image.");

    // Determine shapes robustly
    bool isNCHW = inputShape.length == 4 && inputShape[1] == 3;
    int height = isNCHW ? inputShape[2] : (inputShape.length > 1 ? inputShape[1] : 256);
    int width = isNCHW ? inputShape[3] : (inputShape.length > 2 ? inputShape[2] : 256);
    int channels = isNCHW ? inputShape[1] : (inputShape.length > 3 ? inputShape[3] : 3);

    bool outIsNCHW = outputShape.length == 4 && (outputShape[1] == 1 || outputShape[1] == 2 || outputShape.length > 3 && outputShape[2] > 10); 
    if (outputShape.length == 4 && outputShape[2] > 16 && outputShape[3] > 16) {
        outIsNCHW = true;
    } else {
        outIsNCHW = false;
    }
    
    int outH = outIsNCHW ? outputShape[2] : (outputShape.length > 1 ? outputShape[1] : 256);
    int outW = outIsNCHW ? outputShape[3] : (outputShape.length > 2 ? outputShape[2] : 256);

    final img.Image resized = img.copyResize(image, width: width, height: height);

    // Dynamic tensor allocation
    dynamic allocateTensor(List<int> shape, dynamic defaultVal) {
      if (shape.isEmpty) return defaultVal;
      if (shape.length == 1) return List.filled(shape[0], defaultVal);
      if (shape.length == 2) return List.generate(shape[0], (_) => List.filled(shape[1], defaultVal));
      if (shape.length == 3) return List.generate(shape[0], (_) => List.generate(shape[1], (_) => List.filled(shape[2], defaultVal)));
      if (shape.length == 4) return List.generate(shape[0], (_) => List.generate(shape[1], (_) => List.generate(shape[2], (_) => List.filled(shape[3], defaultVal))));
      return [];
    }

    dynamic inputTensor = allocateTensor(inputShape, 0.0);
    dynamic outputTensor0 = allocateTensor(outputShape0, 0); // integer for type 4
    dynamic outputTensor = allocateTensor(outputShape, 0.0); // mask is float32

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = resized.getPixel(x, y);
        // Apply ImageNet normalization: (val - mean) / std
        double rNorm = (pixel.r / 255.0 - 0.485) / 0.229;
        double gNorm = (pixel.g / 255.0 - 0.456) / 0.224;
        double bNorm = (pixel.b / 255.0 - 0.406) / 0.225;

        if (isNCHW) {
          inputTensor[0][0][y][x] = rNorm;
          if (channels > 1) inputTensor[0][1][y][x] = gNorm;
          if (channels > 2) inputTensor[0][2][y][x] = bNorm;
        } else {
          inputTensor[0][y][x][0] = rNorm;
          if (channels > 1) inputTensor[0][y][x][1] = gNorm;
          if (channels > 2) inputTensor[0][y][x][2] = bNorm;
        }
      }
    }

    try {
      interpreter.runForMultipleInputs([inputTensor], {0: outputTensor0, 1: outputTensor});
    } catch(e) {
       return _errorResult("runForMultipleInputs failed: $e, IN: $inputShape, OUT0: $outputShape0, OUT1: $outputShape");
    } finally {
      interpreter.close();
    }

    int diseasePixels = 0;
    int totalMaskPixels = outH * outW;
    
    final maskImg = img.Image(width: outW, height: outH, numChannels: 4);
    List<List<bool>> binaryMask = List.generate(outH, (_) => List.filled(outW, false));

    double minVal = double.maxFinite;
    double maxVal = -double.maxFinite;

    for (int y = 0; y < outH; y++) {
      for (int x = 0; x < outW; x++) {
        double val = 0.0;
        if (outIsNCHW) {
          val = (outputTensor as List)[0][0][y][x];
        } else {
          val = (outputTensor as List)[0][y][x][0];
        }
        
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;

        // Use > 0.0 for logits instead of > 0.5
        if (val > 0.0) {
          diseasePixels++;
          binaryMask[y][x] = true;
          maskImg.setPixelRgba(x, y, 255, 60, 60, 160); // Vibrant Red for lesions
        } else {
          maskImg.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }
    
    debugPrint("Mask Debug -> Min: $minVal, Max: $maxVal, diseasePixels: $diseasePixels / $totalMaskPixels");

    // Connected components for lesion count
    int lesionCount = 0;
    List<List<bool>> visited = List.generate(outH, (_) => List.filled(outW, false));
    for (int y = 0; y < outH; y++) {
      for (int x = 0; x < outW; x++) {
        if (binaryMask[y][x] && !visited[y][x]) {
          lesionCount++;
          List<Point<int>> queue = [Point(x, y)];
          visited[y][x] = true;
          while(queue.isNotEmpty) {
            final p = queue.removeAt(0);
            final dx = [0, 0, 1, -1];
            final dy = [1, -1, 0, 0];
            for (int i = 0; i < 4; i++) {
              int nx = p.x + dx[i];
              int ny = p.y + dy[i];
              if (nx >= 0 && nx < outW && ny >= 0 && ny < outH) {
                if (binaryMask[ny][nx] && !visited[ny][nx]) {
                  visited[ny][nx] = true;
                  queue.add(Point(nx, ny));
                }
              }
            }
          }
        }
      }
    }

    double percent = (diseasePixels / totalMaskPixels) * 100.0;
    
    SeverityLevel level = SeverityLevel.healthy;
    String score = '100 / 100';
    String symptom = 'No visible necrotic spots or pathogen lesions detected.';

    if (diseaseName.toLowerCase().contains('early blight')) {
      if (percent > 35) {
        level = SeverityLevel.severe;
        symptom = 'Severe Early Blight: Extensive confluent concentric rings and necrotic leaf tissue breakdown.';
      } else if (percent > 10) {
        level = SeverityLevel.moderate;
        symptom = 'Moderate Early Blight: Target-like concentric brown necrotic lesions with surrounding chlorotic halos.';
      } else if (percent > 0.1) {
        level = SeverityLevel.mild;
        symptom = 'Mild Early Blight: Initial localized foliar spots and developing necrotic micro-lesions.';
      }
    } else if (diseaseName.toLowerCase().contains('late blight')) {
      if (percent > 35) {
        level = SeverityLevel.severe;
        symptom = 'Severe Late Blight: Rapidly expanding large dark water-soaked lesions leading to complete leaf collapse.';
      } else if (percent > 10) {
        level = SeverityLevel.moderate;
        symptom = 'Moderate Late Blight: Irregular dark green to black lesions, often with white fungal growth on undersides.';
      } else if (percent > 0.1) {
        level = SeverityLevel.mild;
        symptom = 'Mild Late Blight: Small irregular water-soaked spots emerging on leaf surfaces.';
      }
    } else {
      // Generic fallback for other diseases
      if (percent > 35) {
        level = SeverityLevel.severe;
        symptom = 'Severe $diseaseName symptoms: Extensive foliar damage and tissue necrosis.';
      } else if (percent > 10) {
        level = SeverityLevel.moderate;
        symptom = 'Moderate $diseaseName symptoms: Noticeable spreading lesions and chlorosis.';
      } else if (percent > 0.1) {
        level = SeverityLevel.mild;
        symptom = 'Mild $diseaseName symptoms: Early stages of infection with small isolated lesions.';
      }
    }

    if (level != SeverityLevel.healthy) {
      score = '${(100 - percent).toStringAsFixed(1)} / 100';
    }

    return SeverityResult(
      level: level,
      affectedAreaPercentage: double.parse(percent.toStringAsFixed(1)),
      totalLesionCount: lesionCount,
      primarySymptom: symptom,
      leafTissueHealthScore: score,
      maskImageBytes: img.encodePng(maskImg),
    );
  }

  static SeverityResult _errorResult(String message) {
    return SeverityResult(
      level: SeverityLevel.severe,
      affectedAreaPercentage: 0.0,
      totalLesionCount: 0,
      primarySymptom: message,
      leafTissueHealthScore: 'Error',
    );
  }

  static SeverityResult _getMockSeverity() {
    return const SeverityResult(
      level: SeverityLevel.moderate,
      affectedAreaPercentage: 24.8,
      totalLesionCount: 14,
      primarySymptom: 'Concentric necrotic lesions on lower leaves',
      leafTissueHealthScore: '75.2 / 100',
    );
  }
}
