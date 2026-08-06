# Databricks deployment workflow

The repository uses GitHub environments and Databricks workload identity federation to deploy without passwords, personal access tokens, or client secrets.

## Promotion model

```text
pull request -> CI -> merge to main -> dev
                                      |
                                      +-> approved qual promotion
                                               |
                                               +-> approved prod promotion
```

After the main-branch CI workflow succeeds, `dev` deploys automatically from the exact tested commit. `qual` and `prod` are available only through manual workflow dispatch from `main` and should use protected GitHub environments.

Deploying the bundle creates or updates Databricks job definitions and uploads the wheel. It does not run the job. The smoke-test source contracts contain no records, and `databricks bundle run` is intentionally absent because running the job starts serverless compute and can incur usage charges.

## Identities

Keep these identities separate:

- The **deployment service principal** authenticates GitHub Actions and manages bundle-owned workspace objects.
- The **runtime service principal** is specified by the bundle's `run_as` block and receives the minimum Unity Catalog data privileges required by the job.

The deployment principal should not receive normal write access to pipeline tables. The runtime principal should not receive permission to change GitHub workflows or platform infrastructure.

Use one deployment federation policy per GitHub environment. The expected OIDC subjects are:

```text
repo:binaya-sharma/az-deployment-w-terraform:environment:dev
repo:binaya-sharma/az-deployment-w-terraform:environment:qual
repo:binaya-sharma/az-deployment-w-terraform:environment:prod
```

## GitHub environment configuration

Create environments named `dev`, `qual`, and `prod` under **Settings -> Environments**. Define these environment variables in each environment:

| Variable | Purpose | Dev value |
| --- | --- | --- |
| `DATABRICKS_HOST` | Target workspace URL | `https://adb-7405618741367416.16.azuredatabricks.net` |
| `DATABRICKS_CLIENT_ID` | Deployment service-principal application ID | `feb13c34-eccb-4341-8ce4-0d4b5700157a` |
| `DATABRICKS_RUNTIME_CLIENT_ID` | Job runtime service-principal application ID | `7598c51f-25f3-44fc-9b89-a1af87366465` |
| `DATABRICKS_CATALOG` | Default-storage catalog containing Terraform-managed schemas | `dbw_azref_sandbox_centralindia_001` |

The dev identity objects were bootstrapped manually and must be imported if Terraform assumes ownership; never recreate them under the same names.

These are identifiers and configuration values, not credentials. The short-lived GitHub OIDC token is exchanged at runtime and is never committed.

Configure required reviewers for `qual` and `prod`. Restrict production deployment to the protected `main` branch and prevent self-review when the repository plan supports it.

## Safe rollout

1. Create the Databricks deployment and runtime service principals.
2. Add the deployment principal to the workspace and grant only the workspace permissions needed to deploy bundle-owned resources.
3. Create the `dev` federation policy using the exact environment subject above.
4. Use the workspace-managed default-storage catalog `dbw_azref_sandbox_centralindia_001` and apply the Terraform-managed schemas, grants, restricted bundle directory, and identity assignments.
5. Configure the four `dev` GitHub environment variables.
6. Merge the configured workflow to `main`; a successful CI run automatically deploys `dev`.
7. Confirm that the job definition exists, is owned/deployed by the deployment identity, and is configured to run as the runtime identity. Do not execute the job during the deployment test.
8. Promote the tested `main` revision manually to `qual` and then `prod` after their protected environments are configured.

The workflow uses `cancel-in-progress: false` so a newer commit cannot interrupt a deployment midway through reconciliation.
