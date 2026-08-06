output "resource_group_name" {
  description = "Name of the bootstrap resource group."
  value       = module.resource_group.name
}

output "storage_account_name" {
  description = "Name of the Terraform state storage account."
  value       = azurerm_storage_account.terraform_state.name
}

output "state_container_name" {
  description = "Name of the Terraform state blob container."
  value       = azurerm_storage_container.terraform_state.name
}

output "backend_configuration" {
  description = "Non-secret values used to initialize the azurerm backend."
  value = {
    resource_group_name  = module.resource_group.name
    storage_account_name = azurerm_storage_account.terraform_state.name
    container_name       = azurerm_storage_container.terraform_state.name
    key                  = "bootstrap/terraform.tfstate"
    tenant_id            = var.tenant_id
    subscription_id      = var.subscription_id
    use_azuread_auth     = true
  }
}
