import logging
import uuid

import numpy as np
from fastapi import APIRouter, Depends, Request

from app.core.config import get_settings
from app.core.limiter import limiter
from app.core.security import TokenData, require_role
from app.models.model_loader import get_model_service
from app.models.schemas import PredictionResponse, TransactionFeatures

router = APIRouter(prefix="/inference", tags=["inference"])

logger = logging.getLogger("fraud_api.inference")


def _to_feature_vector(features: TransactionFeatures) -> np.ndarray:
    # Deterministic, explicit ordering — never rely on dict ordering for a
    # security-sensitive feature vector fed into a model.
    return np.array(
        [[
            features.TransactionAmt,
            features.card_type_encoded,
            features.addr1_encoded,
            features.P_emaildomain_encoded,
            features.DeviceType_encoded,
            features.dist1,
            features.C1,
            features.C2,
            features.D1,
            features.V1,
        ]]
    )


@router.post("/predict", response_model=PredictionResponse)
@limiter.limit(get_settings().RATE_LIMIT)
def predict(
    request: Request,
    features: TransactionFeatures,
    current_user: TokenData = Depends(require_role("ml_engineer", "service_client")),
):
    request_id = str(uuid.uuid4())

    # Audit log: WHO called WHAT, never log raw feature values (may be
    # derived from PII) or the prediction payload itself.
    logger.info(
        "inference_request request_id=%s user=%s role=%s",
        request_id, current_user.subject, current_user.role,
    )

    model_service = get_model_service()
    vector = _to_feature_vector(features)
    is_fraud, probability = model_service.predict(vector)

    return PredictionResponse(
        is_fraud=is_fraud,
        fraud_probability=round(probability, 4),
        model_version=model_service.version,
        request_id=request_id,
    )
