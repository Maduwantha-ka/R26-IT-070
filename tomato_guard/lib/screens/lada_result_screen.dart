import 'package:flutter/material.dart';
import '../models/disease_result.dart';
import '../services/disease_service.dart';
import '../services/lada_enhancement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/badge_chip.dart';
import '../widgets/custom_button.dart';
import 'classification_screen.dart';

class LadaResultScreen extends StatefulWidget {
  final LadaEnhancementResult ladaResult;

  const LadaResultScreen({super.key, required this.ladaResult});

  @override
  State<LadaResultScreen> createState() => _LadaResultScreenState();
}

class _LadaResultScreenState extends State<LadaResultScreen> {
  bool _isClassifying = false;

  void _classifyEnhancedImage() async {
    setState(() => _isClassifying = true);

    try {
      final processedData = ProcessedImageData(
        originalFile: widget.ladaResult.originalFile,
        imageBytes: widget.ladaResult.enhancedBytes,
        isEnhancedByLada: true,
        enhancementNote: widget.ladaResult.message,
      );

      final result = await DiseaseService.classifyImage(processedData);
      
      if (mounted) {
        Navigator.pushReplacement(
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
        title: const Text('LADA Enhancement Result'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Confidence Badge
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.ladaResult.isConfident
                      ? AppTheme.primaryDark.withOpacity(0.1)
                      : AppTheme.severityModerate.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.ladaResult.isConfident
                        ? AppTheme.primaryDark.withOpacity(0.4)
                        : AppTheme.severityModerate.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.ladaResult.isConfident ? Icons.verified : Icons.warning_amber_rounded,
                      color: widget.ladaResult.isConfident ? AppTheme.primaryDark : AppTheme.severityModerate,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.ladaResult.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.ladaResult.isConfident ? AppTheme.textDark : AppTheme.severityModerate,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Before / After Display
              const Text(
                'Original Image',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.hardEdge,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Image.file(
                  widget.ladaResult.originalFile,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Enhanced Image',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  const LadaBadgeChip(isEnhanced: true),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.hardEdge,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.primaryLight, width: 2),
                ),
                child: Image.memory(
                  widget.ladaResult.enhancedBytes,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 32),

              // Action Button
              PrimaryButton(
                label: 'Classify Disease',
                icon: Icons.analytics_outlined,
                isLoading: _isClassifying,
                onPressed: _classifyEnhancedImage,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
