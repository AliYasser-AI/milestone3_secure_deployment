"""
Thin wrapper around Azure Key Vault Secrets client.

Uses DefaultAzureCredential so that in Azure (AKS with Workload Identity, or
App Service/Container Apps with a System-Assigned Managed Identity) NO
credentials are stored anywhere - the identity of the compute resource itself
is used to authenticate to Key Vault. Locally, DefaultAzureCredential falls
back to `az login` credentials for developer testing only.
"""
from functools import lru_cache

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient


class KeyVaultClient:
    def __init__(self, vault_url: str):
        self._client = SecretClient(
            vault_url=vault_url,
            credential=DefaultAzureCredential(),
        )

    @lru_cache(maxsize=32)
    def get_secret(self, name: str) -> str:
        return self._client.get_secret(name).value
