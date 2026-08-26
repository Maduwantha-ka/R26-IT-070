import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class LadaEnhancementResult {
  final File originalFile;
  final Uint8List enhancedBytes;
  final bool isConfident;
  final String message;

  LadaEnhancementResult({
    required this.originalFile,
    required this.enhancedBytes,
    required this.isConfident,
    required this.message,
  });
}

class LadaEnhancementService {
  /// Processes the image using classical LADA heuristics on a background isolate.
  static Future<LadaEnhancementResult> enhanceImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    
    // Run the heavy image processing on a separate isolate to avoid freezing the UI.
    return await compute(_processLadaIsolate, {
      'file': imageFile,
      'bytes': bytes,
    });
  }

  static LadaEnhancementResult _processLadaIsolate(Map<String, dynamic> args) {
    final File file = args['file'];
    final Uint8List bytes = args['bytes'];

    // 1. Decode Image
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }

    // 2. Resize to max width 1024 to speed up processing
    img.Image processingImage = originalImage;
    if (processingImage.width > 1024) {
      processingImage = img.copyResize(processingImage, width: 1024);
    }

    final int w = processingImage.width;
    final int h = processingImage.height;
    
    // 3. Leaf Detection (Spatial & Color Masking)
    // We will build a mask where 255 = leaf, 0 = background
    img.Image mask = img.Image(width: w, height: h, numChannels: 1);
    
    int leafPixels = 0;
    
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final pixel = processingImage.getPixel(x, y);
        
        final num r = pixel.r;
        final num g = pixel.g;
        final num b = pixel.b;
        
        // Very basic RGB to HSL conversion for color heuristics
        final maxVal = [r, g, b].reduce((a, b) => a > b ? a : b);
        final minVal = [r, g, b].reduce((a, b) => a < b ? a : b);
        
        final l = (maxVal + minVal) / 2.0;
        
        num s = 0;
        if (maxVal != minVal) {
          s = l < 128 ? (maxVal - minVal) / (maxVal + minVal) : (maxVal - minVal) / (510 - maxVal - minVal);
        }
        
        // Find Hue
        num hue = 0;
        if (maxVal != minVal) {
          if (maxVal == r) {
            hue = (g - b) / (maxVal - minVal);
          } else if (maxVal == g) {
            hue = 2.0 + (b - r) / (maxVal - minVal);
          } else {
            hue = 4.0 + (r - g) / (maxVal - minVal);
          }
          hue *= 60;
          if (hue < 0) hue += 360;
        }

        // Color conditions for Tomato leaf (Green, Yellow, Brown, Olive)
        // Hue roughly between 20 (Brown/Orange) and 160 (Greenish-Cyan)
        bool isPlantColor = (hue >= 15 && hue <= 170);
        
        // Ignore very dark or very bright regions (shadows, sky)
        bool isNotBackground = (l > 20 && l < 240);
        
        // Ignore grey/achromatic background (soil, concrete)
        bool hasColor = s > 0.15;
        
        // Center bias (pixels near center are more likely to be leaf)
        final double normalizedX = (x - w/2).abs() / (w/2);
        final double normalizedY = (y - h/2).abs() / (h/2);
        final double distanceToCenter = normalizedX * normalizedX + normalizedY * normalizedY;
        
        // If it's near the edges and barely has color, reject it
        if (distanceToCenter > 1.2 && s < 0.25) {
          isPlantColor = false;
        }

        if (isPlantColor && isNotBackground && hasColor) {
          mask.setPixelRgb(x, y, 255, 255, 255);
          leafPixels++;
        } else {
          mask.setPixelRgb(x, y, 0, 0, 0);
        }
      }
    }

    final double leafRatio = leafPixels / (w * h);
    bool isConfident = leafRatio > 0.10 && leafRatio < 0.90;
    
    img.Image enhanced = processingImage.clone();

    if (isConfident) {
      // 4. Clean Mask (Optional: mild dilate/erode to remove noise)
      // For performance on dart `image`, we might skip complex morph ops
      // and just apply the mask.
      
      // 5. Apply Mask & Background black-out
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final maskPixel = mask.getPixel(x, y);
          if (maskPixel.r == 0) {
            // Darken the background instead of pure black to look more natural
            final pixel = enhanced.getPixel(x, y);
            enhanced.setPixelRgb(x, y, (pixel.r * 0.3).toInt(), (pixel.g * 0.3).toInt(), (pixel.b * 0.3).toInt());
          }
        }
      }
    }

    // 6. Normalize Lighting / Contrast
    // Mild contrast increase and brightness adjustment
    enhanced = img.adjustColor(
      enhanced,
      contrast: 1.15,
      brightness: 1.05, 
      gamma: 1.05,
    );
    
    // 7. Mild Denoising / Smoothing
    enhanced = img.gaussianBlur(enhanced, radius: 1);

    // 8. Mild Sharpening (Convolution matrix)
    // Enhances veins and disease spots
    const filter = [
      0.0, -0.5, 0.0,
      -0.5, 3.0, -0.5,
      0.0, -0.5, 0.0
    ];
    enhanced = img.convolution(enhanced, filter: filter, div: 1, offset: 0);

    // 9. Encode
    final Uint8List outputBytes = img.encodeJpg(enhanced, quality: 90);

    return LadaEnhancementResult(
      originalFile: file,
      enhancedBytes: outputBytes,
      isConfident: isConfident,
      message: isConfident 
          ? "Leaf detected confidently. Contrast and spatial features augmented."
          : "Leaf not detected clearly. Mild enhancement applied. You can still classify.",
    );
  }
}
