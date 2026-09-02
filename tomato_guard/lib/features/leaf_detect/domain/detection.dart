class LeafDetection {
  final String label;
  final double confidence; // 0..1
  final double x; // left in original image pixels
  final double y; // top in original image pixels
  final double w; // width in original image pixels
  final double h; // height in original image pixels
  final bool isHealthy;

  LeafDetection({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.isHealthy,
  });

  double get area => w * h;

  @override
  String toString() {
    return 'LeafDetection($label, ${(confidence * 100).toStringAsFixed(1)}%, box: [${x.toInt()}, ${y.toInt()}, ${w.toInt()}, ${h.toInt()}])';
  }
}
