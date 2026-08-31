import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';

void main() {
  test('Inspect tflite model', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final file = File('assets/models/student3.tflite');
    final interpreter = Interpreter.fromFile(file);
    
    print('IN:');
    for (var i = 0; i < interpreter.getInputTensors().length; i++) {
      final tensor = interpreter.getInputTensor(i);
      print('  $i: shape=${tensor.shape}, type=${tensor.type}');
    }
    
    print('OUT:');
    for (var i = 0; i < interpreter.getOutputTensors().length; i++) {
      final tensor = interpreter.getOutputTensor(i);
      print('  $i: shape=${tensor.shape}, type=${tensor.type}');
    }
  });
}
