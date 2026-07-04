variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "private_endpoints_subnet_id" { type = string }
variable "keyvault_private_dns_zone_id" { type = string }
variable "aks_workload_identity_principal_id" {
  type        = string
  description = "Object ID of the AKS workload identity (Microsoft Entra Workload ID) used by the FastAPI pods"
}
variable "log_analytics_workspace_id" { type = string }

variable "jwt_secret_key" {
  type      = string
  sensitive = true
}
variable "allowed_origins" {
  type    = string
  default = "https://app.example.com"
}
variable "field_encryption_key" {
  type      = string
  sensitive = true
}
variable "tags" { type = map(string) }
