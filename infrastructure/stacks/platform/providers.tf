provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  storage_use_azuread = true
}

provider "azapi" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "databricks" {
  host      = var.databricks_workspace_host
  auth_type = "azure-cli"
}
