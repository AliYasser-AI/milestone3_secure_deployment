variable "project_name" {
  description = "Short project name used as a resource naming prefix"
  type        = string
  default     = "fraudml"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "uaenorth"
}

variable "vnet_address_space" {
  description = "CIDR range for the project VNet"
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "aks_subnet_prefix" {
  type    = list(string)
  default = ["10.20.1.0/24"]
}

variable "appgw_subnet_prefix" {
  type    = list(string)
  default = ["10.20.2.0/24"]
}

variable "private_endpoints_subnet_prefix" {
  type    = list(string)
  default = ["10.20.3.0/24"]
}

variable "aks_node_count" {
  type    = number
  default = 2
}

variable "aks_node_vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "allowed_admin_ips" {
  description = "IP allow-list for AKS API server and Key Vault management-plane access"
  type        = list(string)
  default     = []
}

variable "tags" {
  type = map(string)
  default = {
    project = "secure-compliant-ml-pipeline"
    owner   = "ali-yasser"
    role    = "security-devsecops"
  }
}

variable "jwt_secret_key" {
  type      = string
  sensitive = true
}

variable "field_encryption_key" {
  type      = string
  sensitive = true
}

variable "security_contact_email" {
  type = string
}
