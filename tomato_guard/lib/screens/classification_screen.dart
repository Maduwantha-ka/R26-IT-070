import 'package:flutter/material.dart';
import '../models/disease_result.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/image_card.dart';
import '../widgets/section_header.dart';
import 'segmentation_screen.dart';
import 'treatment_screen.dart';
import '../services/database_service.dart';

class ClassificationScreen extends StatefulWidget {
  final DiseaseResult diseaseResult;

  const ClassificationScreen({super.key, required this.diseaseResult});

  @override
  State<ClassificationScreen> createState() => _ClassificationScreenState();
}

class _ClassificationScreenState extends State<ClassificationScreen> {
  @override
  void initState() {
    super.initState();
    _saveToHistory();
  }

  Future<void> _saveToHistory() async {
    try {
      await DatabaseService.saveScan(widget.diseaseResult);
    } catch (_) {
      // Ignore duplicates or transient errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final diseaseResult = widget.diseaseResult;
    final bool isNoLeaf = diseaseResult.diseaseName == 'No Tomato Leaf Detected';
    final bool isHealthy = diseaseResult.diseaseName == 'Healthy Tomato Plant';

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        title: const Text('Classification Result'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display Leaf Image
              ImageDisplayCard(
                imageData: diseaseResult.imageData,
                height: 240,
              ),

              const SizedBox(height: 20),

              // Disease Diagnosis Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (diseaseResult.isLadaEnhanced && !isNoLeaf) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'LADA SLA Enhanced Pipeline Active',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isNoLeaf
                                  ? Colors.amber.withValues(alpha: 0.15)
                                  : (isHealthy
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : AppTheme.primaryLight.withValues(alpha: 0.15)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isNoLeaf
                                  ? Icons.warning_amber_rounded
                                  : (isHealthy
                                      ? Icons.check_circle_outline
                                      : Icons.bug_report_outlined),
                              color: isNoLeaf
                                  ? Colors.amber[800]
                                  : (isHealthy ? Colors.green[700] : AppTheme.primaryDark),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  diseaseResult.diseaseName,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isNoLeaf ? Colors.amber[900] : AppTheme.textDark,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  diseaseResult.scientificName,
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: AppTheme.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Confidence Percentage Meter
                      SectionHeader(
                        title: isNoLeaf ? 'Detection Assessment' : 'Model Prediction Confidence',
                        subtitle: isNoLeaf
                            ? 'AI scan results for tomato leaf characteristics'
                            : 'AI classification score based on feature extraction',
                        icon: isNoLeaf ? Icons.search_off_rounded : Icons.speed_rounded,
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                value: isNoLeaf ? 0.0 : (diseaseResult.confidencePercentage / 100.0),
                                minHeight: 14,
                                backgroundColor: isNoLeaf
                                    ? Colors.amber.withValues(alpha: 0.15)
                                    : AppTheme.primaryDark.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    isNoLeaf ? Colors.amber[700]! : AppTheme.primaryDark),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isNoLeaf ? Colors.amber[800] : AppTheme.primaryDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isNoLeaf ? 'No Match' : '${diseaseResult.confidencePercentage}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Overview Text
                      Text(
                        diseaseResult.overview,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              if (isNoLeaf) ...[
                PrimaryButton(
                  label: '📷 Retake Leaf Photo',
                  icon: Icons.camera_alt_outlined,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 14),
                SecondaryButton(
                  label: 'View Photo Guidelines',
                  icon: Icons.lightbulb_outline,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TreatmentScreen(
                          diseaseResult: diseaseResult,
                        ),
                      ),
                    );
                  },
                ),
              ] else ...[
                PrimaryButton(
                  label: diseaseResult.isLadaEnhanced
                      ? '✨ LADA Severity & Lesion Segmentation'
                      : 'Severity Estimation & Lesion Mask',
                  icon: Icons.pie_chart_rounded,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SegmentationScreen(
                          diseaseResult: diseaseResult,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                SecondaryButton(
                  label: 'View Treatment Recommendations',
                  icon: Icons.medical_services_outlined,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TreatmentScreen(
                          diseaseResult: diseaseResult,
                        ),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
