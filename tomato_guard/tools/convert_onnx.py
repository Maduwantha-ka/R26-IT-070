import os
import shutil
import numpy as np

# Set PATH so onnx2tf can find onnxsim
os.environ["PATH"] = "/opt/anaconda3/envs/yolo_env/bin:" + os.environ.get("PATH", "")

import onnx2tf

onnx_path = "assets/models/best.onnx"
out_dir = "assets/models/best_saved_model"
dummy_input = np.zeros((1, 3, 640, 640), dtype=np.float32)

print("Starting direct python onnx2tf conversion...")
try:
    onnx2tf.convert(
        input_onnx_file_path=onnx_path,
        output_folder_path=out_dir,
        test_data=dummy_input,
        output_integer_quantized_tflite=False,
    )
    print("onnx2tf conversion completed successfully.")
except Exception as e:
    print(f"Error during onnx2tf.convert: {e}")

target_tflite = "assets/models/tomato_leaf_yolov8.tflite"

found_tflite = None
possible_paths = [
    os.path.join(out_dir, "best_float32.tflite"),
    os.path.join(out_dir, "model_float32.tflite"),
    os.path.join(out_dir, "best.tflite"),
]

for p in possible_paths:
    if os.path.exists(p):
        found_tflite = p
        break

if not found_tflite and os.path.exists(out_dir):
    for root, dirs, files in os.walk(out_dir):
        for file in files:
            if file.endswith(".tflite"):
                found_tflite = os.path.join(root, file)
                break

if found_tflite:
    shutil.copy(found_tflite, target_tflite)
    print(f"✅ SUCCESS: Generated and copied {found_tflite} -> {target_tflite}")
else:
    print("Warning: .tflite file not found after conversion.")
