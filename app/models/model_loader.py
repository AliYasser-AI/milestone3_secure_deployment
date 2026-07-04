"""
Loads the trained fraud-detection model produced in Milestone 2.

If no trained artifact is present yet (e.g. during infra bring-up before
Nour El-Din's model file is handed off), a deterministic placeholder scorer
is used so the rest of the security pipeline (auth, rate limiting, logging,
Key Vault wiring) can be built, tested, and pen-tested independently of the
ML deliverable. Swap in the real .joblib/.pkl file and this module will pick
it up automatically — no other code changes required.
"""
import logging
import os
from typing import Any

import joblib
import numpy as np

from app.core.config import get_settings

logger = logging.getLogger("fraud_api.model")


class _PlaceholderModel:
    """Rule-of-thumb stand-in used only until the real model is deployed."""

    version = "placeholder-0.1"

    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        # Very naive heuristic: larger, unusual-looking amounts score higher.
        amt = X[:, 0]
        score = np.clip(amt / 5000.0, 0, 1)
        return np.column_stack([1 - score, score])


class ModelService:
    def __init__(self):
        settings = get_settings()
        self.model: Any
        self.version: str

        if os.path.exists(settings.MODEL_PATH):
            self.model = joblib.load(settings.MODEL_PATH)
            self.version = getattr(self.model, "version", "1.0")
            logger.info("Loaded trained model from %s", settings.MODEL_PATH)
        else:
            logger.warning(
                "No trained model artifact found at %s — using placeholder scorer. "
                "Replace before production go-live.",
                settings.MODEL_PATH,
            )
            self.model = _PlaceholderModel()
            self.version = self.model.version

    def predict(self, feature_vector: np.ndarray) -> tuple[bool, float]:
        proba = self.model.predict_proba(feature_vector)[0][1]
        return bool(proba >= 0.5), float(proba)


_model_service: ModelService | None = None


def get_model_service() -> ModelService:
    global _model_service
    if _model_service is None:
        _model_service = ModelService()
    return _model_service
