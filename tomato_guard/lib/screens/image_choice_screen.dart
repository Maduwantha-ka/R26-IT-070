import 'dart:io';
import 'package:flutter/material.dart';
import '../models/disease_result.dart';
import '../services/disease_service.dart';
import '../services/lada_enhancement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import 'classification_screen.dart';
import 'lada_result_screen.dart';

class ImageChoiceScreen extends StatefulWidget {
  final ProcessedImageData imageData;

  const ImageChoiceScreen({super.key, required this.imageData});

  @override
  State<ImageChoiceScreen> createState() => _ImageChoiceScreenState();
}

class _ImageChoiceScreenState extends State<ImageChoiceScreen> {
  bool _isProcessingLada = false;
  bool _isClassifying = false;

  void _enhanceWithLADA() async {
    setState(() {
      _isProcessingLada = true;
    });

    try {
      if (widget.imageData.originalFile == null) {
        throw Exception("No original file provided for enhancement.");
      }

      final result = await LadaEnhancementService.enhanceImage(widget.imageData.originalFile!);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LadaResultScreen(ladaResult: result),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('LADA processing failed: $e'),
            backgroundColor: AppTheme.severitySevere,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingLada = false;
        });
      }
    }
  }

  void _classifyDirectly() async {
    setState(() => _isClassifying = true);

    try {
      final result = await DiseaseService.classifyImage(widget.imageData);
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
              Text(
                'Original Input Image',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 14),

              // Image Display
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.hardEdge,
                child: Container(
                  height: 300,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.black12,
                  ),
                  child: widget.imageData.originalFile != null
                      ? Image.file(
                          widget.imageData.originalFile!,
                          fit: BoxFit.cover,
                        )
                      : (widget.imageData.imageBytes != null 
                          ? Image.memory(widget.imageData.imageBytes!, fit: BoxFit.cover)
                          : const Center(child: Icon(Icons.image, size: 40))),
                ),
              ),

              const SizedBox(height: 24),

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
                                'Processing with Classical LADA Pipeline...',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
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
                  isLoading: _isClassifying,
                  onPressed: _classifyDirectly,
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
