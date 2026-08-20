import 'package:flutter/material.dart';
import '../models/disease_result.dart';
import '../theme/app_theme.dart';
import 'badge_chip.dart';

class ImageDisplayCard extends StatelessWidget {
  final ProcessedImageData imageData;
  final double height;
  final Widget? badgeOverlay;
  final bool showBorderGlow;

  const ImageDisplayCard({
    super.key,
    required this.imageData,
    this.height = 260,
    this.badgeOverlay,
    this.showBorderGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: showBorderGlow
                ? AppTheme.primary.withOpacity(0.3)
                : Colors.black.withOpacity(0.08),
            blurRadius: showBorderGlow ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image Content
            _buildImageWidget(),

            // Soft Gradient overlay for text/badge readability
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
                    ],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
            ),

            // Top Badge
            Positioned(
              top: 14,
              left: 14,
              child: badgeOverlay ??
                  LadaBadgeChip(isEnhanced: imageData.isEnhancedByLada),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (imageData.imageBytes != null) {
      return Image.memory(
        imageData.imageBytes!,
        fit: BoxFit.cover,
      );
    } else if (imageData.originalFile != null) {
      return Image.file(
        imageData.originalFile!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackGraphic(),
      );
    }
    return _buildFallbackGraphic();
  }

  Widget _buildFallbackGraphic() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E7D32),
            Color(0xFF43A047),
            Color(0xFF81C784),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.energy_savings_leaf,
                color: Colors.white,
                size: 54,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Solanum lycopersicum (Tomato Leaf)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
