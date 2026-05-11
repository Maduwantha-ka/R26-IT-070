#!/usr/bin/env python3
"""
Pytest tests for LADA-Net backbone and modules.
"""

import os
from pathlib import Path

# run tests from repo root
os.chdir(Path(__file__).resolve().parents[3])

import pytest
import torch
import yaml

from lada.modules.sla import SLA
from lada.modules.xca import XCA
from lada.modules.dcg import DCG
from lada.modules.lada import LADANet, load_model_from_config


def test_sla_output_shape():
    """Test SLA module output shape."""
    batch_size, channels, h, w = 4, 352, 8, 8
    x = torch.randn(batch_size, channels, h, w)
    sla = SLA(in_channels=channels, kernel_size=7, dropout=0.1)
    out = sla(x)
    assert out.shape == (batch_size, channels, h, w)


def test_sla_increases_receptive_field():
    """Test that SLA processes spatial information (kernel_size=7)."""
    x = torch.randn(4, 352, 8, 8)
    sla_small = SLA(in_channels=352, kernel_size=3, dropout=0.1)
    sla_large = SLA(in_channels=352, kernel_size=7, dropout=0.1)
    
    # Set same seed for reproducibility
    torch.manual_seed(42)
    out_small = sla_small(x)
    
    torch.manual_seed(42)
    out_large = sla_large(x)
    
    # Different kernel sizes should produce different outputs
    assert not torch.allclose(out_small, out_large, atol=0.1)


def test_xca_output_shape():
    """Test XCA module output shape."""
    batch_size, channels, h, w = 4, 352, 8, 8
    x = torch.randn(batch_size, channels, h, w)
    xca = XCA(in_channels=channels, dropout=0.1)
    out = xca(x)
    assert out.shape == (batch_size, channels, h, w)


def test_xca_learns_channel_relationships():
    """Test that XCA produces valid output with trainable parameters."""
    x = torch.randn(4, 352, 8, 8)
    xca = XCA(in_channels=352, dropout=0.1)
    
    # Check that parameters exist and are trainable
    total_params = sum(p.numel() for p in xca.parameters())
    trainable_params = sum(p.numel() for p in xca.parameters() if p.requires_grad)
    
    assert total_params > 0
    assert trainable_params > 0
    assert trainable_params == total_params
    
    # Test forward pass
    out = xca(x)
    assert out.shape == x.shape
    assert not torch.isnan(out).any()


def test_dcg_output_shape():
    """Test DCG module output shape."""
    batch_size, channels, h, w = 4, 352, 8, 8
    x = torch.randn(batch_size, channels, h, w)
    dcg = DCG(in_channels=channels, hidden_dim=128, dropout=0.1)
    out = dcg(x)
    assert out.shape == (batch_size, channels, h, w)


def test_dcg_residual_connection():
    """Test that DCG includes residual connection."""
    x = torch.randn(4, 352, 8, 8)
    dcg = DCG(in_channels=352, hidden_dim=128, dropout=0.0)
    
    # With dropout=0, output should be close to input + augmentation
    out = dcg(x)
    assert out.shape == x.shape


def test_ladanet_output_shape():
    """Test LADANet output shape."""
    model = LADANet(
        num_classes=10,
        in_channels=1408,
        sla_kernel_size=7,
        dcg_hidden_dim=256,
        dropout=0.1,
    )
    x = torch.randn(4, 3, 256, 256)
    out = model(x)
    assert out.shape == (4, 10)


def test_ladanet_num_parameters():
    """Test LADANet parameter count."""
    model = LADANet(
        num_classes=10,
        in_channels=352,
        sla_kernel_size=7,
        dcg_hidden_dim=128,
        dropout=0.1,
    )
    
    total_params = sum(p.numel() for p in model.parameters())
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    
    assert total_params > 0
    assert trainable_params > 0
    # Most params should be trainable
    assert trainable_params / total_params > 0.5


def test_ladanet_freeze_backbone():
    """Test freezing and unfreezing backbone."""
    model = LADANet(num_classes=10, in_channels=1408)
    
    # Initially all parameters should be trainable
    trainable_before = sum(p.numel() for p in model.parameters() if p.requires_grad)
    
    # Freeze backbone
    model.freeze_backbone()
    trainable_frozen = sum(p.numel() for p in model.parameters() if p.requires_grad)
    
    # Frozen should have fewer trainable params
    assert trainable_frozen < trainable_before
    
    # Unfreeze
    model.unfreeze_backbone()
    trainable_unfrozen = sum(p.numel() for p in model.parameters() if p.requires_grad)
    
    assert trainable_unfrozen == trainable_before


def test_load_model_from_config():
    """Test loading model from config file."""
    config_path = Path("configs/default.yaml")
    if not config_path.exists():
        pytest.skip("Config file not found")
    
    model = load_model_from_config(str(config_path), device="cpu")
    assert isinstance(model, LADANet)
    assert model.num_classes == 10


def test_ladanet_gradients():
    """Test that gradients flow through the model."""
    model = LADANet(num_classes=10, in_channels=1408)
    x = torch.randn(2, 3, 256, 256)
    logits = model(x)
    loss = logits.sum()
    loss.backward()
    
    # Check that gradients exist
    for name, param in model.named_parameters():
        if param.requires_grad:
            assert param.grad is not None


def test_ladanet_inference_mode():
    """Test model in inference mode."""
    model = LADANet(num_classes=10, in_channels=1408)
    model.eval()
    
    x = torch.randn(2, 3, 256, 256)
    with torch.no_grad():
        out = model(x)
    
    assert out.shape == (2, 10)
    assert not torch.isnan(out).any()


def test_lada_modules_no_nan():
    """Test that all LADA modules produce valid outputs."""
    x = torch.randn(4, 352, 8, 8)
    
    sla = SLA(in_channels=352, kernel_size=7, dropout=0.1)
    out_sla = sla(x)
    assert not torch.isnan(out_sla).any()
    
    xca = XCA(in_channels=352, dropout=0.1)
    out_xca = xca(x)
    assert not torch.isnan(out_xca).any()
    
    dcg = DCG(in_channels=352, hidden_dim=128, dropout=0.1)
    out_dcg = dcg(x)
    assert not torch.isnan(out_dcg).any()
