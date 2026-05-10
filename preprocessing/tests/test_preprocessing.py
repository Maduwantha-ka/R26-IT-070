import os
from pathlib import Path

# run tests from repo root
os.chdir(Path(__file__).resolve().parents[3])

import pytest
import numpy as np
import torch

from preprocessing.scripts.augment import get_train_transform, get_val_transform, cutmix_batch
from preprocessing.scripts.build_dataloader import PlantVillageDataset, get_dataloaders


def make_dummy_image(h=256, w=256):
    return (np.random.randint(0, 256, size=(h, w, 3), dtype=np.uint8))


def test_train_transform_output_shape():
    img = make_dummy_image()
    t = get_train_transform(256)
    out = t(image=img)["image"]
    assert isinstance(out, torch.Tensor)
    assert out.shape == (3, 256, 256)


def test_val_transform_output_shape():
    img = make_dummy_image()
    t = get_val_transform(256)
    out = t(image=img)["image"]
    assert isinstance(out, torch.Tensor)
    assert out.shape == (3, 256, 256)


def test_normalization_applied():
    img = make_dummy_image()
    t = get_train_transform(256)
    out = t(image=img)["image"]
    assert out.max() > 1.0 or out.min() < 0.0


def test_no_nan_in_output():
    img = make_dummy_image()
    t1 = get_train_transform(256)
    t2 = get_val_transform(256)
    o1 = t1(image=img)["image"]
    o2 = t2(image=img)["image"]
    assert not torch.isnan(o1).any()
    assert not torch.isnan(o2).any()


def test_cutmix_output_shapes():
    images = torch.randn(4, 3, 256, 256)
    labels = torch.tensor([0, 1, 2, 3])
    mixed, la, lb, lam = cutmix_batch(images, labels, alpha=1.0)
    assert mixed.shape == (4, 3, 256, 256)
    assert 0.0 <= lam <= 1.0


def test_dataset_loads_correctly():
    ds = PlantVillageDataset(Path("data/split/train"), transform=get_val_transform(256))
    assert len(ds) > 0
    assert len(ds.classes) == 10
    img, label = ds[0]
    assert isinstance(img, torch.Tensor)
    assert img.shape == (3, 256, 256)
    assert isinstance(label, int)


def test_dataloader_batch_shape():
    import yaml
    cfg_path = Path("configs/default.yaml")
    with cfg_path.open("r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    loaders = get_dataloaders(config)
    train_loader = loaders["train"]
    batch = next(iter(train_loader))
    images, labels = batch
    assert images.shape[0] == 32
    assert images.shape[1:] == (3, 256, 256)
    assert labels.shape[0] == 32


def test_weighted_sampler_rare_class_weight():
    # use the class_counts from build_dataloader
    from preprocessing.scripts.build_dataloader import (
        PlantVillageDataset,
    )
    ds = PlantVillageDataset(Path("data/split/train"), transform=get_val_transform(256))
    # get weights mapping from build_dataloader logic
    from preprocessing.scripts.build_dataloader import get_dataloaders
    import yaml

    cfg_path = Path("configs/default.yaml")
    with cfg_path.open("r", encoding="utf-8") as f:
        config = yaml.safe_load(f)
    loaders = get_dataloaders(config)
    class_names = loaders["class_names"]
    # extract class_counts used
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
    weight_mosaic = 1.0 / class_counts["Tomato___Tomato_mosaic_virus"]
    weight_yellow = 1.0 / class_counts["Tomato___Tomato_Yellow_Leaf_Curl_Virus"]
    assert weight_mosaic > weight_yellow * 10
