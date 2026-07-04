resource "azurerm_user_assigned_identity" "aks_workload" {
  name                = "id-workload-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = "${var.project_name}-${var.environment}"
  kubernetes_version  = var.kubernetes_version
  tags                = var.tags

  # --- Zero Trust posture ---------------------------------------------
  private_cluster_enabled             = true   # no public API server endpoint
  private_cluster_public_fqdn_enabled = false
  role_based_access_control_enabled   = true

  # Managed identity for the cluster control plane itself
  identity {
    type = "SystemAssigned"
  }

  # Workload Identity (OIDC federation) — pods get Azure AD tokens without
  # any stored secret, used by the FastAPI app to call Key Vault.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                = "system"
    node_count          = var.node_count
    vm_size             = var.node_vm_size
    vnet_subnet_id      = var.aks_subnet_id
    only_critical_addons_enabled = true
    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"   # enforce Kubernetes NetworkPolicies (micro-segmentation)
    load_balancer_sku = "standard"
    outbound_type     = "userDefinedRouting"
  }

  api_server_access_profile {
    authorized_ip_ranges = var.allowed_admin_ips
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
  }

  microsoft_defender {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }
}

# Separate, non-system node pool for the inference workload — isolates
# the internet-facing app from cluster system components.
resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "inference"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.node_vm_size
  node_count            = var.node_count
  vnet_subnet_id        = var.aks_subnet_id
  mode                  = "User"
  tags                  = var.tags
}

# Federated credential binds the Kubernetes ServiceAccount used by the
# FastAPI deployment to this Azure AD identity — no client secret anywhere.
resource "azurerm_federated_identity_credential" "workload" {
  name                = "fed-${var.project_name}-inference-sa"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.aks_workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject             = "system:serviceaccount:fraud-inference:fraud-inference-sa"
}
