import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() async {
  try {
    final interpreter = Interpreter.fromFile('assets/models/student3.tflite');
    print('Model loaded');
    
    print('Inputs:');
    for (var i = 0; i < interpreter.getInputTensors().length; i++) {
      print('  $i: ${interpreter.getInputTensor(i).shape} - ${interpreter.getInputTensor(i).type}');
    }
    
    print('Outputs:');
    for (var i = 0; i < interpreter.getOutputTensors().length; i++) {
      print('  $i: ${interpreter.getOutputTensor(i).shape} - ${interpreter.getOutputTensor(i).type}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
