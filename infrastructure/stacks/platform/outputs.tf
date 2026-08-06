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

output "databricks_catalog_name" {
  description = "Existing default-storage catalog containing Terraform-managed development schemas."
  value       = data.databricks_catalog.workspace_default.name
}

output "databricks_schema_names" {
  description = "Terraform-managed pipeline schemas."
  value       = sort([for schema in databricks_schema.pipeline : schema.id])
}

output "runtime_service_principal_application_id" {
  description = "Runtime identity receiving catalog and schema data privileges."
  value       = data.databricks_service_principal.runtime.application_id
}
