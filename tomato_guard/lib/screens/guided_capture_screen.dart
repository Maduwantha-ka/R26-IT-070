import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/quality_analyzer.dart';
import '../theme/app_theme.dart';

class GuidedCaptureScreen extends StatefulWidget {
  const GuidedCaptureScreen({Key? key}) : super(key: key);

  @override
  State<GuidedCaptureScreen> createState() => _GuidedCaptureScreenState();
}

class _GuidedCaptureScreenState extends State<GuidedCaptureScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  
  bool _isCameraInitialized = false;
  bool _isPermissionGranted = false;
  bool _isAnalyzing = false;
  bool _isTakingPicture = false;

  QualityAnalysisResult _currentQuality = const QualityAnalysisResult(
    CaptureQuality.fair, 
    "Analyzing environment..."
  );

  // Analyze every 350ms to keep UI smooth
  DateTime _lastAnalysisTime = DateTime.now();
  final int _analysisIntervalMs = 350;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.stopImageStream();
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(cameraController.description);
    }
  }

  Future<void> _checkPermissionsAndInit() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _isPermissionGranted = true);
      _setupCameras();
    } else {
      setState(() => _isPermissionGranted = false);
    }
  }

  Future<void> _setupCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final backCamera = _cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );
        await _initCamera(backCamera);
      }
    } catch (e) {
      debugPrint('Error setting up cameras: $e');
    }
  }

  Future<void> _initCamera(CameraDescription description) async {
    _cameraController = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      setState(() => _isCameraInitialized = true);
      
      // Start Image Stream for real-time analysis
      _cameraController!.startImageStream((CameraImage image) async {
        if (_isAnalyzing) return;

        final now = DateTime.now();
        if (now.difference(_lastAnalysisTime).inMilliseconds < _analysisIntervalMs) {
          return; // skip frame to save CPU
        }

        _isAnalyzing = true;
        _lastAnalysisTime = now;

        try {
          final result = await QualityAnalyzer.analyze(image);
          if (mounted) {
            setState(() => _currentQuality = result);
          }
        } catch (e) {
          debugPrint('Error analyzing frame: $e');
        } finally {
          _isAnalyzing = false;
        }
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isTakingPicture) {
      return;
    }

    setState(() => _isTakingPicture = true);

    try {
      // Stop stream to free resources during capture
      await _cameraController!.stopImageStream();
      
      final XFile imageFile = await _cameraController!.takePicture();
      
      if (mounted) {
        // Return the captured file to the caller
        Navigator.pop(context, imageFile);
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture image: $e'),
            backgroundColor: AppTheme.severitySevere,
          ),
        );
        setState(() => _isTakingPicture = false);
        // Restart stream
        _cameraController?.startImageStream((image) {});
      }
    }
  }

  Color _getQualityColor() {
    switch (_currentQuality.quality) {
      case CaptureQuality.good:
        return AppTheme.severityMild; // Greenish
      case CaptureQuality.fair:
        return AppTheme.severityModerate; // Yellow/Orange
      case CaptureQuality.poor:
        return AppTheme.severitySevere; // Red
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) {
      return _buildPermissionDeniedState();
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryDark),
        ),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          CameraPreview(_cameraController!),

          // 2. Overlay with Target Box
          _buildOverlay(size),

          // 3. Status Badge (Top)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: _buildStatusBanner(),
          ),

          // 4. Capture Controls (Bottom)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _buildCaptureControls(),
          ),
          
          // 5. Back Button (Top Left)
          Positioned(
            top: 50,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildOverlay(Size size) {
    final boxColor = _getQualityColor();
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.5),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: size.width * 0.75,
                height: size.height * 0.45,
                decoration: BoxDecoration(
                  color: Colors.black, // Punches a hole
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          // Bounding Box Borders
          Align(
            alignment: Alignment.center,
            child: Container(
              width: size.width * 0.75,
              height: size.height * 0.45,
              decoration: BoxDecoration(
                border: Border.all(
                  color: boxColor,
                  width: 3.0,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final boxColor = _getQualityColor();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: const EdgeInsets.only(top: 40), // avoid back button
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: boxColor.withOpacity(0.8), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _currentQuality.quality == CaptureQuality.good ? Icons.check_circle : Icons.info_outline,
            color: boxColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _currentQuality.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureControls() {
    final isGood = _currentQuality.quality == CaptureQuality.good;
    
    return Column(
      children: [
        if (_isTakingPicture)
          const CircularProgressIndicator(color: AppTheme.primaryDark)
        else
          GestureDetector(
            onTap: _captureImage,
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isGood ? AppTheme.primaryDark : Colors.white,
                  width: 4,
                ),
              ),
              child: Center(
                child: Container(
                  height: 65,
                  width: 65,
                  decoration: BoxDecoration(
                    color: isGood ? AppTheme.primaryDark : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: isGood
                      ? const Icon(Icons.camera_alt, color: Colors.white, size: 30)
                      : null,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Keep the leaf inside the box',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionDeniedState() {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(title: const Text('Camera Permission')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 64, color: AppTheme.primaryDark),
              const SizedBox(height: 16),
              const Text(
                'Camera Access Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'We need access to your camera to guide you in taking the best possible photo of your crop.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => openAppSettings(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryDark,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
