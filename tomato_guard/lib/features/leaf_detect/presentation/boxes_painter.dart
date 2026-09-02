import 'package:flutter/material.dart';
import '../domain/detection.dart';

class BoxesPainter extends CustomPainter {
  final List<LeafDetection> detections;
  final Size imageSize;

  BoxesPainter({
    required this.detections,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width <= 0 || imageSize.height <= 0 || detections.isEmpty) {
      return;
    }

    // Compute BoxFit.contain scaling ratio and offsets
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double renderWidth = imageSize.width * scale;
    final double renderHeight = imageSize.height * scale;

    final double offsetX = (size.width - renderWidth) / 2.0;
    final double offsetY = (size.height - renderHeight) / 2.0;

    final Rect imageRect = Rect.fromLTWH(offsetX, offsetY, renderWidth, renderHeight);

    // Clip to image display rect
    canvas.save();
    canvas.clipRect(imageRect);

    for (final detection in detections) {
      final double left = offsetX + (detection.x * scale);
      final double top = offsetY + (detection.y * scale);
      final double width = detection.w * scale;
      final double height = detection.h * scale;

      final Rect boxRect = Rect.fromLTWH(left, top, width, height);

      // Color coding: Green for Healthy, Orange/Red for diseased
      final Color boxColor = detection.isHealthy 
          ? const Color(0xFF4CAF50) 
          : const Color(0xFFE53935);

      final Paint borderPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      final Paint fillPaint = Paint()
        ..color = boxColor.withOpacity(0.15)
        ..style = PaintingStyle.fill;

      // Draw box
      final RRect roundedBox = RRect.fromRectAndRadius(boxRect, const Radius.circular(6));
      canvas.drawRRect(roundedBox, fillPaint);
      canvas.drawRRect(roundedBox, borderPaint);

      // Draw label & confidence tag above box
      final String confPercent = (detection.confidence * 100).toStringAsFixed(1);
      final String tagText = "${detection.label} $confPercent%";

      final TextSpan span = TextSpan(
        text: tagText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );

      final TextPainter textPainter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout();

      const double padH = 6.0;
      const double padV = 3.0;
      final double badgeWidth = textPainter.width + (padH * 2);
      final double badgeHeight = textPainter.height + (padV * 2);

      final double badgeLeft = left.clamp(offsetX, offsetX + renderWidth - badgeWidth);
      final double badgeTop = (top - badgeHeight - 2).clamp(offsetY, offsetY + renderHeight - badgeHeight);

      final RRect badgeBg = RRect.fromRectAndRadius(
        Rect.fromLTWH(badgeLeft, badgeTop, badgeWidth, badgeHeight),
        const Radius.circular(4),
      );

      final Paint badgePaint = Paint()
        ..color = boxColor.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(badgeBg, badgePaint);
      textPainter.paint(canvas, Offset(badgeLeft + padH, badgeTop + padV));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BoxesPainter oldDelegate) {
    return oldDelegate.detections != detections || oldDelegate.imageSize != imageSize;
  }
}
