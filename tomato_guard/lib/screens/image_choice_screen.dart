import 'package:flutter/material.dart';
import '../models/disease_result.dart';
import '../services/disease_service.dart';
import '../theme/app_theme.dart';
import 'classification_screen.dart';

class ImageChoiceScreen extends StatefulWidget {
  final ProcessedImageData imageData;

  const ImageChoiceScreen({super.key, required this.imageData});

  @override
  State<ImageChoiceScreen> createState() => _ImageChoiceScreenState();
}

class _ImageChoiceScreenState extends State<ImageChoiceScreen> {
  bool _isProcessing = false;
  bool _isEnhancingWithLada = false;
  String _processingStage = '';

  Future<void> _runAnalysis({required bool enhanceWithLada}) async {
    setState(() {
      _isProcessing = true;
      _isEnhancingWithLada = enhanceWithLada;
      _processingStage = enhanceWithLada
          ? 'Applying LADA Channel Transformation...'
          : 'Analyzing leaf health and symptoms...';
    });

    try {
      if (enhanceWithLada) {
        await Future.delayed(const Duration(milliseconds: 350));
      }

      final result = await DiseaseService.classifyImage(
        widget.imageData,
        enhanceWithLada: enhanceWithLada,
      );

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
            content: Text('Analysis failed: $e'),
            backgroundColor: AppTheme.severitySevere,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageFile = widget.imageData.originalFile;
    final imageBytes = widget.imageData.imageBytes;

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        title: const Text('Leaf Photo Preview'),
        elevation: 0,
      ),
      body: SafeArea(
        child: _isProcessing
            ? _buildProcessingView()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Photo Preview Card
                    Container(
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (imageFile != null)
                            Image.file(imageFile, fit: BoxFit.cover)
                          else if (imageBytes != null)
                            Image.memory(imageBytes, fit: BoxFit.cover)
                          else
                            Container(
                              color: AppTheme.primaryLight.withValues(alpha: 0.15),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.eco, size: 64, color: AppTheme.primaryDark),
                                  SizedBox(height: 12),
                                  Text(
                                    'Sample Tomato Leaf',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryDark,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Captured',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Choose Diagnosis Mode',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Primary Button: Enhance with LADA
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _runAnalysis(enhanceWithLada: true),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 26),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    'Enhance with LADA',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Secondary Option: Standard Diagnosis
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _runAnalysis(enhanceWithLada: false),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bolt,
                                  color: Color(0xFF616161),
                                  size: 24,
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    'Standard Diagnosis',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: AppTheme.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryDark.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryDark),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _isEnhancingWithLada ? 'LADA Enhancement' : 'Classifying',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _processingStage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
