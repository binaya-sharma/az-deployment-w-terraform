module "resource_group" {
  source = "../../modules/resource-group"

  name          = var.resource_group_name
  location      = var.location
  required_tags = var.required_tags
  additional_tags = {
    purpose = "azure-databricks-serverless"
  }
}

resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = var.budget_name
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = var.monthly_budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget_start_date
    end_date   = var.budget_end_date
  }

  dynamic "notification" {
    for_each = toset([50, 80, 100])

    content {
      enabled        = true
      threshold      = notification.value
      operator       = "GreaterThanOrEqualTo"
      threshold_type = "Actual"
      contact_emails = var.budget_contact_emails
    }
  }
}

# AzureRM does not yet expose computeMode. AzAPI makes the workspace type
# explicit so this cannot silently become a Hybrid workspace with classic
# Azure-hosted compute and managed networking resources.
resource "azapi_resource" "databricks_workspace" {
  type      = "Microsoft.Databricks/workspaces@2026-01-01"
  name      = var.databricks_workspace_name
  parent_id = module.resource_group.id
  location  = module.resource_group.location

  body = {
    properties = {
      computeMode = "Serverless"
    }
    sku = {
      name = "premium"
    }
  }

  tags = module.resource_group.tags
}
