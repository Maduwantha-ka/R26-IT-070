#!/usr/bin/env python3
"""
Dense Connection Group (DCG) module.
Combines information from multiple scales with dense connections.
"""

import torch
import torch.nn as nn
import torch.nn.functional as F


class DCG(nn.Module):
    """
    Dense Connection Group (DCG).
    
    Implements dense connections across multiple convolutional layers:
    1. Multiple parallel conv branches at different scales
    2. Dense connections: each layer sees all previous outputs
    3. Concatenation and projection of concatenated features
    """

    def __init__(self, in_channels: int, hidden_dim: int = 128, dropout: float = 0.1):
        super().__init__()
        self.in_channels = in_channels
        self.hidden_dim = hidden_dim

        # Dense layers: each layer gets concatenation of all previous outputs
        self.conv1 = nn.Conv2d(in_channels, hidden_dim, kernel_size=3, padding=1, bias=True)
        self.conv2 = nn.Conv2d(in_channels + hidden_dim, hidden_dim, kernel_size=3, padding=1, bias=True)
        self.conv3 = nn.Conv2d(in_channels + 2 * hidden_dim, hidden_dim, kernel_size=3, padding=1, bias=True)

        # 1x1 convolutions for scale adjustment
        self.scale1x1 = nn.Conv2d(hidden_dim, hidden_dim, kernel_size=1, bias=True)
        self.scale2x1 = nn.Conv2d(hidden_dim, hidden_dim, kernel_size=1, bias=True)
        self.scale3x1 = nn.Conv2d(hidden_dim, hidden_dim, kernel_size=1, bias=True)

        # Final projection: concatenate all outputs and project back
        self.final_proj = nn.Conv2d(in_channels + 3 * hidden_dim, in_channels, kernel_size=1, bias=True)

        self.dropout = nn.Dropout(dropout)
        self.relu = nn.ReLU(inplace=True)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        x: (B, C, H, W)
        returns: (B, C, H, W)
        """
        # Layer 1: input -> conv1
        d1 = self.conv1(x)  # (B, hidden_dim, H, W)
        d1 = self.relu(d1)
        d1_scaled = self.scale1x1(d1)

        # Layer 2: [input, d1] -> conv2
        d2_in = torch.cat([x, d1], dim=1)  # (B, C + hidden_dim, H, W)
        d2 = self.conv2(d2_in)  # (B, hidden_dim, H, W)
        d2 = self.relu(d2)
        d2_scaled = self.scale2x1(d2)

        # Layer 3: [input, d1, d2] -> conv3
        d3_in = torch.cat([x, d1, d2], dim=1)  # (B, C + 2*hidden_dim, H, W)
        d3 = self.conv3(d3_in)  # (B, hidden_dim, H, W)
        d3 = self.relu(d3)
        d3_scaled = self.scale3x1(d3)

        # Concatenate all outputs: [input, d1, d2, d3]
        out = torch.cat([x, d1_scaled, d2_scaled, d3_scaled], dim=1)  # (B, C + 3*hidden_dim, H, W)

        # Project back to original dimension
        out = self.final_proj(out)  # (B, C, H, W)
        out = self.dropout(out)

        # Residual connection
        out = x + out

        return out
