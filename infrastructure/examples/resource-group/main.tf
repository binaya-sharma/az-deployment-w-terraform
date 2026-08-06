terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "resource_group" {
  source = "../../modules/resource-group"

  name     = "rg-azref-dev-uksouth-001"
  location = "uksouth"
  required_tags = {
    application         = "azref"
    environment         = "dev"
    owner               = "platform-team"
    cost_center         = "learning"
    data_classification = "internal"
  }
  additional_tags = {
    purpose = "terraform-module-example"
  }
}

output "resource_group" {
  description = "Resource group produced by the example module call."
  value = {
    id       = module.resource_group.id
    name     = module.resource_group.name
    location = module.resource_group.location
    tags     = module.resource_group.tags
  }
}
