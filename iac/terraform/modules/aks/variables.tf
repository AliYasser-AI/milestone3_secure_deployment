variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "aks_subnet_id" { type = string }
variable "node_count" { type = number }
variable "node_vm_size" { type = string }
variable "allowed_admin_ips" { type = list(string) }
variable "log_analytics_workspace_id" { type = string }
variable "kubernetes_version" {
  type    = string
  default = "1.29"
}
variable "tags" { type = map(string) }
