import 'dart:io';
import 'package:flutter/foundation.dart';
import 'treatment_info.dart';
import 'severity_result.dart';

class ProcessedImageData {
  final File? originalFile;
  final Uint8List? imageBytes;
  final bool isEnhancedByLada;
  final String? enhancementNote;

  const ProcessedImageData({
    this.originalFile,
    this.imageBytes,
    this.isEnhancedByLada = false,
    this.enhancementNote,
  });
}

class DiseaseResult {
  final String diseaseName;
  final String scientificName;
  final double confidencePercentage; // e.g. 96.4
  final String overview;
  final ProcessedImageData imageData;
  final SeverityResult severity;
  final TreatmentInfo treatment;

  const DiseaseResult({
    required this.diseaseName,
    required this.scientificName,
    required this.confidencePercentage,
    required this.overview,
    required this.imageData,
    required this.severity,
    required this.treatment,
  });
}
