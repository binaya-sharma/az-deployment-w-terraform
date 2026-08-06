data "databricks_service_principal" "deployer" {
  application_id = var.deployment_service_principal_application_id
}

data "databricks_service_principal" "runtime" {
  application_id = var.runtime_service_principal_application_id
}

data "databricks_catalog" "workspace_default" {
  name = var.databricks_catalog_name
}

resource "databricks_schema" "pipeline" {
  for_each = toset(["bronze", "silver", "gold"])

  catalog_name = data.databricks_catalog.workspace_default.name
  name         = each.value
  comment      = "Terraform-managed ${each.value} schema for the retail deployment smoke test."
}

resource "databricks_grant" "catalog_runtime" {
  catalog = data.databricks_catalog.workspace_default.name

  principal  = data.databricks_service_principal.runtime.application_id
  privileges = ["USE_CATALOG"]
}

resource "databricks_grant" "schema_runtime" {
  for_each = databricks_schema.pipeline

  schema = each.value.id

  principal = data.databricks_service_principal.runtime.application_id
  privileges = [
    "CREATE_TABLE",
    "MODIFY",
    "SELECT",
    "USE_SCHEMA",
  ]
}

resource "databricks_directory" "bundle_root" {
  path             = "/Applications/retail-analytics-smoke-test/dev"
  delete_recursive = false
}

resource "databricks_permissions" "bundle_root" {
  directory_path = databricks_directory.bundle_root.path

  access_control {
    service_principal_name = data.databricks_service_principal.deployer.application_id
    permission_level       = "CAN_MANAGE"
  }

  access_control {
    service_principal_name = data.databricks_service_principal.runtime.application_id
    permission_level       = "CAN_READ"
  }
}
