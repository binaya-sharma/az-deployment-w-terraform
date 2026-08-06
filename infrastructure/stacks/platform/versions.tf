terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }

    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.122"
    }
  }

  backend "azurerm" {}
}
