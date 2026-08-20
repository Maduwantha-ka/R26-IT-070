#!/usr/bin/env python3
"""
Training script for LADA-Net plant disease classification.
Backbone: EfficientNet-B2 (1408 channels, 8x8 features)
LADA module: SLA → XCA → DCG
Dataset: 10 tomato disease classes
"""

import os
import sys
from pathlib import Path

# Fix working directory for imports
os.chdir(Path(__file__).resolve().parents[1])
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.optim import AdamW
from torch.optim.lr_scheduler import CosineAnnealingLR
import timm
import yaml
import numpy as np
from tqdm import tqdm
import csv
from datetime import datetime

from lada.modules import SLA, XCA, DCG
from preprocessing.scripts.build_dataloader import get_dataloaders


class FocalLoss(nn.Module):
    """Focal loss for handling class imbalance. Reduces loss for easy examples."""
    
    def __init__(self, gamma=2.0, alpha=None, reduction="mean"):
        super().__init__()
        self.gamma = gamma
        self.alpha = alpha
        self.reduction = reduction
    
    def forward(self, inputs, targets):
        ce_loss = F.cross_entropy(inputs, targets, reduction="none", weight=self.alpha)
        pt = torch.exp(-ce_loss)
        focal_loss = (1 - pt) ** self.gamma * ce_loss
        if self.reduction == "mean":
            return focal_loss.mean()
        return focal_loss.sum()


class ALASNet(nn.Module):
    """LADA-enhanced EfficientNet-B2 for plant disease detection."""
    
    def __init__(self, config):
        super().__init__()
        num_classes = config["data"]["num_classes"]
        
        # Load EfficientNet-B2 backbone
        backbone = timm.create_model("efficientnet_b2", pretrained=True)
        self.backbone = nn.Sequential(*list(backbone.children())[:-2])
        
        # LADA modules (SLA → XCA → DCG)
        self.sla = SLA(in_channels=1408, kernel_size=7, dropout=0.1)
        self.xca = XCA(in_channels=1408, dropout=0.1)
        self.dcg = DCG(in_channels=1408, hidden_dim=256, dropout=0.1)
        
        # Classification head
        self.classifier = nn.Linear(1408, num_classes)
        # Note: other task heads (e.g., severity, auxillary) added by teammates
    
    def forward(self, x):
        # Backbone feature extraction
        feat = self.backbone(x)  # (B, 1408, 8, 8)
        
        # LADA processing
        feat_att = self.sla(feat)
        feat_att = self.xca(feat_att)
        feat_final = self.dcg(feat_att)
        
        # Global average pooling
        feat_pool = F.adaptive_avg_pool2d(feat_final, 1).flatten(1)  # (B, 1408)
        
        # Classification
        class_logits = self.classifier(feat_pool)  # (B, num_classes)
        disease_logits = feat_pool  # auxiliary output for disease detection gate
        
        return class_logits, disease_logits


def train_one_epoch(model, loader, optimizer, focal_loss, device, epoch, num_epochs):
    """Train for one epoch."""
    model.train()
    running_loss = 0.0
    correct = 0
    total = 0
    
    with tqdm(loader, desc=f"Epoch {epoch+1}/{num_epochs}", leave=False) as pbar:
        for images, labels in pbar:
            images, labels = images.to(device), labels.to(device)
            
            optimizer.zero_grad()
            class_logits, disease_logits = model(images)
            
            # Focal loss on class predictions
            loss_class = focal_loss(class_logits, labels)
            # Auxiliary loss on disease logits (regression to label as auxiliary)
            loss_aux = F.cross_entropy(disease_logits, labels) * 0.3
            loss = loss_class + loss_aux
            
            loss.backward()
            optimizer.step()
            
            running_loss += loss.item()
            _, predicted = torch.max(class_logits, 1)
            correct += (predicted == labels).sum().item()
            total += labels.size(0)
            pbar.set_postfix({"loss": f"{running_loss / (total / loader.batch_size):.4f}"})
    
    avg_loss = running_loss / len(loader)
    accuracy = 100.0 * correct / total
    return avg_loss, accuracy


def validate(model, loader, focal_loss, device):
    """Validate on a dataset."""
    model.eval()
    running_loss = 0.0
    correct = 0
    total = 0
    
    with torch.no_grad():
        for images, labels in loader:
            images, labels = images.to(device), labels.to(device)
            
            class_logits, disease_logits = model(images)
            loss_class = focal_loss(class_logits, labels)
            loss_aux = F.cross_entropy(disease_logits, labels) * 0.3
            loss = loss_class + loss_aux
            
            running_loss += loss.item()
            _, predicted = torch.max(class_logits, 1)
            correct += (predicted == labels).sum().item()
            total += labels.size(0)
    
    avg_loss = running_loss / len(loader)
    accuracy = 100.0 * correct / total
    return avg_loss, accuracy


def main():
    """Main training loop."""
    # Load configuration
    with open("configs/default.yaml", "r") as f:
        config = yaml.safe_load(f)
    
    # Create directories
    Path("checkpoints").mkdir(exist_ok=True)
    Path("logs").mkdir(exist_ok=True)
    
    # Device
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")
    
    # Initialize dataloaders
    dataloaders = get_dataloaders(config)
    train_loader = dataloaders["train"]
    val_loader = dataloaders["val"]
    
    # Initialize model
    model = ALASNet(config).to(device)
    print(f"Model loaded: {sum(p.numel() for p in model.parameters()):,} parameters")
    
    # Loss, optimizer, scheduler
    class_weights = torch.ones(config["data"]["num_classes"], device=device)
    focal_loss = FocalLoss(gamma=2.0, alpha=class_weights)
    optimizer = AdamW(model.parameters(), lr=1e-4, weight_decay=0.01)
    scheduler = CosineAnnealingLR(optimizer, T_max=50)
    
    # CSV logging
    log_file = Path("logs/training_log.csv")
    with open(log_file, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["epoch", "train_loss", "train_acc", "val_loss", "val_acc", "lr"])
    
    best_val_acc = 0.0
    best_epoch = 0
    
    # Training loop
    for epoch in range(50):
        train_loss, train_acc = train_one_epoch(model, train_loader, optimizer, focal_loss, device, epoch, 50)
        val_loss, val_acc = validate(model, val_loader, focal_loss, device)
        scheduler.step()
        
        lr = optimizer.param_groups[0]["lr"]
        print(f"Epoch {epoch+1:02d}/50 | Train Loss: {train_loss:.3f} Acc: {train_acc:.1f}% | "
              f"Val Loss: {val_loss:.3f} Acc: {val_acc:.1f}% | LR: {lr:.2e}")
        
        # Log to CSV
        with open(log_file, "a", newline="") as f:
            writer = csv.writer(f)
            writer.writerow([epoch+1, f"{train_loss:.4f}", f"{train_acc:.2f}", 
                           f"{val_loss:.4f}", f"{val_acc:.2f}", f"{lr:.2e}"])
        
        # Save best model
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            best_epoch = epoch + 1
            torch.save({
                "epoch": epoch,
                "model_state_dict": model.state_dict(),
                "val_acc": val_acc,
                "config": config,
            }, "checkpoints/best_model.pth")
        
        # Save last model
        torch.save({
            "epoch": epoch,
            "model_state_dict": model.state_dict(),
            "val_acc": val_acc,
        }, "checkpoints/last_model.pth")
    
    print("\n" + "="*60)
    print("Training complete!")
    print(f"Best val accuracy: {best_val_acc:.2f}% at epoch {best_epoch}")
    print(f"Model saved to checkpoints/best_model.pth")
    print("="*60)


if __name__ == "__main__":
    main()