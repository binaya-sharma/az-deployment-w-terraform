# Project documentation

The documentation is organized by platform responsibility. Start with the main [project README](../Readme.md), then use the domain index below.

## Terraform and Azure

- [Terraform and Azure architecture](terraform/azure-architecture.md): bootstrap, remote state, providers, Azure resources, dependency graph, costs, and command lifecycle.
- [Terraform for data engineers](terraform/for-data-engineers.md): required Terraform knowledge, safe workflows, and a focused learning path.

## Deployment

- [Databricks deployment and identity runbook](deployment/databricks-identity-runbook.md): GitHub Actions, OIDC federation, deployment/runtime identities, permissions, promotion, and troubleshooting.
- [Multi-workspace deployment scaffold](deployment/multi-workspace-promotion.md): one bundle across separate dev, qual, and prod workspaces, environment contracts, identity isolation, Terraform boundaries, and promotion.
- [Retail pipeline](deployment/retail-pipeline.md): current bundle job, wheel entry point, Bronze/Silver/Gold smoke flow, and runtime behavior.

## Governance

- [User onboarding and least privilege](governance/user-onboarding.md): internal members versus external guests, group membership, Azure RBAC, Databricks, GitHub, verification, and offboarding.
- [RBAC and ABAC](governance/rbac-and-abac.md): Azure roles, Unity Catalog grants, row filters, column masks, and regional access policies.
- [Unity Catalog architecture and storage governance](governance/unity-catalog.md): namespace, metastores, managed/external data, volumes, AWS/Azure cloud storage access, lineage, and auditing.

## CDC and streaming

- [CDC architecture index](cdc/README.md): architecture, responsibilities, reliability, metadata, and acceptance criteria.
- [Structured Streaming file ingestion](cdc/structured-streaming-file-ingestion.md): S3/Auto Loader example, checkpoints, restartability, and idempotency boundaries.
- [Change Data Feed processing](cdc/change-data-feed.md): CDF enablement, update/delete propagation, Auto CDC, retention, and `VACUUM`.
- [Liquid clustering](cdc/liquid-clustering.md): physical layout, clustering-key selection, statistics, and optimization.
- [MySQL CDC to Delta CDF scaffold](cdc/mysql-to-delta-cdf.md): implemented Auto CDC definition, development source contract, and future Lakeflow Connect boundary.

## Images

Architecture images are stored in [`images/`](images/) and embedded in the relevant Terraform and deployment guides. They are supporting assets rather than executable configuration.
