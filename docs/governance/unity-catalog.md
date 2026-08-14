# Unity Catalog architecture and storage governance

> **Status:** the sandbox workspace has Unity Catalog enabled and Terraform-managed schemas/grants. External storage credentials, external locations, and human access groups are design guidance until explicitly implemented.

Unity Catalog (UC) is the centralized governance layer for data and AI assets in Databricks. It provides a consistent namespace, access-control model, ownership, discovery, lineage, and auditing for objects such as catalogs, schemas, tables, views, volumes, functions, and models.

## What Unity Catalog solves

```text
Databricks account
└── Unity Catalog metastore
    ├── identities and groups
    ├── permissions and ownership
    ├── audit and lineage metadata
    └── catalog
        └── schema
            ├── table or view
            ├── volume
            ├── function
            └── model
```

The three-part object name is:

```text
catalog.schema.object
```

For example:

```text
dbw_azref_sandbox_centralindia_001.bronze.customer_events
├── catalog: dbw_azref_sandbox_centralindia_001
├── schema:  bronze
└── object:  customer_events
```

A schema is also commonly called a database. Unlike the legacy Hive metastore's two-level `schema.object` organization, UC adds the catalog boundary and centralizes governance across assigned workspaces.

## Account, metastore, and workspace

- A Databricks account can contain multiple workspaces.
- A Unity Catalog metastore is a regional governance boundary and can be assigned to multiple workspaces in its supported region.
- A workspace is assigned to one UC metastore at a time.
- The metastore stores governance metadata; tables and volumes store their data in managed or external cloud storage.
- Account administrators manage account-level identities, groups, metastore assignments, and other account objects. Workspace administrators manage workspace-scoped access.
- Serverless compute runs in the Databricks-managed serverless environment. Classic compute runs in the customer's cloud subscription/account according to the selected network model.

Do not delete an automatically configured metastore simply because custom storage is needed. First determine the intended account/region design and whether a catalog, schema, external location, or workspace assignment solves the requirement. Metastore replacement is an administrative migration, not a normal developer step.

## Current project model

```text
Azure subscription
└── Azure Databricks workspace
    └── regional Unity Catalog metastore
        └── dbw_azref_sandbox_centralindia_001
            ├── bronze
            ├── silver
            └── gold
```

Terraform owns the stable catalog/schema governance and runtime-service-principal grants. The Databricks bundle owns jobs and application deployment. The runtime service principal performs approved table writes; human access should be assigned through account groups.

## Managed and external storage

The terms **managed** and **external** describe who controls the storage path and data lifecycle.

| Object | Storage path | Lifecycle when UC object is dropped | Typical use |
| --- | --- | --- | --- |
| Managed table | UC chooses a path under the metastore/catalog/schema managed location | UC manages metadata and data lifecycle | Default for governed Delta tables |
| External table | Explicit path under a registered external location | UC drops metadata; cloud files remain | Existing/shared data or externally controlled lifecycle |
| Managed volume | UC chooses managed storage | UC manages the volume data lifecycle | Governed files with Databricks-managed storage |
| External volume | Explicit cloud path under an external location | Cloud storage lifecycle remains externally controlled | Existing landing/export/unstructured files |

A catalog can have a `MANAGED LOCATION` while containing both managed and external tables. This does **not** make it an “external catalog.” A **foreign catalog** used for Lakehouse Federation is a separate concept.

Default to managed tables unless an existing path, another engine, retention ownership, or regulatory boundary requires external storage.

## Tables versus volumes

| UC object | Best for | Access |
| --- | --- | --- |
| Table | Structured rows queried with SQL/Spark | `SELECT`, `MODIFY` |
| Volume | Files such as JSON, CSV, images, PDFs, wheels, checkpoints, and exports | `READ VOLUME`, `WRITE VOLUME` |

Volume paths follow the UC hierarchy:

```text
/Volumes/<catalog>/<schema>/<volume>/<file>
```

Example:

```text
/Volumes/main/raw/customer_files/ingestion_001.json
```

The Databricks CLI requires the `dbfs:` scheme for file commands:

```bash
databricks fs ls dbfs:/Volumes/main/raw/customer_files/
```

A volume does not always point to external storage. Managed and external volumes both exist.

## External cloud storage access

UC separates the cloud identity from the governed path:

```text
cloud identity
-> storage credential
-> external location
-> external table or external volume
-> catalog/schema grants to consumers
```

- A **storage credential** wraps an AWS IAM role, Azure managed identity/access connector, or equivalent cloud identity.
- An **external location** binds that credential to an approved cloud path.
- An **external table/volume** registers data beneath the governed location.
- UC privileges control which Databricks principals can use those objects.

Do not place long-lived AWS keys, Azure client secrets, or storage account keys in notebooks, bundle files, Terraform variables committed to Git, or cluster Spark configuration.

## AWS example: separate raw and processed S3 buckets

Requirement:

```text
s3://binayaretail-raw/       -> ingestion identity can read
s3://binayaretail-processed/ -> pipeline identity can write
```

A least-privilege design uses AWS IAM roles with bucket/prefix-scoped policies. Use separate roles/credentials when read and write duties must be independently revoked or audited; one role can cover both paths only when that broader trust boundary is approved.

Conceptual UC setup:

```sql
CREATE STORAGE CREDENTIAL retail_raw_read
WITH AWS_IAM_ROLE 'arn:aws:iam::123456789012:role/uc-retail-raw-read';

CREATE STORAGE CREDENTIAL retail_processed_write
WITH AWS_IAM_ROLE 'arn:aws:iam::123456789012:role/uc-retail-processed-write';

CREATE EXTERNAL LOCATION retail_raw
URL 's3://binayaretail-raw/'
WITH (CREDENTIAL retail_raw_read);

CREATE EXTERNAL LOCATION retail_processed
URL 's3://binayaretail-processed/'
WITH (CREDENTIAL retail_processed_write);
```

Register files as external volumes:

```sql
CREATE EXTERNAL VOLUME retail.bronze.raw_files
LOCATION 's3://binayaretail-raw/customer/';

CREATE EXTERNAL VOLUME retail.gold.exports
LOCATION 's3://binayaretail-processed/exports/';
```

Or register structured Delta data as an external table:

```sql
CREATE EXTERNAL TABLE retail.silver.customers
USING DELTA
LOCATION 's3://binayaretail-processed/tables/customers';
```

Grant consumers access to the UC objects instead of exposing raw bucket credentials:

```sql
GRANT USE CATALOG ON CATALOG retail TO `retail_pipeline_runtimes`;
GRANT USE SCHEMA ON SCHEMA retail.bronze TO `retail_pipeline_runtimes`;
GRANT READ VOLUME ON VOLUME retail.bronze.raw_files
TO `retail_pipeline_runtimes`;

GRANT USE SCHEMA ON SCHEMA retail.gold TO `retail_pipeline_runtimes`;
GRANT WRITE VOLUME ON VOLUME retail.gold.exports
TO `retail_pipeline_runtimes`;
```

Cloud IAM permissions and UC privileges are both required. UC cannot grant an operation that the underlying AWS IAM role cannot perform.

## Azure equivalent for this project

On Azure, the equivalent layers are:

```text
ADLS storage account
└── container/path
    ↑
Databricks Access Connector managed identity
    ↑
Unity Catalog storage credential
    ↑
external location
    ↑
external table or volume
```

Use an Azure managed identity through a Databricks Access Connector where supported. Grant the connector only the required Azure data-plane role and scope, then register that identity/path in UC. This is separate from Azure management-plane `Reader` or `Contributor` access.

In AWS, an S3 bucket is the primary storage container. In Azure, an ADLS Gen2 storage account contains one or more containers, which are the closest equivalent to S3 buckets.

## Correct privilege model

To reach an object, a principal normally needs traversal privileges on its parents plus the action privilege:

```sql
GRANT USE CATALOG ON CATALOG analytics TO `analysts`;
GRANT USE SCHEMA ON SCHEMA analytics.gold TO `analysts`;
GRANT SELECT ON TABLE analytics.gold.orders TO `analysts`;

GRANT USE CATALOG ON CATALOG analytics TO `etl_runtimes`;
GRANT USE SCHEMA ON SCHEMA analytics.silver TO `etl_runtimes`;
GRANT MODIFY ON TABLE analytics.silver.cleaned_orders TO `etl_runtimes`;

GRANT READ VOLUME ON VOLUME analytics.bronze.customer_files
TO `ml_team`;
```

Corrections to legacy terminology:

- Use `USE CATALOG`, not `USAGE ON CATALOG`.
- Use `MODIFY` for table inserts, updates, deletes, and merges; there is no general UC `UPDATE` table privilege.
- `USE CATALOG` and `USE SCHEMA` do not grant data access by themselves.
- Grant to account groups/service principals, not directly to individuals.
- Own securables with groups; use `MANAGE` for delegated permission administration.

Inspect access with:

```sql
SHOW GRANTS ON CATALOG analytics;
SHOW GRANTS ON SCHEMA analytics.gold;
SHOW GRANTS ON TABLE analytics.gold.orders;
```

## Lineage, auditing, and discovery

Unity Catalog captures governance metadata beyond permissions:

- **Lineage:** upstream/downstream relationships between tables and columns.
- **Audit:** access attempts, object changes, and permission changes.
- **Information schema:** catalogs, schemas, tables, columns, volumes, functions, tags, and grants.
- **Discovery:** searchable comments, ownership, tags, and object metadata.

Example lineage query:

```sql
SELECT source_table_full_name, target_table_full_name, event_time
FROM system.access.table_lineage
WHERE target_table_full_name =
  'dbw_azref_sandbox_centralindia_001.gold.customer_summary'
  AND event_date >= current_date() - 30;
```

Example permission inventory:

```sql
SELECT grantee, table_catalog, table_schema, table_name, privilege_type
FROM system.information_schema.table_privileges
WHERE table_catalog = 'dbw_azref_sandbox_centralindia_001'
ORDER BY table_schema, table_name, grantee;
```

System schemas must be enabled/available and separately granted. Always filter large system tables by their date partition.

## Medallion architecture and UC

Bronze, Silver, and Gold are data-quality/processing layers. UC governs the objects in every layer:

| Layer | Typical content | Typical access |
| --- | --- | --- |
| Bronze | Raw files/events and ingestion metadata | Runtime read/write; humans restricted |
| Silver | Validated current state or history | Runtime `MODIFY`; engineers read |
| Gold | Business-facing facts/dimensions | Analysts `SELECT`; runtime writes |
| Operations | Checkpoints, audit outputs, quality metrics | Platform/runtime only |

UC does not perform ETL. Spark, Lakeflow pipelines, and jobs transform data; UC governs the inputs, outputs, and identities.

Partitioning is also not chosen automatically as a governance behavior. A write is unpartitioned unless code/table DDL specifies partitioning or another layout mechanism such as liquid clustering is configured. See the [liquid-clustering guide](../cdc/liquid-clustering.md).

## Hive metastore comparison

| Legacy Hive metastore | Unity Catalog |
| --- | --- |
| Usually workspace-scoped | Account-level governance shared by assigned workspaces |
| Two-level `schema.object` namespace | Three-level `catalog.schema.object` namespace |
| Fragmented permissions/lineage | Central grants, ownership, lineage, auditing |
| Path-based access common | Governed tables, volumes, credentials, and external locations |
| Suitable for local Spark learning | Recommended Databricks governance model |

A local Spark environment may use an embedded/external Hive metastore to persist table metadata across sessions. That does not provide the centralized Databricks account governance of Unity Catalog.

## Terraform boundary in this repository

Terraform should manage stable governance foundations:

- catalog and schemas
- account-group/service-principal lookups
- grants and ownership
- external locations/storage credentials when the cloud design is approved
- workspace/metastore assignments when in scope

The Databricks bundle should manage application jobs/pipelines. Pipeline code should read/write approved UC objects, not create unreviewed catalogs, external locations, or broad grants dynamically.

## Validation checklist

- Confirm workspace and metastore assignment.
- Confirm catalog/schema/object ownership uses groups or platform identities.
- Verify traversal plus action privileges.
- Validate the underlying cloud identity against each external path.
- Keep raw and processed paths separately scoped where required.
- Test that the runtime can perform required reads/writes and cannot access unrelated paths.
- Verify humans cannot write governed pipeline tables by default.
- Query lineage and audit data after a test run.
- Confirm managed/external drop behavior in a disposable environment.
- Store no cloud credentials in Git, notebooks, or bundle variables.

## Related guides

- [RBAC and ABAC](rbac-and-abac.md)
- [User onboarding](user-onboarding.md)
- [CDC architecture](../cdc/README.md)
- [Liquid clustering](../cdc/liquid-clustering.md)
- [Terraform and Azure architecture](../terraform/azure-architecture.md)

## References

- [Unity Catalog overview](https://learn.microsoft.com/en-us/azure/databricks/data-governance/unity-catalog/)
- [Unity Catalog privileges](https://learn.microsoft.com/en-us/azure/databricks/data-governance/unity-catalog/manage-privileges/privileges)
- [Managed and external tables](https://learn.microsoft.com/en-us/azure/databricks/tables/managed)
- [Storage credentials](https://learn.microsoft.com/en-us/azure/databricks/connect/unity-catalog/cloud-storage/storage-credentials)
- [External locations](https://learn.microsoft.com/en-us/azure/databricks/connect/unity-catalog/cloud-storage/external-locations)
- [Unity Catalog volumes](https://learn.microsoft.com/en-us/azure/databricks/volumes/)
- [System tables](https://learn.microsoft.com/en-us/azure/databricks/admin/system-tables/)
