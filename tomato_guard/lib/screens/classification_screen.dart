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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryDark.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.eco_outlined,
                              color: AppTheme.primaryDark,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  diseaseResult.diseaseName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textDark,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  diseaseResult.scientificName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 28),

                      // Confidence Percentage Meter
                      const SectionHeader(
                        title: 'Model Prediction Confidence',
                        subtitle: 'AI classification score based on feature extraction',
                        icon: Icons.speed_rounded,
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                value: diseaseResult.confidencePercentage / 100.0,
                                minHeight: 14,
                                backgroundColor:
                                    AppTheme.primaryDark.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryDark),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${diseaseResult.confidencePercentage}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
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
              PrimaryButton(
                label: 'View Treatment Recommendation',
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

              const SizedBox(height: 14),

              SecondaryButton(
                label: 'Segmentation & Severity Estimation',
                icon: Icons.pie_chart_outline_rounded,
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

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
