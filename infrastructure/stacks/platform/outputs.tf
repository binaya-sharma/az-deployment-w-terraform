output "resource_group_id" {
  description = "Azure resource ID of the platform resource group."
  value       = module.resource_group.id
}

output "databricks_workspace_id" {
  description = "Azure resource ID of the serverless Databricks workspace."
  value       = azapi_resource.databricks_workspace.id
}

output "databricks_workspace_name" {
  description = "Name of the serverless Databricks workspace."
  value       = azapi_resource.databricks_workspace.name
}

output "monthly_budget_amount" {
  description = "Configured monthly Azure budget amount."
  value       = azurerm_consumption_budget_subscription.monthly.amount
}
