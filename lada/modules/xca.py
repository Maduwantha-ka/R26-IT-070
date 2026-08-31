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
    1. Linear projection to query/key/value per channel
    2. Attention across channel dimension (C, C)
    3. Output projection
    """

    def __init__(self, in_channels: int, dropout: float = 0.1):
        super().__init__()
        self.in_channels = in_channels
        self.dropout = nn.Dropout(dropout)

        # Feature dimension per channel for attention
        self.reduced_dim = max(in_channels // 4, 1)

        # Projections per channel. Input dim is 1 because each channel 
        # is represented by a single scalar after global average pooling.
        self.q_proj = nn.Linear(1, self.reduced_dim, bias=True)
        self.k_proj = nn.Linear(1, self.reduced_dim, bias=True)
        self.v_proj = nn.Linear(1, self.reduced_dim, bias=True)

        # Output projection back to 1 scalar per channel
        self.out_proj = nn.Linear(self.reduced_dim, 1, bias=True)

        # Scaling factor for attention
        self.scale = self.reduced_dim ** -0.5

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        x: (B, C, H, W)
        returns: (B, C, H, W) with channel attention applied
        """
        B, C, H, W = x.shape

        # Average across spatial dimensions to get channel statistics: (B, C)
        x_avg = x.view(B, C, -1).mean(dim=-1)

        # Treat each channel as an independent token of dimension 1: (B, C, 1)
        x_tokens = x_avg.unsqueeze(-1)

        # Project tokens to Q, K, V: each is (B, C, reduced_dim)
        q = self.q_proj(x_tokens)
        k = self.k_proj(x_tokens)
        v = self.v_proj(x_tokens)

        # Compute attention across channels: 
        # (B, C, reduced_dim) x (B, reduced_dim, C) -> (B, C, C)
        attn = torch.bmm(q, k.transpose(1, 2))
        attn = attn * self.scale
        attn = F.softmax(attn, dim=-1)  # normalize across the keys (channels)
        attn = self.dropout(attn)

        # Apply attention to values
        context = torch.bmm(attn, v)  # (B, C, C) x (B, C, reduced_dim) -> (B, C, reduced_dim)

        # Project back to original dimension (1 scalar per channel)
        out = self.out_proj(context)  # (B, C, 1)
        out = out.squeeze(-1)  # (B, C)

        # Expand back to spatial dimensions to form the additive feature map
        out = out.unsqueeze(-1).unsqueeze(-1)  # (B, C, 1, 1)
        out = out.expand_as(x)  # (B, C, H, W)

        return out
