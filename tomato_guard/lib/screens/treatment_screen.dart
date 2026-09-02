import 'package:flutter/material.dart';
import '../models/disease_result.dart';
import '../models/treatment_info.dart';
import '../theme/app_theme.dart';
import '../widgets/section_header.dart';
import '../widgets/custom_button.dart';
import 'segmentation_screen.dart';

class TreatmentScreen extends StatelessWidget {
  final DiseaseResult diseaseResult;

  const TreatmentScreen({super.key, required this.diseaseResult});

  @override
  Widget build(BuildContext context) {
    final treatment = diseaseResult.treatment;

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        title: const Text('Treatment Recommendation'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Disease Name Header Card
              Card(
                color: AppTheme.primaryDark,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.medication_liquid_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Targeted Treatment Plan',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              diseaseResult.diseaseName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Section 1: Cultural Practices
              const SectionHeader(
                title: 'Cultural Practices',
                subtitle: 'Agronomic field techniques and prevention',
                icon: Icons.grass_outlined,
              ),
              const SizedBox(height: 8),
              ...treatment.culturalPractices.map(
                (item) => _buildTreatmentCard(
                  context: context,
                  item: item,
                  accentColor: AppTheme.primaryDark,
                  icon: Icons.eco_outlined,
                ),
              ),

              const SizedBox(height: 24),

              // Section 2: Organic Treatment
              const SectionHeader(
                title: 'Organic Treatment',
                subtitle: 'Eco-friendly and biological interventions',
                icon: Icons.nature_people_outlined,
              ),
              const SizedBox(height: 8),
              ...treatment.organicTreatments.map(
                (item) => _buildTreatmentCard(
                  context: context,
                  item: item,
                  accentColor: AppTheme.primaryLight,
                  icon: Icons.eco,
                ),
              ),

              const SizedBox(height: 24),

              // Section 3: Chemical Control
              const SectionHeader(
                title: 'Chemical Control',
                subtitle: 'Targeted fungicides, pesticides, and dosages',
                icon: Icons.science_outlined,
              ),
              const SizedBox(height: 8),
              ...treatment.chemicalTreatments.map(
                (item) => _buildTreatmentCard(
                  context: context,
                  item: item,
                  accentColor: AppTheme.severityModerate,
                  icon: Icons.warning_amber_rounded,
                ),
              ),

              const SizedBox(height: 28),

              // Action Buttons for Flow
              PrimaryButton(
                label: 'View Severity & Lesion Mask',
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

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTreatmentCard({
    required BuildContext context,
    required TreatmentItem item,
    required Color accentColor,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accentColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_outlined,
                            size: 14, color: accentColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Dosage: ${item.dosageOrFrequency}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
