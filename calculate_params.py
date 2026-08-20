#!/usr/bin/env python3
import sys
from pathlib import Path

# Add repo to path
REPO_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_ROOT))

import torch
from lada.modules import SLA, XCA, DCG

# Config settings
in_channels = 1408
kernel_size = 7
hidden_dim = 256
dropout = 0.1

# Instantiate modules
sla = SLA(in_channels=in_channels, kernel_size=kernel_size, dropout=dropout)
xca = XCA(in_channels=in_channels, dropout=dropout)
dcg = DCG(in_channels=in_channels, hidden_dim=hidden_dim, dropout=dropout)

# Count parameters
sla_params = sum(p.numel() for p in sla.parameters())
xca_params = sum(p.numel() for p in xca.parameters())
dcg_params = sum(p.numel() for p in dcg.parameters())

total_lada = sla_params + xca_params + dcg_params

print("=" * 70)
print("LADA Module Parameter Counts (with in_channels=1408)")
print("=" * 70)
print()
print(f"SLA (Squeeze-Linear Augmentation, kernel_size={kernel_size}):")
print(f"  - Total parameters: {sla_params:,}")
print()
print(f"XCA (Cross-Channel Attention):")
print(f"  - Reduced dimension: {max(in_channels // 4, 1)}")
print(f"  - Total parameters: {xca_params:,}")
print()
print(f"DCG (Dense Connection Group, hidden_dim={hidden_dim}):")
print(f"  - Total parameters: {dcg_params:,}")
print()
print("=" * 70)
print(f"TOTAL LADA Parameters: {total_lada:,}")
print("=" * 70)
print()
print("Breakdown:")
print(f"  SLA: {sla_params:,} ({100*sla_params/total_lada:.1f}%)")
print(f"  XCA: {xca_params:,} ({100*xca_params/total_lada:.1f}%)")
print(f"  DCG: {dcg_params:,} ({100*dcg_params/total_lada:.1f}%)")
print()
print("Impact when frozen:")
print(f"  - Freezing XCA saves: {xca_params:,} trainable params ({100*xca_params/total_lada:.1f}% of LADA)")
print(f"  - Freezing SLA saves: {sla_params:,} trainable params ({100*sla_params/total_lada:.1f}% of LADA)")
print(f"  - Freezing DCG saves: {dcg_params:,} trainable params ({100*dcg_params/total_lada:.1f}% of LADA)")
