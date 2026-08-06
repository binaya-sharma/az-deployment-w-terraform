locals {
  tags = merge(var.additional_tags, {
    application         = var.required_tags.application
    environment         = var.required_tags.environment
    owner               = var.required_tags.owner
    cost_center         = var.required_tags.cost_center
    data_classification = var.required_tags.data_classification
    managed_by          = "terraform"
  })
}

resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location
  tags     = local.tags
}
