terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53"
    }
  }

  # Remote state — never store state locally for a shared production project.
  backend "azurerm" {
    # Fill these in via `terraform init -backend-config=backend.hcl`
    # resource_group_name  = "rg-tfstate"
    # storage_account_name = "sttfstatefraud"
    # container_name       = "tfstate"
    # key                  = "milestone3-secure-deployment.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {}
