import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';

void inspectModel(String path) {
  try {
    final interpreter = Interpreter.fromFile(File(path));
    print("--- Model: $path ---");
    print("Input tensors:");
    for (var tensor in interpreter.getInputTensors()) {
      print("  ${tensor.name} : ${tensor.type} : ${tensor.shape}");
    }
    print("Output tensors:");
    for (var tensor in interpreter.getOutputTensors()) {
      print("  ${tensor.name} : ${tensor.type} : ${tensor.shape}");
    }
    interpreter.close();
  } catch (e) {
    print("Error inspecting $path: $e");
  }
}

void main() async {
  inspectModel('assets/models/alas_net_NO_SLA.tflite');
  inspectModel('assets/models/alas_net_With_Lada_SLA_.tflite');
}
