import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

enum CaptureQuality { good, fair, poor }

class QualityAnalysisResult {
  final CaptureQuality quality;
  final String message;

  const QualityAnalysisResult(this.quality, this.message);
}

class QualityAnalyzer {
  /// Analyzes the camera image and returns a quality result.
  /// Runs in an isolate to prevent UI jank.
  static Future<QualityAnalysisResult> analyze(CameraImage image) async {
    // compute is used to run the analysis on a separate background thread
    return await compute(_analyzeImage, image);
  }

  static QualityAnalysisResult _analyzeImage(CameraImage image) {
    if (image.planes.isEmpty) {
      return const QualityAnalysisResult(CaptureQuality.poor, "Camera error");
    }

    final int width = image.width;
    final int height = image.height;
    
    // We will sample a grid to check for green pixels (leaf) and brightness.
    const int sampleSteps = 20; // 20x20 grid = 400 pixels
    final int stepX = width ~/ sampleSteps;
    final int stepY = height ~/ sampleSteps;

    int totalLuminance = 0;
    int greenCount = 0;
    int centerGreenCount = 0;
    int totalCenterSamples = 0;
    int sampleCount = 0;
    
    // For blur detection (variance of laplacian or simple gradient)
    int diffSum = 0;

    final bool isYUV = image.format.group == ImageFormatGroup.yuv420;
    final bool isBGRA = image.format.group == ImageFormatGroup.bgra8888;

    if (!isYUV && !isBGRA) {
      // Unsupported format, just return good to not block the user
      return const QualityAnalysisResult(CaptureQuality.good, "Perfect! You can capture now");
    }

    final Uint8List plane0 = image.planes[0].bytes;
    
    // Check center bounds (middle 50% of the image)
    final int minCenterX = (width * 0.25).toInt();
    final int maxCenterX = (width * 0.75).toInt();
    final int minCenterY = (height * 0.25).toInt();
    final int maxCenterY = (height * 0.75).toInt();

    for (int y = 0; y < height - stepY; y += stepY) {
      for (int x = 0; x < width - stepX; x += stepX) {
        int r = 0, g = 0, b = 0, luma = 0;

        if (isYUV) {
          final int uvRowStride = image.planes[1].bytesPerRow;
          final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

          final int yIndex = y * image.planes[0].bytesPerRow + x;
          final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

          // Safe access
          if (yIndex >= plane0.length || uvIndex >= image.planes[1].bytes.length || uvIndex >= image.planes[2].bytes.length) {
             continue;
          }

          final int yValue = plane0[yIndex];
          final int uValue = image.planes[1].bytes[uvIndex];
          final int vValue = image.planes[2].bytes[uvIndex];

          luma = yValue;
          
          // YUV to RGB approximation
          r = (yValue + 1.402 * (vValue - 128)).toInt().clamp(0, 255);
          g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).toInt().clamp(0, 255);
          b = (yValue + 1.772 * (uValue - 128)).toInt().clamp(0, 255);
          
          // Calculate a simple gradient for blur (difference with next pixel)
          final int nextYIndex = yIndex + stepX;
          if (nextYIndex < plane0.length) {
            diffSum += (yValue - plane0[nextYIndex]).abs();
          }

        } else if (isBGRA) {
          final int pixelIndex = (y * image.planes[0].bytesPerRow) + (x * 4);
          if (pixelIndex + 3 >= plane0.length) continue;

          b = plane0[pixelIndex];
          g = plane0[pixelIndex + 1];
          r = plane0[pixelIndex + 2];
          luma = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
          
          final int nextPixelIndex = pixelIndex + (stepX * 4);
          if (nextPixelIndex + 2 < plane0.length) {
            final int nextLuma = (0.299 * plane0[nextPixelIndex + 2] + 0.587 * plane0[nextPixelIndex + 1] + 0.114 * plane0[nextPixelIndex]).toInt();
            diffSum += (luma - nextLuma).abs();
          }
        }

        totalLuminance += luma;
        sampleCount++;

        // Basic "is it green enough to be a leaf" check
        // Green should be dominant
        if (g > r + 10 && g > b + 10 && g > 60) {
          greenCount++;
          
          if (x >= minCenterX && x <= maxCenterX && y >= minCenterY && y <= maxCenterY) {
            centerGreenCount++;
          }
        }
        
        if (x >= minCenterX && x <= maxCenterX && y >= minCenterY && y <= maxCenterY) {
            totalCenterSamples++;
        }
      }
    }

    if (sampleCount == 0) return const QualityAnalysisResult(CaptureQuality.poor, "Error analyzing image");

    final double avgLuminance = totalLuminance / sampleCount;
    final double greenRatio = greenCount / sampleCount;
    final double centerGreenRatio = totalCenterSamples > 0 ? (centerGreenCount / totalCenterSamples) : 0.0;
    final double gradientAvg = diffSum / sampleCount;

    // 1. Lighting Check
    if (avgLuminance < 40) {
      return const QualityAnalysisResult(CaptureQuality.poor, "Find better lighting");
    } else if (avgLuminance > 220) {
      return const QualityAnalysisResult(CaptureQuality.poor, "Too bright, reduce lighting");
    }

    // 2. Blur Check
    // A low gradient average indicates a lack of sharp edges (blurry)
    if (gradientAvg < 15.0 && avgLuminance > 50) { 
      return const QualityAnalysisResult(CaptureQuality.poor, "Hold steady – image is blurry");
    }

    // 3. Leaf Detection (Green presence)
    if (greenRatio < 0.05) {
      return const QualityAnalysisResult(CaptureQuality.poor, "Leaf not detected");
    }

    // 4. Centering and Distance Check
    if (centerGreenRatio < 0.2 && greenRatio > 0.1) {
      return const QualityAnalysisResult(CaptureQuality.fair, "Center the leaf");
    }
    
    if (greenRatio < 0.15) {
      return const QualityAnalysisResult(CaptureQuality.fair, "Move closer");
    }
    
    if (greenRatio > 0.70) {
      return const QualityAnalysisResult(CaptureQuality.fair, "Move back a little");
    }

    // If it passes all checks
    return const QualityAnalysisResult(CaptureQuality.good, "Perfect! You can capture now");
  }
}
