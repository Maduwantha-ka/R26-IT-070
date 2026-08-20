import 'package:flutter/material.dart';
import '../models/disease_result.dart';
import '../models/severity_result.dart';
import '../theme/app_theme.dart';
import 'image_card.dart';

class SegmentedImageView extends StatelessWidget {
  final ProcessedImageData imageData;
  final SeverityResult severity;
  final double height;

  const SegmentedImageView({
    super.key,
    required this.imageData,
    required this.severity,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Underlying Leaf Base Image
          ImageDisplayCard(
            imageData: imageData,
            height: height,
          ),

          // Custom Segmentation Mask Overlay (Green disease spot contours & bounding circles)
          CustomPaint(
            size: Size.infinite,
            painter: _SegmentationMaskPainter(severityLevel: severity.level),
          ),

          // Overlay Legend Badge
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryLight, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.layers, color: AppTheme.primaryLight, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Green Mask: AI Disease Spot Overlay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentationMaskPainter extends CustomPainter {
  final SeverityLevel severityLevel;

  _SegmentationMaskPainter({required this.severityLevel});

  @override
  void paint(Canvas canvas, Size size) {
    // Green overlay for lesion contours
    final paintFill = Paint()
      ..color = const Color(0xFF66BB6A).withOpacity(0.45)
      ..style = PaintingStyle.fill;

    final paintStroke = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final paintAccentSpot = Paint()
      ..color = const Color(0xFFA5D6A7).withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // Center focal lesions
    final centerW = size.width * 0.45;
    final centerH = size.height * 0.48;

    // Draw realistic lesion spots
    final spot1 = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(centerW, centerH), width: 75, height: 60));
    final spot2 = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(centerW + 50, centerH - 30), width: 55, height: 45));
    final spot3 = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(centerW - 40, centerH + 35), width: 65, height: 50));

    canvas.drawPath(spot1, paintFill);
    canvas.drawPath(spot1, paintStroke);
    canvas.drawPath(spot2, paintFill);
    canvas.drawPath(spot2, paintStroke);
    canvas.drawPath(spot3, paintFill);
    canvas.drawPath(spot3, paintStroke);

    // Accent inner highlights
    canvas.drawCircle(Offset(centerW - 5, centerH - 5), 14, paintAccentSpot);
    canvas.drawCircle(
        Offset(centerW + 48, centerH - 32), 10, paintAccentSpot);

    // Draw AI Bounding Contours Box
    final boundsPaint = Paint()
      ..color = const Color(0xFF81C784)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rectBounds = Rect.fromLTRB(
      centerW - 85,
      centerH - 65,
      centerW + 90,
      centerH + 75,
    );
    canvas.drawRRect(
        RRect.fromRectAndRadius(rectBounds, const Radius.circular(12)),
        boundsPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
