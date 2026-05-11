#!/usr/bin/env python3
"""
Squeeze-and-Linearly-interacting Augmentation (SLA) module.
Applies spatial and channel augmentation to feature maps.
"""

import torch
import torch.nn as nn
import torch.nn.functional as F


class SLA(nn.Module):
    """
    Squeeze-and-Linearly-interacting Augmentation.
    
    Performs:
    1. Channel squeeze via global average pooling
    2. Linear interaction between spatial and channel dimensions
    3. Spatial augmentation via convolution
    4. Channel augmentation via linear transformation
    """

    def __init__(self, in_channels: int, kernel_size: int = 7, dropout: float = 0.1):
        super().__init__()
        self.in_channels = in_channels
        self.kernel_size = kernel_size
        self.dropout = nn.Dropout(dropout)

        # Squeeze module: global average pooling to get channel-wise statistics
        self.squeeze = nn.AdaptiveAvgPool2d(1)

        # Spatial augmentation: larger kernel for spatial context
        padding = kernel_size // 2
        self.spatial_conv = nn.Conv2d(
            in_channels, in_channels, kernel_size=kernel_size,
            padding=padding, groups=1, bias=True
        )

        # Channel augmentation: linear transformation
        self.channel_fc = nn.Linear(in_channels, in_channels, bias=True)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        x: (B, C, H, W)
        returns: (B, C, H, W) with augmented features
        """
        B, C, H, W = x.shape

        # Squeeze: get channel-wise global statistics
        squeeze = self.squeeze(x)  # (B, C, 1, 1)
        squeeze = squeeze.view(B, C)  # (B, C)

        # Channel augmentation: apply linear transformation and reshape
        channel_aug = self.channel_fc(squeeze)  # (B, C)
        channel_aug = channel_aug.unsqueeze(-1).unsqueeze(-1)  # (B, C, 1, 1)
        channel_aug = channel_aug.expand_as(x)  # (B, C, H, W)

        # Spatial augmentation: apply spatial convolution
        spatial_aug = self.spatial_conv(x)  # (B, C, H, W)

        # Combine augmentations
        out = x + spatial_aug + channel_aug
        out = self.dropout(out)

        return out
