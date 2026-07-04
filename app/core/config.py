"""
Application configuration.

Secrets NEVER live in code or in plain environment files in production.
In production (ENVIRONMENT=production) all secrets are pulled from Azure Key
Vault using a Managed Identity (DefaultAzureCredential -> no client
secret/password stored anywhere). For local development only, values can
fall back to a local .env file (never commit this file).
"""
import os
from functools import lru_cache
from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict

from app.core.keyvault import KeyVaultClient


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # ---- General ----
    ENVIRONMENT: str = "development"          # development | staging | production
    APP_NAME: str = "fraud-inference-api"
    API_V1_PREFIX: str = "/api/v1"

    # ---- Azure Key Vault ----
    AZURE_KEY_VAULT_URL: str = ""             # e.g. https://kv-fraud-prod.vault.azure.net/

    # ---- Auth / JWT ----
    JWT_SECRET_KEY: str = ""                  # pulled from Key Vault in prod
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15

    # ---- CORS ----
    ALLOWED_ORIGINS: List[str] = []           # explicit allow-list, never "*"

    # ---- Rate limiting ----
    RATE_LIMIT: str = "30/minute"

    # ---- Model ----
    MODEL_PATH: str = "app/models/artifacts/fraud_model.joblib"


@lru_cache
def get_settings() -> Settings:
    settings = Settings()

    # In production, secrets are resolved from Key Vault via Managed Identity,
    # overriding anything picked up from the environment. This ensures no
    # production secret can be smuggled in via a local .env or app setting.
    if settings.ENVIRONMENT == "production" and settings.AZURE_KEY_VAULT_URL:
        kv = KeyVaultClient(vault_url=settings.AZURE_KEY_VAULT_URL)
        settings.JWT_SECRET_KEY = kv.get_secret("jwt-secret-key")
        origins = kv.get_secret("allowed-origins")  # comma-separated
        settings.ALLOWED_ORIGINS = [o.strip() for o in origins.split(",") if o.strip()]

    if not settings.JWT_SECRET_KEY:
        if settings.ENVIRONMENT == "production":
            raise RuntimeError(
                "JWT_SECRET_KEY could not be resolved from Azure Key Vault. "
                "Refusing to start with an empty secret."
            )
        # Local/dev only fallback - never used in production.
        settings.JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", "dev-only-insecure-key")

    return settings
