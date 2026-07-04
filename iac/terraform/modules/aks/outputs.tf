output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "workload_identity_id" {
  value = azurerm_user_assigned_identity.aks_workload.id
}

output "workload_identity_client_id" {
  value = azurerm_user_assigned_identity.aks_workload.client_id
}

output "workload_identity_principal_id" {
  value = azurerm_user_assigned_identity.aks_workload.principal_id
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}
