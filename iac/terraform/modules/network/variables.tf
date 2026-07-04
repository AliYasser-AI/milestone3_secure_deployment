variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "vnet_address_space" { type = list(string) }
variable "aks_subnet_prefix" { type = list(string) }
variable "appgw_subnet_prefix" { type = list(string) }
variable "private_endpoints_subnet_prefix" { type = list(string) }
variable "tags" { type = map(string) }
