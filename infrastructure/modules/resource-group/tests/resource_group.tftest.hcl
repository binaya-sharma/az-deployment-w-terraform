mock_provider "azurerm" {
  override_during = plan

  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-azref-dev-uksouth-001"
    }
  }
}

run "creates_resource_group_with_standard_tags" {
  command = plan

  variables {
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
      purpose = "module-test"
    }
  }

  assert {
    condition     = azurerm_resource_group.this.name == "rg-azref-dev-uksouth-001"
    error_message = "The module did not pass the requested resource group name to AzureRM."
  }

  assert {
    condition     = azurerm_resource_group.this.location == "uksouth"
    error_message = "The module did not pass the requested location to AzureRM."
  }

  assert {
    condition = azurerm_resource_group.this.tags == tomap({
      application         = "azref"
      environment         = "dev"
      owner               = "platform-team"
      cost_center         = "learning"
      data_classification = "internal"
      managed_by          = "terraform"
      purpose             = "module-test"
    })
    error_message = "The module did not produce the expected standard and additional tags."
  }

  assert {
    condition     = output.id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-azref-dev-uksouth-001"
    error_message = "The module did not expose the mocked resource group ID."
  }
}

run "rejects_name_ending_with_period" {
  command = plan

  variables {
    name     = "rg-azref-dev."
    location = "uksouth"
    required_tags = {
      application         = "azref"
      environment         = "dev"
      owner               = "platform-team"
      cost_center         = "learning"
      data_classification = "internal"
    }
  }

  expect_failures = [
    var.name,
  ]
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    name     = "rg-azref-test-uksouth-001"
    location = "uksouth"
    required_tags = {
      application         = "azref"
      environment         = "test"
      owner               = "platform-team"
      cost_center         = "learning"
      data_classification = "internal"
    }
  }

  expect_failures = [
    var.required_tags,
  ]
}

run "rejects_reserved_additional_tag" {
  command = plan

  variables {
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
      managed_by = "a-person"
    }
  }

  expect_failures = [
    var.additional_tags,
  ]
}
