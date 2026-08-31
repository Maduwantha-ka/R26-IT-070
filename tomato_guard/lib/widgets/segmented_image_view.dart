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

          // Custom Segmentation Mask Overlay (Green disease spot overlay)
          if (severity.maskImageBytes != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.9,
                child: Image.memory(
                  severity.maskImageBytes!,
                  fit: BoxFit.cover,
                ),
              ),
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
                    'Red Mask: AI Disease Spot Overlay',
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
