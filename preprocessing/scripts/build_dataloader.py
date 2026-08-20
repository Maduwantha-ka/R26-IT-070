#!/usr/bin/env python3
import os
from pathlib import Path

# ensure script runs from repository root
os.chdir(Path(__file__).resolve().parents[2])

import yaml
import numpy as np
from PIL import Image
import torch
from torch.utils.data import Dataset, DataLoader, WeightedRandomSampler
from collections import Counter

from albumentations.pytorch import ToTensorV2
import sys
from pathlib import Path

# Add repo root to path so imports work when run directly
_repo_root = Path(__file__).resolve().parents[2]
if str(_repo_root) not in sys.path:
    sys.path.insert(0, str(_repo_root))

from preprocessing.scripts.augment import get_train_transform, get_val_transform


class PlantVillageDataset(Dataset):
    def __init__(self, root: Path, transform=None):
        self.root = Path(root)
        self.transform = transform
        self.classes = sorted([p.name for p in self.root.iterdir() if p.is_dir()])
        self.class_to_idx = {c: i for i, c in enumerate(self.classes)}
        self.samples = []
        for c in self.classes:
            for ext in ["*.JPG", "*.jpg", "*.JPEG", "*.jpeg", "*.PNG", "*.png"]:
                for p in sorted((self.root / c).glob(ext)):
                    self.samples.append((p, self.class_to_idx[c]))
        print(f"Loaded {len(self.samples)} images from {self.root}")

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        path, label = self.samples[idx]
        img = Image.open(path).convert("RGB")
        arr = np.array(img)
        if self.transform:
            sample = self.transform(image=arr)
            img_t = sample["image"]
        else:
            img_t = ToTensorV2()(image=arr)["image"]
        return img_t, int(label)


def get_dataloaders(config: dict):
    data_cfg = config.get("data", {})
    dl_cfg = config.get("dataloader", {})

    image_size = int(data_cfg.get("image_size", 256))
    split_dir = Path(data_cfg.get("split_dir", "data/split"))
    batch_size = int(dl_cfg.get("batch_size", 32))
    num_workers = int(dl_cfg.get("num_workers", 4))

    train_transform = get_train_transform(image_size)
    val_transform = get_val_transform(image_size)

    train_ds = PlantVillageDataset(split_dir / "train", transform=train_transform)
    val_ds = PlantVillageDataset(split_dir / "val", transform=val_transform)
    test_ds = PlantVillageDataset(split_dir / "test", transform=val_transform)

    # class counts for weighting (provided counts)
    class_counts = {
        "Tomato___Bacterial_spot": 1702,
        "Tomato___Early_blight": 800,
        "Tomato___Late_blight": 1527,
        "Tomato___Leaf_Mold": 761,
        "Tomato___Septoria_leaf_spot": 1417,
        "Tomato___Spider_mites Two-spotted_spider_mite": 1341,
        "Tomato___Target_Spot": 1123,
        "Tomato___Tomato_Yellow_Leaf_Curl_Virus": 4286,
        "Tomato___Tomato_mosaic_virus": 299,
        "Tomato___healthy": 1273,
    }

    # weights per class
    class_weights = {c: 1.0 / class_counts.get(c, 1) for c in train_ds.classes}

    print("\nClass                              Weight")
    for c in train_ds.classes:
        w = class_weights[c]
        print(f"{c:<35} {w:.6f}")

    # weights per sample
    weights = [class_weights[train_ds.classes[label]] for (_, label) in train_ds.samples]
    sampler = WeightedRandomSampler(weights, num_samples=len(train_ds), replacement=True)

    train_loader = DataLoader(train_ds, batch_size=batch_size, sampler=sampler, num_workers=num_workers)
    val_loader = DataLoader(val_ds, batch_size=batch_size, shuffle=False, num_workers=num_workers)
    test_loader = DataLoader(test_ds, batch_size=batch_size, shuffle=False, num_workers=num_workers)

    return {
        "train": train_loader,
        "val": val_loader,
        "test": test_loader,
        "class_names": train_ds.classes,
        "class_to_idx": train_ds.class_to_idx,
        "num_classes": len(train_ds.classes),
    }


if __name__ == "__main__":
    cfg_path = Path("configs/default.yaml")
    if not cfg_path.exists():
        print("configs/default.yaml not found — exiting")
        sys.exit(1)
    with cfg_path.open("r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    dl = get_dataloaders(config)
    train_loader = dl["train"]
    class_names = dl["class_names"]
    num_classes = dl["num_classes"]

    batch = next(iter(train_loader))
    images, labels = batch
    print("Batch image shape:", images.shape)
    print("Batch label shape:", labels.shape)
    print("Class names:", class_names)
    print("Num classes:", num_classes)
    img0 = images[0]
    print("First image min/max:", float(img0.min()), float(img0.max()))
