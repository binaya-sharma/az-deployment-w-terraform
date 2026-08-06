module "resource_group" {
  source = "../modules/resource-group"

  name          = var.resource_group_name
  location      = var.location
  required_tags = var.required_tags
  additional_tags = {
    purpose = "terraform-remote-state"
  }
}

resource "azurerm_storage_account" "terraform_state" {
  name                = var.storage_account_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  local_user_enabled              = false
  public_network_access_enabled   = true
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = module.resource_group.tags
}

resource "azurerm_storage_container" "terraform_state" {
  name                  = var.state_container_name
  storage_account_id    = azurerm_storage_account.terraform_state.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "current_user_state_access" {
  scope                = azurerm_storage_container.terraform_state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}

resource "azurerm_management_lock" "terraform_state" {
  name       = "lock-terraform-state"
  scope      = azurerm_storage_account.terraform_state.id
  lock_level = "CanNotDelete"
  notes      = "Protects the Terraform state storage account from accidental deletion."
}
