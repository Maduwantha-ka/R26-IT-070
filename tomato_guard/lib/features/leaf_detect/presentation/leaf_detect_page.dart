import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../data/yolo_detector.dart';
import '../domain/detection.dart';
import 'boxes_painter.dart';

class LeafDetectPage extends StatefulWidget {
  final File? initialImageFile;

  const LeafDetectPage({
    super.key,
    this.initialImageFile,
  });

  @override
  State<LeafDetectPage> createState() => _LeafDetectPageState();
}

class _LeafDetectPageState extends State<LeafDetectPage> {
  final YoloDetector _detector = YoloDetector();
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  Size _imageSize = Size.zero;
  List<LeafDetection> _detections = [];
  
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initDetectorAndLoadInitial();
  }

  Future<void> _initDetectorAndLoadInitial() async {
    setState(() => _isProcessing = true);
    await _detector.loadModel();
    
    if (widget.initialImageFile != null) {
      await _processImage(widget.initialImageFile!);
    } else {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _detector.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        await _processImage(File(pickedFile.path));
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to pick image: $e";
      });
    }
  }

  Future<void> _processImage(File file) async {
    setState(() {
      _isProcessing = true;
      _imageFile = file;
      _errorMessage = null;
      _detections = [];
    });

    try {
      // Decode image dimensions
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception("Failed to decode image file.");
      }

      final Size size = Size(decoded.width.toDouble(), decoded.height.toDouble());

      // Run on-device YOLO detection
      final results = await _detector.detectFromBytes(bytes, confidenceThreshold: 0.30);

      if (mounted) {
        setState(() {
          _imageSize = size;
          _detections = results;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Inference error: $e";
          _isProcessing = false;
        });
      }
    }
  }

  double get _infectedAreaPct {
    if (_imageSize.width <= 0 || _imageSize.height <= 0) return 0.0;
    final double totalImageArea = _imageSize.width * _imageSize.height;
    if (totalImageArea <= 0) return 0.0;

    double diseasedBoxesArea = 0.0;
    for (final d in _detections) {
      if (!d.isHealthy) {
        diseasedBoxesArea += d.area;
      }
    }

    final double pct = (diseasedBoxesArea / totalImageArea) * 100.0;
    return pct.clamp(0.0, 100.0);
  }

  int get _diseasedCount => _detections.where((d) => !d.isHealthy).length;
  int get _healthyCount => _detections.where((d) => d.isHealthy).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F6),
      appBar: AppBar(
        title: const Text('Tomato leaf disease location'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Control Buttons (Gallery / Camera)
            _buildControlButtons(),

            const SizedBox(height: 16),

            // Image & CustomPaint Overlay Display Card
            _buildImageDisplayCard(),

            const SizedBox(height: 16),

            // Error or Processing Indicator
            if (_isProcessing) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2E7D32)),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Running YOLOv8 on-device detection...",
                        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Analysis Summary Card (Infected Area % & Count)
            if (_imageFile != null && !_isProcessing) _buildSummaryCard(),

            const SizedBox(height: 16),

            // List of Detected Disease Regions
            if (_imageFile != null && !_isProcessing) _buildDetectionsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageDisplayCard() {
    if (_imageFile == null) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.center_focus_strong, size: 64, color: Color(0xFF81C784)),
            SizedBox(height: 12),
            Text(
              "No photo selected",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            SizedBox(height: 4),
            Text(
              "Tap Gallery or Camera to locate disease regions",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.passthrough,
          children: [
            // Original Image
            Image.file(
              _imageFile!,
              fit: BoxFit.contain,
            ),

            // YOLO Bounding Boxes CustomPainter Overlay
            if (_detections.isNotEmpty && _imageSize != Size.zero)
              Positioned.fill(
                child: CustomPaint(
                  painter: BoxesPainter(
                    detections: _detections,
                    imageSize: _imageSize,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final double infectedPct = _infectedAreaPct;
    final Color statusColor = infectedPct > 30.0
        ? const Color(0xFFD32F2F)
        : (infectedPct > 5.0 ? const Color(0xFFF57C00) : const Color(0xFF388E3C));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Estimated Infected Area",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    "${infectedPct.toStringAsFixed(1)}%",
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "APPROXIMATE: Calculated from non-healthy bounding boxes vs total image surface area.",
              style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem("Diseased Spots", "$_diseasedCount", const Color(0xFFE53935)),
                _buildStatItem("Healthy Areas", "$_healthyCount", const Color(0xFF4CAF50)),
                _buildStatItem("Total Regions", "${_detections.length}", Colors.blueGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildDetectionsList() {
    if (_detections.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Text(
            "No disease region found. Try a closer leaf photo.",
            style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Detected Disease Regions",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _detections.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final d = _detections[index];
            final Color badgeColor = d.isHealthy ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: badgeColor.withOpacity(0.4), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 38,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.label,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Box: ${d.w.toInt()} × ${d.h.toInt()} px at (${d.x.toInt()}, ${d.y.toInt()})",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${(d.confidence * 100).toStringAsFixed(1)}%",
                      style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
