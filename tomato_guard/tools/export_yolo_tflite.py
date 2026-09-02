import os
import shutil
import struct
from ultralytics import YOLO

def export():
    model_path = "assets/models/best.pt"
    if not os.path.exists(model_path):
        print(f"Error: {model_path} not found.")
        return

    print("Loading YOLO model...")
    model = YOLO(model_path)

    # Save class names to labels.txt
    labels_path = "assets/models/labels.txt"
    classes = model.names
    print(f"Model classes ({len(classes)}): {classes}")
    
    with open(labels_path, "w") as f:
        for idx in sorted(classes.keys()):
            f.write(f"{classes[idx]}\n")
    print(f"Saved labels to {labels_path}")

    print("Exporting model to ONNX (imgsz=640)...")
    onnx_path = model.export(
        format="onnx",
        imgsz=640,
        dynamic=False,
        simplify=True,
    )
    print(f"Exported ONNX model to: {onnx_path}")

    target_tflite = "assets/models/tomato_leaf_yolov8.tflite"

    # Convert ONNX to TFLite via onnx2tf
    print("Converting ONNX to TFLite via onnx2tf...")
    out_dir = "assets/models/best_saved_model"
    os.system(f"onnx2tf -i {onnx_path} -o {out_dir} -oiqt")

    # Locate generated float32 tflite file
    found_tflite = None
    possible_paths = [
        os.path.join(out_dir, "best_float32.tflite"),
        os.path.join(out_dir, "model_float32.tflite"),
    ]
    for p in possible_paths:
        if os.path.exists(p):
            found_tflite = p
            break

    if not found_tflite:
        for root, dirs, files in os.walk(out_dir):
            for file in files:
                if file.endswith(".tflite"):
                    found_tflite = os.path.join(root, file)
                    break

    if found_tflite:
        shutil.copy(found_tflite, target_tflite)
        print(f"Successfully generated and copied {found_tflite} -> {target_tflite}")
    else:
        print("Warning: Could not locate converted .tflite file.")

    # Inspect TFLite model tensors using flatbuffer parser
    if os.path.exists(target_tflite):
        inspect_and_save_io(target_tflite, "assets/models/model_io.txt")

def inspect_and_save_io(tflite_path, io_txt_path):
    with open(tflite_path, 'rb') as f:
        buf = f.read()

    root_offset = struct.unpack_from('<I', buf, 0)[0]
    
    def read_table(offset):
        vtable_offset_rel = struct.unpack_from('<i', buf, offset)[0]
        vtable_offset = offset - vtable_offset_rel
        vtable_len, table_len = struct.unpack_from('<HH', buf, vtable_offset)
        fields = {}
        for i in range(4, vtable_len, 2):
            field_offset = struct.unpack_from('<H', buf, vtable_offset + i)[0]
            field_idx = (i - 4) // 2
            if field_offset != 0:
                fields[field_idx] = offset + field_offset
        return fields

    def read_vector(offset, elem_size=4):
        vec_offset = offset + struct.unpack_from('<I', buf, offset)[0]
        length = struct.unpack_from('<I', buf, vec_offset)[0]
        return vec_offset + 4, length

    def read_string(offset):
        str_offset = offset + struct.unpack_from('<I', buf, offset)[0]
        length = struct.unpack_from('<I', buf, str_offset)[0]
        return buf[str_offset + 4 : str_offset + 4 + length].decode('utf-8', errors='ignore')

    root_fields = read_table(root_offset)
    output_lines = [f"=== TFLite Model I/O Metadata ({tflite_path}) ===", f"File Size: {len(buf)} bytes\n"]

    if 2 in root_fields: # subgraphs
        subgraphs_offset, subgraphs_len = read_vector(root_fields[2])
        for sg_i in range(subgraphs_len):
            sg_table_offset = subgraphs_offset + sg_i * 4 + struct.unpack_from('<I', buf, subgraphs_offset + sg_i * 4)[0]
            sg_fields = read_table(sg_table_offset)
            
            inputs = []
            if 1 in sg_fields:
                in_offset, in_len = read_vector(sg_fields[1], 4)
                inputs = [struct.unpack_from('<i', buf, in_offset + i * 4)[0] for i in range(in_len)]
            
            outputs = []
            if 2 in sg_fields:
                out_offset, out_len = read_vector(sg_fields[2], 4)
                outputs = [struct.unpack_from('<i', buf, out_offset + i * 4)[0] for i in range(out_len)]

            if 0 in sg_fields: # tensors
                t_offset, t_len = read_vector(sg_fields[0], 4)
                output_lines.append(f"Subgraph {sg_i}: Total Tensors = {t_len}")
                
                type_names = {0: 'FLOAT32', 1: 'FLOAT16', 2: 'INT32', 3: 'UINT8', 4: 'INT64', 6: 'BOOL', 9: 'INT8'}

                for idx in inputs:
                    tensor_table_offset = t_offset + idx * 4 + struct.unpack_from('<I', buf, t_offset + idx * 4)[0]
                    t_fields = read_table(tensor_table_offset)
                    shape = []
                    if 0 in t_fields:
                        sh_offset, sh_len = read_vector(t_fields[0], 4)
                        shape = [struct.unpack_from('<i', buf, sh_offset + s * 4)[0] for s in range(sh_len)]
                    t_type = struct.unpack_from('<b', buf, t_fields[1])[0] if 1 in t_fields else 0
                    t_name = read_string(t_fields[3]) if 3 in t_fields else ""
                    output_lines.append(f"INPUT [{idx}]: name='{t_name}', shape={shape}, type={type_names.get(t_type, t_type)}")

                for idx in outputs:
                    tensor_table_offset = t_offset + idx * 4 + struct.unpack_from('<I', buf, t_offset + idx * 4)[0]
                    t_fields = read_table(tensor_table_offset)
                    shape = []
                    if 0 in t_fields:
                        sh_offset, sh_len = read_vector(t_fields[0], 4)
                        shape = [struct.unpack_from('<i', buf, sh_offset + s * 4)[0] for s in range(sh_len)]
                    t_type = struct.unpack_from('<b', buf, t_fields[1])[0] if 1 in t_fields else 0
                    t_name = read_string(t_fields[3]) if 3 in t_fields else ""
                    output_lines.append(f"OUTPUT [{idx}]: name='{t_name}', shape={shape}, type={type_names.get(t_type, t_type)}")

    info_str = "\n".join(output_lines)
    print(info_str)
    with open(io_txt_path, "w") as f:
        f.write(info_str + "\n")
    print(f"Saved model I/O info to {io_txt_path}")

if __name__ == "__main__":
    export()
