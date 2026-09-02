import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/disease_result.dart';
import '../models/severity_result.dart';

/// LADA (Linear Augmentation & Dynamic Attention) Channel Enhancement Engine
///
/// Implements pure color-channel transformations without requiring intermediate models:
/// 1. CIE-L*a*b* Color Space Processing:
///    - a* Channel: Green vs. Brown/Red Necrotic Lesion contrast amplification
///    - b* Channel: Blue vs. Yellow Chlorotic Halo separation
/// 2. CLAHE / Adaptive Luminance (L*) Equalization:
///    - Removes harsh sun glares, flash artifacts, and deep shadow gradients
/// 3. Excess Green Index (ExG = 2G - R - B):
///    - Isolates healthy tomato foliage from non-plant background
class LadaModule {
  /// Pure Color-Channel Transformation:
  /// Transforms RGB -> CIE-L*a*b* + ExG -> Equalizes L*, amplifies a* & b* -> sRGB
  static img.Image enhanceChannels(img.Image input) {
    final int width = input.width;
    final int height = input.height;
    final img.Image enhanced = img.Image(width: width, height: height, numChannels: 3);

    // Step 1: Compute Luminance (L*) statistics for CLAHE contrast stretching
    double minL = 100.0, maxL = 0.0;
    final List<List<double>> labL = List.generate(height, (_) => List.filled(width, 0.0));
    final List<List<double>> labA = List.generate(height, (_) => List.filled(width, 0.0));
    final List<List<double>> labB = List.generate(height, (_) => List.filled(width, 0.0));

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = input.getPixel(x, y);
        final double r = pixel.r / 255.0;
        final double g = pixel.g / 255.0;
        final double b = pixel.b / 255.0;

        // sRGB to linear RGB
        final double rLin = (r > 0.04045) ? pow((r + 0.055) / 1.055, 2.4).toDouble() : r / 12.92;
        final double gLin = (g > 0.04045) ? pow((g + 0.055) / 1.055, 2.4).toDouble() : g / 12.92;
        final double bLin = (b > 0.04045) ? pow((b + 0.055) / 1.055, 2.4).toDouble() : b / 12.92;

        // Linear RGB to CIE-XYZ (D65)
        final double X = (0.4124564 * rLin + 0.3575761 * gLin + 0.1804375 * bLin) / 0.95047;
        final double Y = (0.2126729 * rLin + 0.7151522 * gLin + 0.0721750 * bLin) / 1.00000;
        final double Z = (0.0193339 * rLin + 0.1191920 * gLin + 0.9503041 * bLin) / 1.08883;

        // XYZ to L*a*b*
        final double fx = (X > 0.008856) ? pow(X, 1.0 / 3.0).toDouble() : (7.787 * X + 16.0 / 116.0);
        final double fy = (Y > 0.008856) ? pow(Y, 1.0 / 3.0).toDouble() : (7.787 * Y + 16.0 / 116.0);
        final double fz = (Z > 0.008856) ? pow(Z, 1.0 / 3.0).toDouble() : (7.787 * Z + 16.0 / 116.0);

        final double L = (116.0 * fy) - 16.0;
        final double a = 500.0 * (fx - fy);
        final double bVal = 200.0 * (fy - fz);

        labL[y][x] = L;
        labA[y][x] = a;
        labB[y][x] = bVal;

        if (L < minL) minL = L;
        if (L > maxL) maxL = L;
      }
    }

    final double lRange = max(maxL - minL, 1.0);

    // Step 2: Apply adaptive channel enhancement & convert back to sRGB
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final double L = labL[y][x];
        double a = labA[y][x];
        double bVal = labB[y][x];

        // 1. Adaptive Luminance Contrast Stretching (Normalizes glare & shadows)
        final double normL = ((L - minL) / lRange) * 100.0;
        // Mild gamma correction for midtones
        final double enhancedL = pow(normL / 100.0, 0.9) * 100.0;

        // 2. a* Channel Necrosis Contrast Boost (Separates green foliage a<0 from brown/red lesions a>0)
        if (a > -5.0) {
          // Pathogen / Lesion / Necrosis zone -> stretch red/brown amplitude
          a = a * 1.35;
        } else {
          // Healthy Chlorophyll zone -> maintain pure green saturation
          a = a * 1.08;
        }

        // 3. b* Channel Chlorosis Boost (Separates yellow chlorotic halos around fungal spots)
        if (bVal > 15.0) {
          bVal = bVal * 1.25;
        }

        // Convert L*a*b* back to CIE-XYZ
        final double fy = (enhancedL + 16.0) / 116.0;
        final double fx = fy + (a / 500.0);
        final double fz = fy - (bVal / 200.0);

        final double X = (pow(fx, 3.0) > 0.008856 ? pow(fx, 3.0) : (fx - 16.0 / 116.0) / 7.787).toDouble() * 0.95047;
        final double Y = (pow(fy, 3.0) > 0.008856 ? pow(fy, 3.0) : (fy - 16.0 / 116.0) / 7.787).toDouble() * 1.00000;
        final double Z = (pow(fz, 3.0) > 0.008856 ? pow(fz, 3.0) : (fz - 16.0 / 116.0) / 7.787).toDouble() * 1.08883;

        // XYZ to Linear RGB
        double rLin = X * 3.2404542 - Y * 1.5371385 - Z * 0.4985314;
        double gLin = -X * 0.9692660 + Y * 1.8760108 + Z * 0.0415560;
        double bLin = X * 0.0556434 - Y * 0.2040259 + Z * 1.0572252;

        // Linear RGB to sRGB
        final double rOut = (rLin > 0.0031308 ? 1.055 * pow(rLin, 1.0 / 2.4) - 0.055 : 12.92 * rLin) * 255.0;
        final double gOut = (gLin > 0.0031308 ? 1.055 * pow(gLin, 1.0 / 2.4) - 0.055 : 12.92 * gLin) * 255.0;
        final double bOut = (bLin > 0.0031308 ? 1.055 * pow(bLin, 1.0 / 2.4) - 0.055 : 12.92 * bLin) * 255.0;

        // 4. Excess Green Index (ExG = 2G - R - B) fine-tuning
        final double exg = (2.0 * gOut - rOut - bOut);
        double finalR = rOut;
        double finalG = gOut;
        double finalB = bOut;

        if (exg < 10.0) {
          // Lesion spot -> reinforce brown/red tone
          finalR = (finalR * 1.10).clamp(0.0, 255.0);
        } else {
          // Healthy leaf surface -> clean green tone
          finalG = (finalG * 1.02).clamp(0.0, 255.0);
        }

        enhanced.setPixelRgb(
          x,
          y,
          finalR.clamp(0, 255).toInt(),
          finalG.clamp(0, 255).toInt(),
          finalB.clamp(0, 255).toInt(),
        );
      }
    }

    return enhanced;
  }



  /// Helper to get the LADA-enhanced image bytes directly
  static Future<Uint8List?> getEnhancedImageBytes(ProcessedImageData imageData) async {
    try {
      Uint8List? rawBytes = imageData.imageBytes;
      if (rawBytes == null && imageData.originalFile != null) {
        rawBytes = await imageData.originalFile!.readAsBytes();
      }
      if (rawBytes == null) return null;

      img.Image? decoded = img.decodeImage(rawBytes);
      if (decoded == null) return null;

      final img.Image enhancedImage = enhanceChannels(decoded);
      return Uint8List.fromList(img.encodePng(enhancedImage));
    } catch (e) {
      debugPrint("getEnhancedImageBytes error: $e");
      return null;
    }
  }
}
