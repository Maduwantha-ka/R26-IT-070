import 'package:flutter/material.dart';
import '../models/disease_result.dart';
import '../models/severity_result.dart';
import '../theme/app_theme.dart';
import '../widgets/badge_chip.dart';
import '../widgets/section_header.dart';
import '../widgets/segmented_image_view.dart';
import '../widgets/custom_button.dart';
import 'treatment_screen.dart';

class SegmentationScreen extends StatelessWidget {
  final DiseaseResult diseaseResult;

  const SegmentationScreen({super.key, required this.diseaseResult});

  @override
  Widget build(BuildContext context) {
    final severity = diseaseResult.severity;

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        title: const Text('Segmentation & Severity'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented Leaf Image with Green Mask Overlay
              SegmentedImageView(
                imageData: diseaseResult.imageData,
                severity: severity,
                height: 260,
              ),

              const SizedBox(height: 20),

              // Severity Summary Card
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Infection Severity',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SeverityBadgeChip(level: severity.level),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // LADA Channel Enhancement Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                diseaseResult.isLadaEnhanced
                                    ? 'LADA SLA Multi-Channel Attention Active'
                                    : 'Baseline ALAS-Net Segmentation',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Affected Area Percentage Gauge Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.primaryLight.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryDark,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.pie_chart,
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
                                    'Affected Leaf Area',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${severity.affectedAreaPercentage}%',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Detailed Metrics Breakdown Grid
                      const SectionHeader(
                        title: 'Morphological Lesion Analysis',
                        subtitle: 'Leaf tissue surface area segmentation data',
                        icon: Icons.grain_outlined,
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Total Lesion Count',
                              value: '${severity.totalLesionCount} Spots',
                              icon: Icons.bubble_chart_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Tissue Health Index',
                              value: severity.leafTissueHealthScore,
                              icon: Icons.health_and_safety_outlined,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      _buildMetricTile(
                        label: 'Primary Pathogen Manifestation',
                        value: severity.primarySymptom,
                        icon: Icons.center_focus_weak_outlined,
                      ),

                      const Divider(height: 28),

                      // Severity Guidance Text
                      Text(
                        severity.level.description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textDark,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              PrimaryButton(
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

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentMint.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
