#!/usr/bin/env python3
"""Training loop utilities for LADA-Net."""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional

import torch
import torch.nn as nn
from sklearn.metrics import f1_score

from preprocessing.scripts.augment import cutmix_batch


@dataclass
class TrainingConfig:
    """Runtime training settings loaded from config."""

    epochs: int = 25
    learning_rate: float = 1e-4
    weight_decay: float = 1e-4
    optimizer: str = "adamw"
    freeze_backbone_epochs: int = 0
    use_amp: bool = True
    cutmix_alpha: float = 1.0
    checkpoint_dir: str = "checkpoints"
    max_grad_norm: Optional[float] = 1.0


class Trainer:
    """Encapsulates the train/validate/checkpoint flow for LADANet."""

    def __init__(
        self,
        model: nn.Module,
        dataloaders: Dict[str, Any],
        config: Dict[str, Any],
        device: torch.device,
    ) -> None:
        self.model = model
        self.dataloaders = dataloaders
        self.device = device
        self.config = config

        training_cfg = config.get("training", {})
        self.training_config = TrainingConfig(
            epochs=int(training_cfg.get("epochs", 25)),
            learning_rate=float(training_cfg.get("learning_rate", 1e-4)),
            weight_decay=float(training_cfg.get("weight_decay", 1e-4)),
            optimizer=str(training_cfg.get("optimizer", "adamw")),
            freeze_backbone_epochs=int(training_cfg.get("freeze_backbone_epochs", 0)),
            use_amp=bool(training_cfg.get("use_amp", True)),
            cutmix_alpha=float(training_cfg.get("cutmix_alpha", 1.0)),
            checkpoint_dir=str(training_cfg.get("checkpoint_dir", "checkpoints")),
            max_grad_norm=training_cfg.get("max_grad_norm", 1.0),
        )

        self.criterion = nn.CrossEntropyLoss()
        self.optimizer = self._build_optimizer()
        self.scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
            self.optimizer,
            T_max=max(1, self.training_config.epochs),
        )
        self.scaler = torch.amp.GradScaler(enabled=self.training_config.use_amp and device.type == "cuda")

        self.checkpoint_dir = Path(self.training_config.checkpoint_dir)
        self.checkpoint_dir.mkdir(parents=True, exist_ok=True)
        self.history_path = self.checkpoint_dir / "history.json"
        self.best_checkpoint_path = self.checkpoint_dir / "best_model.pt"
        self.last_checkpoint_path = self.checkpoint_dir / "last_model.pt"

        # Logger setup
        self.logger = logging.getLogger("lada.trainer")
        self.logger.setLevel(logging.INFO)
        if not self.logger.handlers:
            stream_handler = logging.StreamHandler()
            stream_handler.setLevel(logging.INFO)
            formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
            stream_handler.setFormatter(formatter)
            self.logger.addHandler(stream_handler)

            file_handler = logging.FileHandler(self.checkpoint_dir / "train.log")
            file_handler.setLevel(logging.INFO)
            file_handler.setFormatter(formatter)
            self.logger.addHandler(file_handler)

        self.best_val_loss = float("inf")
        self.history: list[dict[str, float | int]] = []

    def _build_optimizer(self) -> torch.optim.Optimizer:
        params = [p for p in self.model.parameters() if p.requires_grad]
        optimizer_name = self.training_config.optimizer.lower()
        if optimizer_name == "adam":
            return torch.optim.Adam(
                params,
                lr=self.training_config.learning_rate,
                weight_decay=self.training_config.weight_decay,
            )
        if optimizer_name == "sgd":
            return torch.optim.SGD(
                params,
                lr=self.training_config.learning_rate,
                momentum=0.9,
                weight_decay=self.training_config.weight_decay,
            )
        return torch.optim.AdamW(
            params,
            lr=self.training_config.learning_rate,
            weight_decay=self.training_config.weight_decay,
        )

    def _forward_loss(self, images: torch.Tensor, labels: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        use_cutmix = bool(self.config.get("augmentation", {}).get("use_cutmix", False))
        if use_cutmix and self.training_config.cutmix_alpha > 0 and images.size(0) > 1:
            mixed_images, labels_a, labels_b, lam = cutmix_batch(
                images,
                labels,
                alpha=self.training_config.cutmix_alpha,
            )
            logits = self.model(mixed_images)
            loss = lam * self.criterion(logits, labels_a) + (1.0 - lam) * self.criterion(logits, labels_b)
            return logits, loss

        logits = self.model(images)
        loss = self.criterion(logits, labels)
        return logits, loss

    def train_one_epoch(self, epoch: int, max_batches: Optional[int] = None) -> dict[str, float]:
        """Train the model for one epoch and return aggregate metrics."""
        if epoch < self.training_config.freeze_backbone_epochs:
            self.model.freeze_backbone()
        else:
            self.model.unfreeze_backbone()

        self.model.train()

        total_loss = 0.0
        total_correct = 0
        total_samples = 0

        for batch_idx, (images, labels) in enumerate(self.dataloaders["train"]):
            if max_batches is not None and batch_idx >= max_batches:
                break

            images = images.to(self.device, non_blocking=True)
            labels = labels.to(self.device, non_blocking=True)

            self.optimizer.zero_grad(set_to_none=True)

            with torch.autocast(
                device_type=self.device.type,
                enabled=self.training_config.use_amp and self.device.type == "cuda",
            ):
                logits, loss = self._forward_loss(images, labels)

            if self.scaler.is_enabled():
                self.scaler.scale(loss).backward()
                if self.training_config.max_grad_norm:
                    self.scaler.unscale_(self.optimizer)
                    torch.nn.utils.clip_grad_norm_(self.model.parameters(), self.training_config.max_grad_norm)
                self.scaler.step(self.optimizer)
                self.scaler.update()
            else:
                loss.backward()
                if self.training_config.max_grad_norm:
                    torch.nn.utils.clip_grad_norm_(self.model.parameters(), self.training_config.max_grad_norm)
                self.optimizer.step()

            batch_size = labels.size(0)
            total_loss += loss.item() * batch_size
            total_samples += batch_size
            total_correct += (logits.argmax(dim=1) == labels).sum().item()

        return {
            "loss": total_loss / max(1, total_samples),
            "accuracy": total_correct / max(1, total_samples),
        }

    @torch.no_grad()
    def evaluate(self, split: str = "val", max_batches: Optional[int] = None) -> dict[str, float]:
        """Evaluate the model on validation or test data."""
        self.model.eval()

        total_loss = 0.0
        total_correct = 0
        total_samples = 0
        all_targets: list[int] = []
        all_predictions: list[int] = []

        for batch_idx, (images, labels) in enumerate(self.dataloaders[split]):
            if max_batches is not None and batch_idx >= max_batches:
                break

            images = images.to(self.device, non_blocking=True)
            labels = labels.to(self.device, non_blocking=True)
            logits = self.model(images)
            loss = self.criterion(logits, labels)

            predictions = logits.argmax(dim=1)
            batch_size = labels.size(0)

            total_loss += loss.item() * batch_size
            total_samples += batch_size
            total_correct += (predictions == labels).sum().item()
            all_targets.extend(labels.detach().cpu().tolist())
            all_predictions.extend(predictions.detach().cpu().tolist())

        average_loss = total_loss / max(1, total_samples)
        accuracy = total_correct / max(1, total_samples)
        macro_f1 = f1_score(all_targets, all_predictions, average="macro", zero_division=0) if all_targets else 0.0

        return {
            "loss": average_loss,
            "accuracy": accuracy,
            "macro_f1": float(macro_f1),
        }

    def _save_checkpoint(self, epoch: int, val_metrics: dict[str, float], is_best: bool) -> None:
        state = {
            "epoch": epoch,
            "model_state_dict": self.model.state_dict(),
            "optimizer_state_dict": self.optimizer.state_dict(),
            "scheduler_state_dict": self.scheduler.state_dict(),
            "best_val_loss": self.best_val_loss,
            "val_metrics": val_metrics,
            "config": self.config,
        }
        torch.save(state, self.last_checkpoint_path)
        if is_best:
            torch.save(state, self.best_checkpoint_path)

    def load_checkpoint(self, path: Optional[str] = None, map_location: Optional[str] = None) -> int:
        """Load checkpoint state into trainer.

        Returns the next epoch index (1-based) to resume from.
        If `path` is None, tries to load `last_model.pt`.
        """
        checkpoint_path = Path(path) if path else self.last_checkpoint_path
        if not checkpoint_path.exists():
            self.logger.warning(f"Checkpoint not found: {checkpoint_path}")
            return 1

        if map_location is None:
            map_location = "cuda" if self.device.type == "cuda" else "cpu"

        self.logger.info(f"Loading checkpoint: {checkpoint_path}")
        state = torch.load(checkpoint_path, map_location=map_location)

        self.model.load_state_dict(state["model_state_dict"])
        try:
            self.optimizer.load_state_dict(state["optimizer_state_dict"])
            if "scheduler_state_dict" in state:
                self.scheduler.load_state_dict(state["scheduler_state_dict"])
        except Exception:
            self.logger.warning("Failed to restore optimizer/scheduler state; continuing with fresh state.")

        self.best_val_loss = float(state.get("best_val_loss", self.best_val_loss))

        # Restore history from disk if present
        try:
            if self.history_path.exists():
                self.history = json.loads(self.history_path.read_text(encoding="utf-8"))
        except Exception:
            self.logger.debug("Could not restore history.json")

        start_epoch = int(state.get("epoch", 0)) + 1
        self.logger.info(f"Resuming from epoch {start_epoch}")
        return start_epoch

    def fit(
        self,
        epochs: Optional[int] = None,
        max_batches: Optional[int] = None,
        resume_from: Optional[str] = None,
    ) -> dict[str, list[dict[str, float | int]]]:
        """Run the full training loop."""
        total_epochs = int(epochs or self.training_config.epochs)

        start_epoch = 1
        if resume_from:
            start_epoch = self.load_checkpoint(path=resume_from, map_location=("cpu" if self.device.type == "cpu" else None))

        for epoch in range(start_epoch, total_epochs + 1):
            train_metrics = self.train_one_epoch(epoch=epoch, max_batches=max_batches)
            val_metrics = self.evaluate(split="val", max_batches=max_batches)

            self.scheduler.step()

            is_best = val_metrics["loss"] < self.best_val_loss
            if is_best:
                self.best_val_loss = val_metrics["loss"]

            self._save_checkpoint(epoch, val_metrics, is_best)

            record = {
                "epoch": epoch,
                "train_loss": train_metrics["loss"],
                "train_accuracy": train_metrics["accuracy"],
                "val_loss": val_metrics["loss"],
                "val_accuracy": val_metrics["accuracy"],
                "val_macro_f1": val_metrics["macro_f1"],
            }
            self.history.append(record)
            self.history_path.write_text(json.dumps(self.history, indent=2), encoding="utf-8")

            self.logger.info(
                f"Epoch {epoch:03d}/{total_epochs:03d} | "
                f"train_loss={record['train_loss']:.4f} train_acc={record['train_accuracy']:.4f} | "
                f"val_loss={record['val_loss']:.4f} val_acc={record['val_accuracy']:.4f} val_f1={record['val_macro_f1']:.4f}"
            )

        return {"history": self.history}


def train_model(
    model: nn.Module,
    dataloaders: Dict[str, Any],
    config: Dict[str, Any],
    device: torch.device,
    epochs: Optional[int] = None,
    max_batches: Optional[int] = None,
) -> dict[str, list[dict[str, float | int]]]:
    """Convenience wrapper for the full training flow."""
    trainer = Trainer(model=model, dataloaders=dataloaders, config=config, device=device)
    return trainer.fit(epochs=epochs, max_batches=max_batches)