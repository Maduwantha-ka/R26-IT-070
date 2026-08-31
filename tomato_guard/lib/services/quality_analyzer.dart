import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'leaf_detector.dart';

enum CaptureQuality { good, fair, poor }

class QualityAnalysisResult {
  final CaptureQuality quality;
  final String message;

  const QualityAnalysisResult(this.quality, this.message);
}

class QualityAnalyzer {
  /// Analyzes the camera image and leaf bounding box to return a quality result.
  static Future<QualityAnalysisResult> analyze(CameraImage image, BoundingBox? leafBox) async {
    // We still compute the brightness/blur on an isolate
    final environmentQuality = await compute(_analyzeEnvironment, image);
    
    // If environment is poor (blur, lighting), return that first (unless no leaf is even detected)
    
    if (leafBox == null || leafBox.confidence < 0.80) {
      return const QualityAnalysisResult(CaptureQuality.poor, "No tomato leaf detected. Point the camera at a tomato leaf.");
    }

    final double boxArea = leafBox.width * leafBox.height;
    
    // Area check (relaxed for realistic camera distances)
    if (boxArea < 0.05) {
      return const QualityAnalysisResult(CaptureQuality.fair, "Move closer to the leaf");
    }
    if (boxArea > 0.85) {
      return const QualityAnalysisResult(CaptureQuality.fair, "Move back a little");
    }

    // Center check with directional guidance
    final double boxCenterX = leafBox.x + (leafBox.width / 2);
    final double boxCenterY = leafBox.y + (leafBox.height / 2);
    
    if (boxCenterX < 0.28) {
      return const QualityAnalysisResult(CaptureQuality.fair, "Leaf is too far left. Center the leaf");
    }
    if (boxCenterX > 0.72) {
      return const QualityAnalysisResult(CaptureQuality.fair, "Leaf is too far right. Center the leaf");
    }
    if (boxCenterY < 0.22) {
      return const QualityAnalysisResult(CaptureQuality.fair, "Leaf is too high. Move camera down");
    }
    if (boxCenterY > 0.78) {
      return const QualityAnalysisResult(CaptureQuality.fair, "Leaf is too low. Move camera up");
    }

    // If leaf is good, check the environment quality
    if (environmentQuality != null) {
      return environmentQuality;
    }

    // If everything passes
    return const QualityAnalysisResult(CaptureQuality.good, "Perfect! You can capture now");
  }

  static QualityAnalysisResult? _analyzeEnvironment(CameraImage image) {
    if (image.planes.isEmpty) return null;

    final int width = image.width;
    final int height = image.height;
    
    // We sample a grid to check for brightness and blur
    const int sampleSteps = 20; 
    final int stepX = width ~/ sampleSteps;
    final int stepY = height ~/ sampleSteps;

    int totalLuminance = 0;
    int sampleCount = 0;
    int diffSum = 0;

    final bool isYUV = image.format.group == ImageFormatGroup.yuv420;
    final bool isBGRA = image.format.group == ImageFormatGroup.bgra8888;

    if (!isYUV && !isBGRA) {
      return null; // Unsupported format, skip blur/light check
    }

    final Uint8List plane0 = image.planes[0].bytes;

    for (int y = 0; y < height - stepY; y += stepY) {
      for (int x = 0; x < width - stepX; x += stepX) {
        int luma = 0;

        if (isYUV) {
          final int yIndex = y * image.planes[0].bytesPerRow + x;
          if (yIndex >= plane0.length) continue;

          final int yValue = plane0[yIndex];
          luma = yValue;
          
          final int nextYIndex = yIndex + stepX;
          if (nextYIndex < plane0.length) {
            diffSum += (yValue - plane0[nextYIndex]).abs();
          }
        } else if (isBGRA) {
          final int pixelIndex = (y * image.planes[0].bytesPerRow) + (x * 4);
          if (pixelIndex + 3 >= plane0.length) continue;

          final int b = plane0[pixelIndex];
          final int g = plane0[pixelIndex + 1];
          final int r = plane0[pixelIndex + 2];
          luma = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
          
          final int nextPixelIndex = pixelIndex + (stepX * 4);
          if (nextPixelIndex + 2 < plane0.length) {
            final int nextLuma = (0.299 * plane0[nextPixelIndex + 2] + 0.587 * plane0[nextPixelIndex + 1] + 0.114 * plane0[nextPixelIndex]).toInt();
            diffSum += (luma - nextLuma).abs();
          }
        }

        totalLuminance += luma;
        sampleCount++;
      }
    }

    if (sampleCount == 0) return null;

    final double avgLuminance = totalLuminance / sampleCount;
    final double gradientAvg = diffSum / sampleCount;

    // 1. Lighting Check
    if (avgLuminance < 40) {
      return const QualityAnalysisResult(CaptureQuality.poor, "Find better lighting");
    } else if (avgLuminance > 220) {
      return const QualityAnalysisResult(CaptureQuality.poor, "Too bright, reduce lighting");
    }

    // 2. Blur Check
    if (gradientAvg < 15.0 && avgLuminance > 50) { 
      return const QualityAnalysisResult(CaptureQuality.poor, "Hold steady – image is blurry");
    }

    return null; // Passed environment checks
  }
}
