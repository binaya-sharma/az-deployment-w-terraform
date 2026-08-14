# Terraform for data engineers

This guide defines the Terraform knowledge needed to work safely in this Azure Databricks project. A data engineer does not need to become a network or Azure platform specialist, but must be able to read a plan, understand ownership, change governed data objects, and avoid destructive operations.

## Recommended depth

Aim for working proficiency in roughly 20% of Terraform:

| Level | Topics | Expectation |
| --- | --- | --- |
| Must know | configuration syntax, providers, resources, data sources, variables, outputs, references, `for_each`, state, plan/apply lifecycle | Read, review, and safely change this project |
| Should know | modules, imports, dependency graph, provider aliases, lifecycle behavior, lock files, remote state, drift | Diagnose routine failures and review pull requests |
| Recognize | OIDC authentication, RBAC, policy, storage backends, CI plan/apply separation | Collaborate safely with platform engineers |
| Platform-specialist depth | VNet design, Private Link/DNS, firewalls, route tables, enterprise landing zones, cross-subscription identity design | Learn only when the role owns the platform |

## The mental model

Terraform reconciles declared configuration with real infrastructure:

```text
Terraform files + variables + provider credentials
                    |
                    v
             terraform plan
                    |
             proposed changes
                    |
          review and approve safely
                    |
                    v
             terraform apply
                    |
                    v
 Azure resources + Databricks governance objects
```

Terraform is declarative. You describe the desired result; providers translate it into Azure and Databricks API calls. Resource order is normally derived from references rather than file order.

## Syntax you must understand

### Resource

A resource asks Terraform to manage an object:

```hcl
resource "databricks_schema" "pipeline" {
  for_each = toset(["bronze", "silver", "gold"])

  catalog_name = data.databricks_catalog.workspace_default.name
  name         = each.value
}
```

- `databricks_schema` is the provider resource type.
- `pipeline` is this repository's local Terraform name.
- `for_each` creates one instance per schema name.
- A reference to another object also creates a dependency.

### Data source

A data source reads an existing object without creating it:

```hcl
data "databricks_catalog" "workspace_default" {
  name = var.databricks_catalog_name
}
```

This matters in this project: the workspace default catalog already exists; Terraform looks it up and manages schemas inside it.

### Variables and outputs

Variables are inputs and outputs expose useful results:

```hcl
variable "location" {
  type = string
}

output "databricks_workspace_name" {
  value = azapi_resource.databricks_workspace.name
}
```

A tenant ID, subscription ID, workspace URL, client ID, and catalog name are identifiers—not secrets. Tokens, client secrets, passwords, state files, and saved plans must not be committed.

## What Terraform owns here

This repository separates long-lived platform state from application deployment:

| Owner | Objects |
| --- | --- |
| Bootstrap Terraform | State resource group, storage account/container, RBAC, and protection |
| Platform Terraform | Resource group, budget, Azure Databricks workspace, schemas, grants, directories, and identity assignments |
| Databricks bundle | Python wheel, Databricks jobs, job permissions, `run_as`, and environment-specific job settings |
| GitHub Actions | Validation, deployment trigger, environment approvals, and OIDC authentication |

Do not define the same object in two systems. For example, schemas and Unity Catalog grants belong to Terraform; the smoke-test job belongs to the Databricks bundle.

## This project's deployment sequence

```text
Tenant and subscription (existing prerequisites)
        |
        v
Bootstrap stack -> remote Terraform state
        |
        v
Platform stack -> Azure resource group, budget, workspace
        |
        v
Workspace URL becomes known
        |
        v
Platform Databricks provider -> schemas, grants, directories
        |
        v
Databricks bundle -> wheel and job definition
        |
        v
Job runtime identity -> reads/writes only granted UC objects
```

The workspace URL cannot be used by the Databricks provider until the Azure workspace exists. That is why platform creation and workspace-level governance are applied in phases or supplied with outputs from the first phase.

## Commands you should be comfortable with

Run commands from the relevant stack directory:

```bash
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
terraform apply
terraform output
terraform state list
```

Understand these safety rules:

1. Confirm the active Azure tenant and subscription before planning.
2. Read the complete plan, especially every `destroy` and replacement (`-/+`).
3. Never apply a saved plan from an untrusted or different commit.
4. Never edit remote state manually.
5. Do not use `-target` as a routine deployment mechanism.
6. Import an existing object before Terraform assumes ownership; do not recreate it.
7. Treat state and plan files as sensitive even when source configuration has no secrets.
8. Commit provider lock files, but never commit `.tfstate`, saved plans, `.terraform/`, or local credentials.

## Changes a data engineer should be able to make

After learning this guide, you should be able to:

- Add a Unity Catalog schema with a clear owner and comment.
- Add or tighten grants for the runtime service principal.
- Add variables and outputs with validation and descriptions.
- Change a Databricks job in the bundle without moving its ownership to Terraform.
- Run formatting, validation, tests, and a plan.
- explain why a proposed plan is safe before applying it.
- Diagnose missing variables, authentication failures, drift, and permission errors.

Escalate changes involving networking, private endpoints and DNS, organization policy, subscription vending, cross-tenant identity, production state recovery, or unexplained destruction of shared resources.

## A practical two-week learning path

### Week 1: core Terraform

1. Learn blocks, expressions, variables, locals, outputs, resources, and data sources.
2. Trace every resource in the bootstrap and platform stacks to the Azure or Databricks object it controls.
3. Run `fmt`, `validate`, and `plan`; explain each planned action without applying it.
4. Learn state, imports, drift, provider lock files, and the difference between identifiers and credentials.

### Week 2: project delivery

1. Add a disposable schema or grant in a branch and inspect the plan.
2. Review the separation between Terraform governance and bundle-owned jobs.
3. Follow CI from pull-request checks to automatic `dev` deployment and manual `qual`/`prod` promotion.
4. Practice diagnosing a failed plan or permission error from logs.
5. Study modules and OIDC deeply enough to review them; leave advanced Azure networking for a platform-owned task.

## Readiness check

You are ready to contribute when you can answer all of these:

- What will Terraform create, update, replace, or destroy in this plan?
- Which provider and identity perform each API call?
- Does Terraform create this object or merely read it as a data source?
- Who owns the object: Terraform, a Databricks bundle, or an operator?
- Where is state stored, and could it contain sensitive information?
- If the apply fails halfway, what has already changed and what should be rerun?
- Does the runtime service principal have only the required Unity Catalog privileges?

For the concrete resource graph and Azure-side implementation, continue with [Terraform and Azure architecture](azure-architecture.md).
