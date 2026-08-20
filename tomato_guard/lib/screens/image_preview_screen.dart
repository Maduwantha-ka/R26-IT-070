import 'package:flutter/material.dart';
import '../models/disease_result.dart';
import '../services/disease_service.dart';
import '../services/lada_service.dart';
import '../theme/app_theme.dart';
import '../widgets/badge_chip.dart';
import '../widgets/custom_button.dart';
import '../widgets/image_card.dart';
import 'classification_screen.dart';

class ImagePreviewScreen extends StatefulWidget {
  final ProcessedImageData imageData;

  const ImagePreviewScreen({super.key, required this.imageData});

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late ProcessedImageData _currentImageData;
  bool _isProcessingLada = false;
  bool _hasEnhancedWithLada = false;
  double _ladaProgress = 0.0;
  String _ladaStatusMessage = '';
  bool _isClassifying = false;

  @override
  void initState() {
    super.initState();
    _currentImageData = widget.imageData;
  }

  void _enhanceWithLADA() async {
    setState(() {
      _isProcessingLada = true;
      _ladaProgress = 0.0;
      _ladaStatusMessage = 'Starting LADA Augmentation Pipeline...';
    });

    await for (final progress in LadaService.processImageWithLADA()) {
      if (!mounted) return;
      setState(() {
        _ladaProgress = progress.progress;
        _ladaStatusMessage = progress.currentStepMessage;
      });
    }

    if (mounted) {
      setState(() {
        _isProcessingLada = false;
        _hasEnhancedWithLada = true;
        _currentImageData = ProcessedImageData(
          originalFile: _currentImageData.originalFile,
          imageBytes: _currentImageData.imageBytes,
          isEnhancedByLada: true,
          enhancementNote:
              'Feature contrast & spatial resolution augmented by LADA SLA-XCA module.',
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white),
              SizedBox(width: 10),
              Text('Image successfully enhanced by LADA!'),
            ],
          ),
          backgroundColor: AppTheme.primaryDark,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToClassification(ProcessedImageData dataToUse) async {
    setState(() => _isClassifying = true);

    try {
      final result = await DiseaseService.classifyImage(dataToUse);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassificationScreen(diseaseResult: result),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Classification error: $e'),
            backgroundColor: AppTheme.severitySevere,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClassifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        title: const Text('Image Preview'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview Header Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _hasEnhancedWithLada
                          ? 'Enhanced Image Preview'
                          : 'Original Input Image',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.textDark,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  LadaBadgeChip(isEnhanced: _hasEnhancedWithLada),
                ],
              ),

              const SizedBox(height: 14),

              // Image Container Card
              ImageDisplayCard(
                imageData: _currentImageData,
                height: 280,
                showBorderGlow: _hasEnhancedWithLada,
              ),

              const SizedBox(height: 20),

              // LADA Enhancement Indicator / Loading State
              if (_isProcessingLada) ...[
                Card(
                  color: Colors.white,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryDark),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                _ladaStatusMessage,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _ladaProgress,
                            minHeight: 8,
                            backgroundColor: AppTheme.softBackground,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Enhanced Info Callout Card
              if (_hasEnhancedWithLada) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.primaryLight.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified,
                          color: AppTheme.primaryDark, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Enhanced by LADA module (Spatial-Linear Augmentation & Cross-Channel Attention applied)',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Action Buttons
              if (!_hasEnhancedWithLada && !_isProcessingLada) ...[
                // Option 1: Enhance with LADA
                PrimaryButton(
                  label: 'Enhance with LADA',
                  icon: Icons.auto_awesome,
                  onPressed: _enhanceWithLADA,
                ),
                const SizedBox(height: 14),
                // Option 2: Classify Directly
                SecondaryButton(
                  label: 'Classify Directly',
                  icon: Icons.flash_on_outlined,
                  onPressed: () =>
                      _navigateToClassification(_currentImageData),
                ),
              ] else if (_hasEnhancedWithLada && !_isProcessingLada) ...[
                // Post-Enhancement Action: Classify Disease with Enhanced Image
                PrimaryButton(
                  label: 'Classify Disease',
                  icon: Icons.analytics_outlined,
                  isLoading: _isClassifying,
                  onPressed: () =>
                      _navigateToClassification(_currentImageData),
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
