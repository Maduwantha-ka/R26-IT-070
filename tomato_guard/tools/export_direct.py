import os
import shutil
from ultralytics import YOLO

print("Loading best.pt model...")
model = YOLO("assets/models/best.pt")

print("Exporting best.pt to TFLite (Float32, imgsz=640)...")
res = model.export(format="tflite", imgsz=640, int8=False)
print(f"Ultralytics export result: {res}")

target_tflite = "assets/models/tomato_leaf_yolov8.tflite"

found_tflite = None
if res and os.path.exists(res):
    found_tflite = res
else:
    for root, dirs, files in os.walk("assets/models"):
        for f in files:
            if f.endswith(".tflite") and "tomato_leaf.tflite" not in f and "student3.tflite" not in f:
                found_tflite = os.path.join(root, f)
                break

if found_tflite and found_tflite != target_tflite:
    shutil.copy(found_tflite, target_tflite)
    print(f"✅ SUCCESS: Copied {found_tflite} -> {target_tflite}")

if os.path.exists(target_tflite):
    print(f"✅ Target TFLite file verified: {target_tflite} ({os.path.getsize(target_tflite)} bytes)")
