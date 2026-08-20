import 'dart:math';
import '../models/disease_result.dart';
import '../models/severity_result.dart';
import '../models/treatment_info.dart';

class DiseaseService {
  static final Random _random = Random();

  /// Mock Classification Engine
  /// When [isEnhancedByLada] is true, confidence score boost and clearer diagnostics are provided!
  static Future<DiseaseResult> classifyImage(ProcessedImageData imageData) async {
    // Simulate classification latency
    await Future.delayed(const Duration(milliseconds: 600));

    // Base confidence score: LADA enhanced images get higher confidence (94-98.8%), direct get (84-91.5%)
    final double confidence = imageData.isEnhancedByLada
        ? 94.5 + _random.nextDouble() * 4.3
        : 84.0 + _random.nextDouble() * 7.5;

    // Pick realistic disease result (defaulting to Early Blight for main demo, with rich data)
    final diseaseResult = _sampleDiseaseDatabase[0]; // Tomato Early Blight

    return DiseaseResult(
      diseaseName: diseaseResult.diseaseName,
      scientificName: diseaseResult.scientificName,
      confidencePercentage: double.parse(confidence.toStringAsFixed(1)),
      overview: diseaseResult.overview,
      imageData: imageData,
      severity: diseaseResult.severity,
      treatment: diseaseResult.treatment,
    );
  }

  static TreatmentInfo getDefaultTreatment() {
    return _sampleDiseaseDatabase[0].treatment;
  }

  static const List<DiseaseResult> _sampleDiseaseDatabase = [
    DiseaseResult(
      diseaseName: 'Tomato Early Blight',
      scientificName: 'Alternaria solani',
      confidencePercentage: 96.8,
      overview:
          'Early Blight is a common fungal disease of tomatoes causing distinct dark concentric target-like rings on older leaves, causing defoliation and severe yield loss if untreated.',
      imageData: ProcessedImageData(),
      severity: SeverityResult(
        level: SeverityLevel.moderate,
        affectedAreaPercentage: 24.8,
        totalLesionCount: 14,
        primarySymptom: 'Concentric necrotic lesions on lower leaves',
        leafTissueHealthScore: '75.2 / 100',
      ),
      treatment: TreatmentInfo(
        diseaseName: 'Tomato Early Blight (Alternaria solani)',
        culturalPractices: [
          TreatmentItem(
            title: 'Lower Leaf Pruning',
            description: 'Prune and destroy infected lower foliage touching the soil to reduce fungal spore splash-back.',
            dosageOrFrequency: 'Weekly during growing season',
          ),
          TreatmentItem(
            title: 'Drip Irrigation & Spacing',
            description: 'Water at the soil line using drip hoses. Maintain 24-36 inches plant spacing for air circulation.',
            dosageOrFrequency: 'Daily ground watering',
          ),
          TreatmentItem(
            title: 'Crop Rotation',
            description: 'Rotate tomato crops with non-solanaceous plants (e.g. corn, beans, cabbage) for 3 seasons.',
            dosageOrFrequency: 'Seasonal rotation plan',
          ),
        ],
        organicTreatments: [
          TreatmentItem(
            title: 'Copper Octanoate Fungicide',
            description: 'Apply liquid copper soap to foliage early in the morning. Covers leaf surface preventing spore germination.',
            dosageOrFrequency: '2 tbsp per gallon of water every 7-10 days',
          ),
          TreatmentItem(
            title: 'Neem Oil Concentrate (70%)',
            description: 'Foliar spray of organic cold-pressed neem oil to control secondary fungal hyphae development.',
            dosageOrFrequency: '1 oz per gallon, repeat every 7 days',
          ),
          TreatmentItem(
            title: 'Bio-fungicide (Bacillus subtilis)',
            description: 'Beneficial bacterial bio-agent that outcompetes fungal pathogens on leaf surfaces.',
            dosageOrFrequency: '1-2 tsp per gallon every 5-7 days',
          ),
        ],
        chemicalTreatments: [
          TreatmentItem(
            title: 'Chlorothalonil 500 SC',
            description: 'Broad-spectrum protective contact fungicide. Provides durable barrier against spore germination.',
            dosageOrFrequency: '1.5-2.0 ml per liter of water every 7 days',
          ),
          TreatmentItem(
            title: 'Mancozeb 75% WP',
            description: 'Multi-site protective fungicide for severe foliage outbreaks.',
            dosageOrFrequency: '2g per liter, maximum 4 sprays per season',
          ),
          TreatmentItem(
            title: 'Azoxystrobin (Systemic)',
            description: 'Strobilurin class systemic fungicide absorbed into leaf vascular tissue.',
            dosageOrFrequency: '0.5 ml per liter, alternate with contact spray',
          ),
        ],
      ),
    ),
  ];
}
