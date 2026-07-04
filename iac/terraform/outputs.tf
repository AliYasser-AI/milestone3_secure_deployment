output "resource_group_name" {
  value = module.network.resource_group_name
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "key_vault_uri" {
  value = module.keyvault.key_vault_uri
}

output "waf_public_ip" {
  value = module.waf.public_ip_address
}

output "log_analytics_workspace_id" {
  value = module.monitoring.log_analytics_workspace_id
}
