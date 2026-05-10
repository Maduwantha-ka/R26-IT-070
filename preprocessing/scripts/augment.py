#!/usr/bin/env python3
import os
from pathlib import Path

# ensure script runs from repository root
os.chdir(Path(__file__).resolve().parents[2])

import sys
import random
import inspect
import numpy as np
from PIL import Image
import matplotlib.pyplot as plt

import albumentations as A
from albumentations.pytorch import ToTensorV2

import torch


def _affine_transform():
    params = inspect.signature(A.Affine).parameters
    if "translate_percent" in params:
        return A.Affine(translate_percent=0.05, scale=(0.95, 1.05), rotate=(-15, 15), p=0.4)
    if "shift_limit" in params:
        return A.Affine(shift_limit=0.05, scale_limit=0.05, rotate_limit=15, p=0.4)
    if "shift_limit_x" in params:
        return A.Affine(
            shift_limit_x=(-0.05, 0.05),
            shift_limit_y=(-0.05, 0.05),
            scale=(0.95, 1.05),
            rotate=(-15, 15),
            p=0.4,
        )
    return A.Affine(p=0.4)


def _coarse_dropout():
    params = inspect.signature(A.CoarseDropout).parameters
    if "num_holes_range" in params:
        return A.CoarseDropout(
            num_holes_range=(1, 8),
            hole_height_range=(8, 32),
            hole_width_range=(8, 32),
            p=0.3,
        )
    if "max_holes" in params:
        return A.CoarseDropout(max_holes=8, max_height=32, max_width=32, p=0.3)
    if "num_holes_max" in params:
        return A.CoarseDropout(num_holes_max=8, max_height=32, max_width=32, p=0.3)
    return A.CoarseDropout(p=0.3)


def get_train_transform(image_size=256):
    return A.Compose(
        [
            A.Resize(image_size, image_size),
            A.HorizontalFlip(p=0.5),
            A.VerticalFlip(p=0.2),
            A.RandomRotate90(p=0.3),
            _affine_transform(),
            A.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2, hue=0.1, p=0.5),
            A.ElasticTransform(alpha=1, sigma=50, p=0.3),
            A.GridDistortion(p=0.2),
            _coarse_dropout(),
            A.Normalize(mean=(0.485, 0.456, 0.406), std=(0.229, 0.224, 0.225)),
            ToTensorV2(),
        ],
        p=1.0,
    )


def get_val_transform(image_size=256):
    return A.Compose(
        [
            A.Resize(image_size, image_size),
            A.Normalize(mean=(0.485, 0.456, 0.406), std=(0.229, 0.224, 0.225)),
            ToTensorV2(),
        ],
        p=1.0,
    )


def cutmix_batch(images: torch.Tensor, labels: torch.Tensor, alpha: float = 1.0):
    """
    images: (B, C, H, W) torch.Tensor
    labels: (B,) torch.Tensor
    returns: mixed_images, labels_a, labels_b, lam
    """
    assert images.dim() == 4
    B, C, H, W = images.shape
    if B == 1:
        return images, labels, labels, 1.0

    lam = np.random.beta(alpha, alpha) if alpha > 0 else 1.0
    rand_index = torch.randperm(B)
    labels_a = labels
    labels_b = labels[rand_index]

    # determine box
    cut_rat = np.sqrt(1.0 - lam)
    cut_w = int(W * cut_rat)
    cut_h = int(H * cut_rat)

    # uniform center
    cx = np.random.randint(W)
    cy = np.random.randint(H)

    bbx1 = np.clip(cx - cut_w // 2, 0, W)
    bby1 = np.clip(cy - cut_h // 2, 0, H)
    bbx2 = np.clip(cx + cut_w // 2, 0, W)
    bby2 = np.clip(cy + cut_h // 2, 0, H)

    mixed_images = images.clone()
    mixed_images[:, :, bby1:bby2, bbx1:bbx2] = images[rand_index, :, bby1:bby2, bbx1:bbx2]

    # adjust lambda to exactly match pixel ratio
    area = (bbx2 - bbx1) * (bby2 - bby1)
    lam = 1.0 - area / float(W * H)

    return mixed_images, labels_a, labels_b, lam


if __name__ == "__main__":
    # demo: load one image, apply train transform and save 4 augmented versions
    docs_dir = Path("docs")
    docs_dir.mkdir(exist_ok=True)

    train_dir = Path("data") / "split" / "train"
    if not train_dir.exists():
        print("No training data found at data/split/train — skipping demo")
        sys.exit(0)

    # pick first class and image
    try:
        first_class = next(train_dir.iterdir())
        first_image = next(first_class.glob("*.jpg"))
    except StopIteration:
        print("No images found in training folder — skipping demo")
        sys.exit(0)

    img = Image.open(first_image).convert("RGB")
    arr = np.array(img)

    transform = get_train_transform(256)

    tensors = []
    for i in range(4):
        out = transform(image=arr)["image"]
        tensors.append(out)

    # print shape and min/max
    t0 = tensors[0]
    print("Tensor shape:", t0.shape)
    print("Min/Max:", float(t0.min()), float(t0.max()))

    # visualize 4 images
    fig, axes = plt.subplots(1, 4, figsize=(12, 4))
    for i, ax in enumerate(axes):
        img_np = tensors[i].permute(1, 2, 0).numpy()
        # unnormalize for display
        img_np = img_np * np.array((0.229, 0.224, 0.225)) + np.array((0.485, 0.456, 0.406))
        img_np = np.clip(img_np, 0, 1)
        ax.imshow(img_np)
        ax.axis("off")

    plt.tight_layout()
    plt.savefig(docs_dir / "augmentation_sample.png", dpi=150)
    print("Saved augmentation sample to docs/augmentation_sample.png")

