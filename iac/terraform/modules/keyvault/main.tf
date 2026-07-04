data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                = "kv-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location             = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Enterprise-grade Key Vault hardening
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  enable_rbac_authorization     = true   # Azure RBAC instead of legacy access policies
  public_network_access_enabled = false  # reachable ONLY via the private endpoint below

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# --- Private endpoint: no public network path to secrets -----------------
resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoints_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv-${var.project_name}"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.keyvault_private_dns_zone_id]
  }
}

# --- RBAC: grant the AKS workload identity least-privilege secret access -
resource "azurerm_role_assignment" "aks_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"   # read-only, no write/delete
  principal_id         = var.aks_workload_identity_principal_id
}

# Application Gateway needs to read the TLS certificate object (not just a
# secret) at rotation time.
resource "azurerm_role_assignment" "appgw_cert_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = var.aks_workload_identity_principal_id
}

# --- Secrets ------------------------------------------------------------
# NOTE: values are injected at apply-time via -var / a secure pipeline
# variable — never hardcoded in this file or committed to source control.
resource "azurerm_key_vault_secret" "jwt_secret_key" {
  name         = "jwt-secret-key"
  value        = var.jwt_secret_key
  key_vault_id = azurerm_key_vault.this.id
  content_type = "text/plain"

  depends_on = [azurerm_role_assignment.aks_secrets_user]
}

resource "azurerm_key_vault_secret" "allowed_origins" {
  name         = "allowed-origins"
  value        = var.allowed_origins
  key_vault_id = azurerm_key_vault.this.id
  content_type = "text/csv"

  depends_on = [azurerm_role_assignment.aks_secrets_user]
}

resource "azurerm_key_vault_secret" "field_encryption_key" {
  name         = "field-encryption-key"     # the Fernet key from Milestone 1
  value        = var.field_encryption_key
  key_vault_id = azurerm_key_vault.this.id
  content_type = "text/plain"

  depends_on = [azurerm_role_assignment.aks_secrets_user]
}

# --- Diagnostic logging: every access to a secret is auditable -----------
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "diag-kv-${var.project_name}"
  target_resource_id        = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
  }
}
