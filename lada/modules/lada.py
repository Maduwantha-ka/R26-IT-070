#!/usr/bin/env python3
"""
LADA-Net: EfficientNet-B2 backbone with Squeeze-Linear Augmentation,
Cross-Channel Attention, and Dense Connection Group modules.
"""

import os
from pathlib import Path

# ensure imports work from repo root
os.chdir(Path(__file__).resolve().parents[2])

import torch
import torch.nn as nn
import yaml

from lada.modules.sla import SLA
from lada.modules.xca import XCA
from lada.modules.dcg import DCG


def get_efficientnet_b2():
    """Load EfficientNet-B2 backbone from torchvision."""
    from torchvision.models import efficientnet_b2, EfficientNet_B2_Weights
    model = efficientnet_b2(weights=EfficientNet_B2_Weights.IMAGENET1K_V1)
    return model


class LADANet(nn.Module):
    """
    LADA-Net: Advanced plant disease detection model.
    
    Architecture:
    1. EfficientNet-B2 backbone (ImageNet pretrained)
    2. SLA module (Squeeze-Linear Augmentation)
    3. XCA module (Cross-Channel Attention)
    4. DCG module (Dense Connection Group)
    5. Global Average Pooling
    6. Classification head
    """

    def __init__(
        self,
        num_classes: int = 10,
        in_channels: int = 1408,
        sla_kernel_size: int = 7,
        dcg_hidden_dim: int = 256,
        dropout: float = 0.1,
    ):
        super().__init__()
        self.num_classes = num_classes

        # EfficientNet-B2 backbone
        self.backbone = get_efficientnet_b2()
        
        # Remove classification head, keep only feature extraction
        self.backbone = nn.Sequential(*list(self.backbone.children())[:-2])

        # LADA modules
        self.sla = SLA(in_channels=in_channels, kernel_size=sla_kernel_size, dropout=dropout)
        self.xca = XCA(in_channels=in_channels, dropout=dropout)
        self.dcg = DCG(in_channels=in_channels, hidden_dim=dcg_hidden_dim, dropout=dropout)

        # Classification head
        self.pool = nn.AdaptiveAvgPool2d(1)
        self.dropout = nn.Dropout(dropout)
        self.classifier = nn.Linear(in_channels, num_classes, bias=True)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        x: (B, 3, 256, 256) RGB images
        returns: (B, num_classes) logits
        """
        # Backbone: extract features
        features = self.backbone(x)  # (B, 1408, 8, 8)

        # LADA augmentation modules
        features = self.sla(features)  # Squeeze-Linear Augmentation
        features = features + self.xca(features)  # Cross-Channel Attention (residual)
        features = self.dcg(features)  # Dense Connection Group

        # Global average pooling
        features = self.pool(features)  # (B, 1408, 1, 1)
        features = features.view(features.size(0), -1)  # (B, 1408)

        # Classification head
        features = self.dropout(features)
        logits = self.classifier(features)  # (B, num_classes)

        return logits

    def freeze_backbone(self):
        """Freeze backbone parameters for transfer learning."""
        for param in self.backbone.parameters():
            param.requires_grad = False

    def unfreeze_backbone(self):
        """Unfreeze backbone parameters."""
        for param in self.backbone.parameters():
            param.requires_grad = True


def load_model_from_config(config_path: str, device: str = "cpu") -> LADANet:
    """Load LADANet model from config file."""
    with open(config_path, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    data_cfg = config.get("data", {})
    lada_cfg = config.get("lada", {})
    backbone_cfg = config.get("backbone", {})

    num_classes = int(data_cfg.get("num_classes", 10))
    in_channels = int(backbone_cfg.get("out_channels", 1408))
    sla_kernel_size = int(lada_cfg.get("sla_kernel_size", 7))
    dcg_hidden_dim = int(lada_cfg.get("dcg_hidden_dim", 256))
    dropout = float(lada_cfg.get("dropout", 0.1))

    model = LADANet(
        num_classes=num_classes,
        in_channels=in_channels,
        sla_kernel_size=sla_kernel_size,
        dcg_hidden_dim=dcg_hidden_dim,
        dropout=dropout,
    )

    model.to(device)
    return model


if __name__ == "__main__":
    # Demo: create model and run forward pass
    config_path = Path("configs/default.yaml")
    if not config_path.exists():
        print("Config file not found")
        exit(1)

    print("Loading model from config...")
    model = load_model_from_config(str(config_path), device="cpu")
    print(f"Model: {model.__class__.__name__}")
    print(f"Parameters: {sum(p.numel() for p in model.parameters()):,}")
    print(f"Trainable: {sum(p.numel() for p in model.parameters() if p.requires_grad):,}")

    # Test forward pass
    print("\nTesting forward pass...")
    dummy_input = torch.randn(2, 3, 256, 256)
    with torch.no_grad():
        output = model(dummy_input)
    print(f"Input shape: {dummy_input.shape}")
    print(f"Output shape: {output.shape}")
    print("Forward pass successful!")
