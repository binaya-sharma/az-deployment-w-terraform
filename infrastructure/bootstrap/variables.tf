variable "subscription_id" {
  description = "Azure subscription ID that owns the bootstrap resources."
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
  description = "Azure region for the bootstrap resource group and storage account."
  type        = string
  default     = "centralindia"
}

variable "resource_group_name" {
  description = "Name of the Terraform bootstrap resource group."
  type        = string
  default     = "rg-azref-bootstrap-centralindia-001"
}

variable "storage_account_name" {
  description = "Globally unique name of the Terraform state storage account."
  type        = string
  default     = "stazreftfstate5f78"

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must contain 3 to 24 lowercase letters or numbers."
  }
}

variable "state_container_name" {
  description = "Name of the private blob container that stores Terraform state."
  type        = string
  default     = "tfstate"
}

variable "required_tags" {
  description = "Required ownership and governance tags for bootstrap resources."
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
