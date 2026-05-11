#!/usr/bin/env python3
"""
Cross-Channel Attention (XCA) module.
Applies channel-wise self-attention to learn relationships between channels.
"""

import torch
import torch.nn as nn
import torch.nn.functional as F


class XCA(nn.Module):
    """
    Cross-Channel Attention (XCA).
    
    Learns relationships between channels using:
    1. Linear projection to query/key/value
    2. Attention across channel dimension
    3. Output projection
    """

    def __init__(self, in_channels: int, dropout: float = 0.1):
        super().__init__()
        self.in_channels = in_channels
        self.dropout = nn.Dropout(dropout)

        # Reduce channels for efficient attention computation
        self.reduced_dim = max(in_channels // 4, 1)

        # Query, Key, Value projections
        self.q_proj = nn.Linear(in_channels, self.reduced_dim, bias=True)
        self.k_proj = nn.Linear(in_channels, self.reduced_dim, bias=True)
        self.v_proj = nn.Linear(in_channels, self.reduced_dim, bias=True)

        # Output projection back to original dimensions
        self.out_proj = nn.Linear(self.reduced_dim, in_channels, bias=True)

        # Scaling factor for attention
        self.scale = self.reduced_dim ** -0.5

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        x: (B, C, H, W)
        returns: (B, C, H, W) with channel attention applied
        """
        B, C, H, W = x.shape

        # Flatten spatial dimensions: (B, C, H*W)
        x_flat = x.view(B, C, H * W)

        # Average across spatial dimensions: (B, C)
        x_avg = x_flat.mean(dim=2)

        # Project to Q, K, V: each (B, reduced_dim)
        q = self.q_proj(x_avg)  # (B, reduced_dim)
        k = self.k_proj(x_avg)  # (B, reduced_dim)
        v = self.v_proj(x_avg)  # (B, reduced_dim)

        # Compute attention: (B, reduced_dim) x (B, reduced_dim) -> (B,)
        attn = torch.bmm(
            q.unsqueeze(1),  # (B, 1, reduced_dim)
            k.unsqueeze(2)   # (B, reduced_dim, 1)
        ).squeeze()  # (B,)
        attn = attn * self.scale
        attn = F.softmax(attn, dim=0)  # normalize across batch
        attn = self.dropout(attn)

        # Apply attention to values
        context = v * attn.unsqueeze(1)  # (B, reduced_dim)

        # Project back to original dimension
        out = self.out_proj(context)  # (B, C)

        # Expand back to spatial dimensions
        out = out.unsqueeze(-1).unsqueeze(-1)  # (B, C, 1, 1)
        out = out.expand_as(x)  # (B, C, H, W)

        return out
