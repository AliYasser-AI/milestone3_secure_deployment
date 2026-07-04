resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.tags
}

# --- Microsoft Defender for Cloud: continuous vulnerability scanning -----
resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"      # scans AKS + container images in ACR
}

resource "azurerm_security_center_subscription_pricing" "key_vaults" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

resource "azurerm_security_center_subscription_pricing" "app_services" {
  tier          = "Standard"
  resource_type = "AppServices"
}

resource "azurerm_security_center_subscription_pricing" "arm" {
  tier          = "Standard"
  resource_type = "Arm"             # detects anomalous resource-manager activity
}

resource "azurerm_security_center_auto_provisioning" "this" {
  auto_provision = "On"
}

resource "azurerm_security_center_workspace" "this" {
  scope        = "/subscriptions/${var.subscription_id}"
  workspace_id = azurerm_log_analytics_workspace.this.id
}

resource "azurerm_security_center_contact" "this" {
  email               = var.security_contact_email
  phone               = var.security_contact_phone
  alert_notifications = true
  alerts_to_admins    = true
}
