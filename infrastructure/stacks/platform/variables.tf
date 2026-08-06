variable "subscription_id" {
  description = "Azure subscription ID that owns the platform resources."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "Subscription ID must be a valid GUID."
  }
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID associated with the subscription."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "Tenant ID must be a valid GUID."
  }
}

variable "location" {
  description = "Azure region for the serverless Databricks workspace."
  type        = string
  default     = "centralindia"
}

variable "resource_group_name" {
  description = "Name of the platform resource group."
  type        = string
  default     = "rg-azref-platform-centralindia-001"
}

variable "databricks_workspace_name" {
  description = "Name of the serverless Azure Databricks workspace."
  type        = string
  default     = "dbw-azref-sandbox-centralindia-001"
}

variable "budget_name" {
  description = "Name of the subscription-level monthly cost budget."
  type        = string
  default     = "budget-azref-sandbox-monthly"
}

variable "monthly_budget_amount" {
  description = "Monthly Azure budget in the subscription billing currency."
  type        = number
  default     = 10

  validation {
    condition     = var.monthly_budget_amount > 0
    error_message = "Monthly budget amount must be greater than zero."
  }
}

variable "budget_start_date" {
  description = "Budget start date; Azure requires the first day of a month in RFC3339 format."
  type        = string
  default     = "2026-08-01T00:00:00Z"
}

variable "budget_end_date" {
  description = "Budget expiry date in RFC3339 format."
  type        = string
  default     = "2036-08-01T00:00:00Z"
}

variable "budget_contact_emails" {
  description = "Email addresses that receive actual-spend alerts at 50, 80, and 100 percent."
  type        = set(string)

  validation {
    condition     = length(var.budget_contact_emails) > 0
    error_message = "At least one budget contact email is required."
  }
}

variable "required_tags" {
  description = "Required ownership and governance tags for platform resources."
  type = object({
    application         = string
    environment         = string
    owner               = string
    cost_center         = string
    data_classification = string
  })

  default = {
    application         = "azref"
    environment         = "sandbox"
    owner               = "platform-owner"
    cost_center         = "learning"
    data_classification = "internal"
  }
}
