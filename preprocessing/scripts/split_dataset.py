#!/usr/bin/env python3
import os
import sys
from pathlib import Path

# ensure script runs from repository root
os.chdir(Path(__file__).resolve().parents[2])

import shutil
from collections import defaultdict

import yaml
from sklearn.model_selection import train_test_split
from tqdm import tqdm


def load_config(path: Path):
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def main():
    repo_root = Path.cwd()
    config = load_config(repo_root / "configs" / "default.yaml")

    data_cfg = config.get("data", {})
    raw_dir = Path(data_cfg.get("raw_dir", "data/raw/plantvillage"))
    split_dir = Path(data_cfg.get("split_dir", "data/split"))
    train_split = float(data_cfg.get("train_split", 0.70))
    val_split = float(data_cfg.get("val_split", 0.15))
    test_split = float(data_cfg.get("test_split", 0.15))
    seed = int(data_cfg.get("seed", 42))

    # debug prints for verification
    print(f"Raw dir   : {raw_dir.resolve()}")
    print(f"Split dir : {split_dir.resolve()}")
    print(f"Exists    : {raw_dir.exists()}")

    image_exts = {".jpg", ".JPG", ".jpeg", ".JPEG", ".png", ".PNG"}

    if not raw_dir.exists():
        print(f"Raw dataset folder not found: {raw_dir}")
        sys.exit(1)

    class_dirs = [p for p in sorted(raw_dir.iterdir()) if p.is_dir()]

    copy_jobs = []  # list of tuples (src_path, dest_dir)
    summary = defaultdict(lambda: {"train": 0, "val": 0, "test": 0, "total": 0})

    for class_dir in class_dirs:
        images = [p for p in sorted(class_dir.iterdir()) if p.is_file() and p.suffix.lower() in image_exts]
        n = len(images)
        print(f"Found {n} images in {class_dir.name}")
        summary[class_dir.name]["total"] = n

        if n == 0:
            continue

        # split off test first
        if test_split > 0:
            rem, test_files = train_test_split(images, test_size=test_split, random_state=seed, shuffle=True)
        else:
            rem, test_files = images, []

        # then split rem into train and val
        if val_split > 0:
            rel_val = val_split / (train_split + val_split) if (train_split + val_split) > 0 else 0
            if rel_val > 0:
                train_files, val_files = train_test_split(rem, test_size=rel_val, random_state=seed, shuffle=True)
            else:
                train_files, val_files = rem, []
        else:
            train_files, val_files = rem, []

        summary[class_dir.name]["train"] = len(train_files)
        summary[class_dir.name]["val"] = len(val_files)
        summary[class_dir.name]["test"] = len(test_files)

        for p in train_files:
            dest = split_dir / "train" / class_dir.name
            copy_jobs.append((p, dest))
        for p in val_files:
            dest = split_dir / "val" / class_dir.name
            copy_jobs.append((p, dest))
        for p in test_files:
            dest = split_dir / "test" / class_dir.name
            copy_jobs.append((p, dest))

    # perform copying with progress bar
    for src, dest_dir in tqdm(copy_jobs, desc="Copying files", unit="file"):
        dest_dir.mkdir(parents=True, exist_ok=True)
        try:
            shutil.copy2(src, dest_dir / src.name)
        except Exception as e:
            print(f"Failed to copy {src} -> {dest_dir}: {e}")

    # print summary table
    header_fmt = "{:<40} {:>7} {:>7} {:>7} {:>8}"
    row_fmt = "{:<40} {:>7} {:>7} {:>7} {:>8}"
    print()
    print(header_fmt.format("Class", "Train", "Val", "Test", "Total"))
    print("-" * 72)

    totals = {"train": 0, "val": 0, "test": 0, "total": 0}
    for class_name in sorted(summary.keys()):
        s = summary[class_name]
        print(row_fmt.format(class_name, s["train"], s["val"], s["test"], s["total"]))
        totals["train"] += s["train"]
        totals["val"] += s["val"]
        totals["test"] += s["test"]
        totals["total"] += s["total"]

    print("-" * 72)
    print(row_fmt.format("TOTAL", totals["train"], totals["val"], totals["test"], totals["total"]))
    print()
    print("Split complete. Files saved to data/split")


if __name__ == "__main__":
    main()

