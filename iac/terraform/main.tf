data "azurerm_client_config" "current" {}

module "network" {
  source = "./modules/network"

  project_name                    = var.project_name
  environment                     = var.environment
  location                        = var.location
  vnet_address_space              = var.vnet_address_space
  aks_subnet_prefix               = var.aks_subnet_prefix
  appgw_subnet_prefix             = var.appgw_subnet_prefix
  private_endpoints_subnet_prefix = var.private_endpoints_subnet_prefix
  tags                            = var.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name            = var.project_name
  environment              = var.environment
  location                 = module.network.location
  resource_group_name     = module.network.resource_group_name
  subscription_id          = data.azurerm_client_config.current.subscription_id
  security_contact_email   = var.security_contact_email
  tags                     = var.tags
}

module "aks" {
  source = "./modules/aks"

  project_name                = var.project_name
  environment                 = var.environment
  location                    = module.network.location
  resource_group_name        = module.network.resource_group_name
  aks_subnet_id               = module.network.aks_subnet_id
  node_count                  = var.aks_node_count
  node_vm_size                = var.aks_node_vm_size
  allowed_admin_ips           = var.allowed_admin_ips
  log_analytics_workspace_id  = module.monitoring.log_analytics_workspace_id
  tags                        = var.tags
}

module "keyvault" {
  source = "./modules/keyvault"

  project_name                         = var.project_name
  environment                          = var.environment
  location                             = module.network.location
  resource_group_name                 = module.network.resource_group_name
  private_endpoints_subnet_id          = module.network.private_endpoints_subnet_id
  keyvault_private_dns_zone_id        = module.network.keyvault_private_dns_zone_id
  aks_workload_identity_principal_id  = module.aks.workload_identity_principal_id
  log_analytics_workspace_id          = module.monitoring.log_analytics_workspace_id

  jwt_secret_key        = var.jwt_secret_key
  field_encryption_key  = var.field_encryption_key
  tags                   = var.tags
}

module "waf" {
  source = "./modules/waf"

  project_name                        = var.project_name
  environment                         = var.environment
  location                            = module.network.location
  resource_group_name                = module.network.resource_group_name
  appgw_subnet_id                     = module.network.appgw_subnet_id
  # NOTE: reusing the AKS workload identity here for simplicity. In a
  # stricter Zero Trust setup, provision a dedicated user-assigned identity
  # for Application Gateway with ONLY "Key Vault Certificates User" scope.
  appgw_identity_id                   = module.aks.workload_identity_id
  tls_certificate_keyvault_secret_id  = "${module.keyvault.key_vault_uri}secrets/appgw-tls-cert"
  enable_geo_block                    = false
  tags                                 = var.tags
}
