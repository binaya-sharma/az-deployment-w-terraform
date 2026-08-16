| One bundle with dev, qual, and prod targets | Implemented |
| Environment-specific classic compute example | Documented; not active |# Multi-workspace deployment scaffold

Deploy one application definition to separate Databricks workspaces by selecting a bundle target and a protected GitHub environment. Do not maintain three copies of the job as JSON or YAML.

## Recommended topology

~~~text
Git commit and Python wheel
          |
Databricks bundle: one source definition
          |
          +-- target dev  -- GitHub environment dev  --> dev workspace
          +-- target qual -- GitHub environment qual --> qual workspace
          `-- target prod -- GitHub environment prod --> prod workspace
~~~

Each environment supplies its own workspace host, deployment identity, runtime identity, and Unity Catalog catalog. Application code and resource definitions remain identical. Target overrides contain only genuine environment differences such as schedules, sizing, or feature flags.

## Why not three JSON files?

Independent files drift. A permission fix may reach dev but be missed in qual, or production may run code different from what was tested. A single bundle provides one declarative source with small target overlays.

The target scaffold already exists in [databricks.yml](../../databricks.yml). The workspace host is deliberately not committed per target. The workflow selects a GitHub environment, which supplies DATABRICKS_HOST. The CLI therefore sends the bundle to the workspace associated with the selected environment.

## Environment contract

Create these same variable names in every GitHub environment, with environment-specific values:

| GitHub variable | dev | qual | prod | Purpose |
| --- | --- | --- | --- | --- |
| DATABRICKS_HOST | dev URL | qual URL | prod URL | Destination workspace |
| DATABRICKS_CLIENT_ID | dev deployer | qual deployer | prod deployer | Bundle authentication and ownership |
| DATABRICKS_RUNTIME_CLIENT_ID | dev runtime | qual runtime | prod runtime | Job run-as identity |
| DATABRICKS_CATALOG | dev catalog | qual catalog | prod catalog | Governed data boundary |

These values are identifiers, not secrets. Authentication still requires a short-lived GitHub OIDC token and an exact federation policy.

## Identity boundary

Use separate deployment and runtime service principals per environment:

~~~text
GitHub dev  -> dev federation policy  -> dev deployer  -> dev workspace
GitHub qual -> qual federation policy -> qual deployer -> qual workspace
GitHub prod -> prod federation policy -> prod deployer -> prod workspace
~~~

This prevents a compromised development identity from deploying to production. Each federation policy must match the exact GitHub environment subject and destination workspace audience. Do not broaden the dev policy to cover all environments.

The runtime identity receives only the required Unity Catalog privileges. The deployment identity manages bundle resources but should not normally write business data.

## Terraform boundary

Terraform creates long-lived workspace and governance foundations. The bundle creates application resources such as jobs and pipelines.

Use a reusable Terraform module with one root invocation per environment. Give each environment a separate remote-state key and normally a separate resource group. Production commonly also uses a separate subscription.

~~~text
Terraform
  +-- dev state  --> dev workspace, identities, catalogs and grants
  +-- qual state --> qual workspace, identities, catalogs and grants
  `-- prod state --> prod workspace, identities, catalogs and grants

Databricks bundle
  `-- deploys application resources into each provisioned workspace
~~~

Do not use Terraform workspaces as the only isolation boundary for unrelated production environments. Independent state and access boundaries make plans, recovery, and blast radius easier to reason about.

## Promotion flow

1. A pull request passes CI and receives required review.
2. A merge to main deploys automatically to the dev workspace.
3. The workflow records the built wheel and checksum.
4. An authorized reviewer manually promotes the tested revision to qual.
5. After validation, an authorized reviewer manually promotes the same immutable artifact to prod.

Automatic dev deployment and manual qual/prod targets are implemented. Reusing the exact dev wheel during later promotion, instead of rebuilding it, remains **TBD**.

## New-workspace checklist

1. Provision the workspace and Unity Catalog foundations with Terraform.
2. Create environment-specific deployment and runtime service principals.
3. Grant workspace access and bundle-resource ownership to the deployer.
4. Apply least-privilege Unity Catalog grants to the runtime identity.
5. Create the exact GitHub OIDC federation policy.
6. Configure the matching GitHub environment variables.
7. Require reviewers for qual and prod.
8. Validate and deploy without running the job, then execute a separately approved smoke test.

For local validation, use a distinct CLI profile per workspace:

~~~bash
databricks bundle validate --strict --target dev --profile dev
databricks bundle validate --strict --target qual --profile qual
databricks bundle validate --strict --target prod --profile prod
~~~

Never rely on an implicit profile for production. Confirm the target, profile, host, subscription, and planned changes before deployment.

## Current versus planned

| Capability | State |
| --- | --- |
| One bundle with dev, qual, and prod targets | Implemented |
| GitHub environment selects host, identities, and catalog | Implemented |
| Automatic dev; manual qual and prod | Implemented |
| Separate qual workspace and federation policy | TBD |
| Separate prod workspace and federation policy | TBD |
| Independent Terraform state per workspace | TBD |
| Promote the identical wheel across all environments | TBD |
| Environment-specific smoke tests and rollback runbook | TBD |

## Environment-specific compute

Different environments may use different compute configurations without copying the job logic.

The current retail smoke job uses serverless task environments. Serverless compute has no committed node type, Spark runtime, or worker count because Databricks manages that infrastructure. Keeping all environments serverless is the simplest and most cost-aware option for this deployment-focused project.

If classic job compute becomes necessary, keep the tasks in one resource definition and reference one shared job cluster key. Override only the job_clusters block under each target. The documentation-only [classic compute target example](examples/classic-compute-targets.yml) shows different policy IDs, node types, and autoscaling limits for dev, qual, and prod.

~~~text
Common job definition
  +-- common tasks and dependencies
  `-- job_cluster_key: shared_job_cluster

Target overlay
  +-- dev:  small nodes, autoscale 1-2
  +-- qual: representative nodes, autoscale 1-4
  `-- prod: approved nodes and policy, autoscale 2-8
~~~

Prefer a cluster policy per environment so administrators control allowed runtimes, node families, autoscaling limits, tags, and security mode. Bundle configuration selects an approved policy and supplies permitted values; it should not bypass platform governance.

A task cannot simultaneously use serverless environment_key and classic job_cluster_key. Moving only one environment to classic compute is therefore a deliberate structural variation. Validate every target after that change and avoid hiding a large duplicated task list inside target overrides. If the environments need fundamentally different task graphs, treat them as different workloads rather than pretending they are one promotion path.
