import 'dart:typed_data';

enum SeverityLevel {
  mild,
  moderate,
  severe,
  healthy,
}

extension SeverityLevelExtension on SeverityLevel {
  String get displayName {
    switch (this) {
      case SeverityLevel.mild:
        return 'Mild';
      case SeverityLevel.moderate:
        return 'Moderate';
      case SeverityLevel.severe:
        return 'Severe';
      case SeverityLevel.healthy:
        return 'Healthy (0%)';
    }
  }

  String get description {
    switch (this) {
      case SeverityLevel.mild:
        return 'Early stage infection localized to lower leaf areas. High recovery potential with organic treatment.';
      case SeverityLevel.moderate:
        return 'Noticeable lesion spread across 15-35% of leaf surface. Immediate treatment recommended to prevent crop spread.';
      case SeverityLevel.severe:
        return 'Widespread leaf necrosis and chlorosis exceeding 35%. Urgent intervention and isolation required.';
      case SeverityLevel.healthy:
        return 'No visible signs of pathogen infection. Plant tissue exhibits optimal chlorophyll distribution.';
    }
  }
}

class SeverityResult {
  final SeverityLevel level;
  final double affectedAreaPercentage; // e.g. 24.5%
  final int totalLesionCount;
  final String primarySymptom;
  final String leafTissueHealthScore; // e.g. "75.5/100"
  final Uint8List? maskImageBytes;

  const SeverityResult({
    required this.level,
    required this.affectedAreaPercentage,
    required this.totalLesionCount,
    required this.primarySymptom,
    required this.leafTissueHealthScore,
    this.maskImageBytes,
  });
}
