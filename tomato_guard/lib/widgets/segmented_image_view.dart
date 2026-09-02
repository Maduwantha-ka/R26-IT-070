import 'package:flutter/material.dart';
import '../models/disease_result.dart';
import '../models/severity_result.dart';
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
        ],
      ),
    );
  }
}
