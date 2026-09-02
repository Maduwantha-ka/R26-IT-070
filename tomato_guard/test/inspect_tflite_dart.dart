import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';

void main() async {
  try {
    final interpreter = Interpreter.fromFile(File('assets/models/tomato_leaf_yolov8.tflite'));
    print('Inputs:');
    for (var i in interpreter.getInputTensors()) {
      print('  ${i.name}: ${i.shape} (${i.type})');
    }
    print('Outputs:');
    for (var i in interpreter.getOutputTensors()) {
      print('  ${i.name}: ${i.shape} (${i.type})');
    }
  } catch (e) {
    print('Error: $e');
  }
}
