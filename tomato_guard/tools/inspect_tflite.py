import tensorflow as tf
import os

model_path = "assets/models/tomato_leaf_yolov8.tflite"

print(f"Inspecting TFLite model: {model_path}")
interpreter = tf.lite.Interpreter(model_path=model_path)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

io_summary = []
io_summary.append(f"Model File: {model_path} ({os.path.getsize(model_path)} bytes)\n")

io_summary.append("--- INPUT TENSORS ---")
for i, detail in enumerate(input_details):
    io_summary.append(f"Input {i}: Name='{detail['name']}', Shape={detail['shape']}, Type={detail['dtype']}")

io_summary.append("\n--- OUTPUT TENSORS ---")
for i, detail in enumerate(output_details):
    io_summary.append(f"Output {i}: Name='{detail['name']}', Shape={detail['shape']}, Type={detail['dtype']}")

text_content = "\n".join(io_summary)
print("\n" + text_content)

with open("assets/models/model_io.txt", "w") as f:
    f.write(text_content + "\n")

print("\nWrote tensor metadata to assets/models/model_io.txt")
