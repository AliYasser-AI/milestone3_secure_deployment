variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "appgw_subnet_id" { type = string }
variable "appgw_identity_id" {
  type        = string
  description = "User-assigned identity Application Gateway uses to read the TLS cert from Key Vault"
}
variable "tls_certificate_keyvault_secret_id" { type = string }
variable "enable_geo_block" {
  type    = bool
  default = false
}
variable "blocked_country_codes" {
  type    = list(string)
  default = []
}
variable "tags" { type = map(string) }
