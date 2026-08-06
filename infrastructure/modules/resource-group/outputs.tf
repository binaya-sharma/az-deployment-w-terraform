output "id" {
  description = "Azure resource ID of the resource group."
  value       = azurerm_resource_group.this.id
}

output "name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Azure region containing the resource group's metadata."
  value       = azurerm_resource_group.this.location
}

output "tags" {
  description = "Final tags applied to the resource group, including managed_by=terraform."
  value       = azurerm_resource_group.this.tags
}
