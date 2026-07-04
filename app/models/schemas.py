"""
Request/response schemas for the inference endpoint.

Strict typing + bounds act as the first line of defence (input validation)
against malformed input, injection attempts, and resource-exhaustion payloads —
mapping to the OWASP API Security Top 10 (API3: Broken Object Property Level
Authorization / API8: Security Misconfiguration mitigations start here).
"""
from typing import Optional

from pydantic import BaseModel, Field, ConfigDict


class TransactionFeatures(BaseModel):
    model_config = ConfigDict(extra="forbid")  # reject unexpected/extra fields

    TransactionAmt: float = Field(..., ge=0, le=1_000_000, description="Transaction amount")
    ProductCD: str = Field(..., max_length=10)
    card_type_encoded: int = Field(..., ge=0, le=100)
    addr1_encoded: Optional[int] = Field(default=0, ge=0, le=1000)
    P_emaildomain_encoded: Optional[int] = Field(default=0, ge=0, le=1000)
    DeviceType_encoded: Optional[int] = Field(default=0, ge=0, le=10)
    dist1: Optional[float] = Field(default=0.0, ge=0)
    C1: Optional[float] = 0.0
    C2: Optional[float] = 0.0
    D1: Optional[float] = 0.0
    V1: Optional[float] = 0.0

    # NOTE: field list is a representative subset of the engineered feature
    # set produced in Milestone 2 (Nour El-Din). Extend to match the final
    # trained model's feature schema exactly before go-live — the model
    # will refuse to score a feature vector whose shape doesn't match.


class PredictionResponse(BaseModel):
    is_fraud: bool
    fraud_probability: float
    model_version: str
    request_id: str
