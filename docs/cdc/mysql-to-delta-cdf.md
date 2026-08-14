# MySQL CDC to Delta CDF scaffold

## Recommendation

MySQL is the more realistic source for this prototype. Lakeflow Connect can
capture MySQL database changes through a managed CDC connector, whereas the
Oracle connector path currently available in the same catalog is query-based.
MySQL CDC still requires a gateway and network connectivity, so provisioning a
database only for this reference project would add cost without improving the
downstream CDC logic.

Use two phases:

```text
Current scaffold
Synthetic or manually changed Bronze Delta table with CDF enabled
  -> Lakeflow Auto CDC
  -> Silver current-state table

Future source integration
MySQL transaction log
  -> Lakeflow Connect gateway and ingestion pipeline
  -> Bronze Unity Catalog Delta table
  -> Delta CDF
  -> the same Lakeflow Auto CDC pipeline
```

This boundary lets the project verify insert, update, delete, ordering, replay,
and governance behavior without running a database or ingestion gateway.

## Implemented bundle resource

The unscheduled `customer_cdc` pipeline is defined in
[`resources/customer_cdc.pipeline.yml`](../../resources/customer_cdc.pipeline.yml).
It publishes to the existing `silver` schema and reads this configured source:

```text
${catalog}.bronze.customers
```

The transformation in
[`customer_cdf.py`](../../src/pipelines/customer_cdc/customer_cdf.py):

1. Reads the source table with `readChangeFeed=true`.
2. Keeps inserts, update postimages, and deletes.
3. Ignores update preimages because they are not the new current state.
4. Orders changes by Delta commit version and timestamp.
5. Applies deletes and upserts using Lakeflow Auto CDC.
6. Maintains `${catalog}.silver.customers_current` as SCD Type 1.

The pipeline uses triggered mode and has no schedule. A bundle deployment only
creates or updates its definition; compute starts only when someone explicitly
runs the pipeline.

## Bronze source contract

Create a small development source table before the first run:

```sql
CREATE TABLE <catalog>.bronze.customers (
  customer_id BIGINT NOT NULL,
  customer_name STRING,
  country_code STRING,
  status STRING,
  updated_at TIMESTAMP
)
TBLPROPERTIES (delta.enableChangeDataFeed = true);
```

Only commits made after CDF is enabled are available as change history. On the
first streaming read without an explicit starting version, the current table
snapshot is processed as inserts, followed by later changes.

Test all three mutation types:

```sql
INSERT INTO <catalog>.bronze.customers
VALUES (101, 'Asha', 'NP', 'ACTIVE', current_timestamp());

UPDATE <catalog>.bronze.customers
SET status = 'INACTIVE', updated_at = current_timestamp()
WHERE customer_id = 101;

DELETE FROM <catalog>.bronze.customers
WHERE customer_id = 101;
```

## MySQL integration boundary

When a real source is justified, add a Unity Catalog connection and a Lakeflow
Connect MySQL CDC ingestion pipeline. The source database must provide:

- a stable primary key;
- transaction-log retention longer than the maximum connector outage;
- a restricted database account with only connector-required privileges;
- network reachability from the ingestion gateway;
- an initial snapshot boundary followed by ordered log changes.

Keep source credentials in the Unity Catalog connection, not in this repository
or bundle variables. The deployment service principal manages definitions. The
runtime service principal receives only the source read and Silver target write
privileges required by this pipeline.

MySQL CDC in Lakeflow Connect is currently a Public Preview capability. Confirm
regional availability, support status, gateway compute cost, and connector
requirements before treating it as a production dependency.

## Acceptance test

A production-ready version must demonstrate:

- initial hydration produces one Silver row per source key;
- repeated processing is idempotent;
- an update changes the existing Silver row without duplication;
- a source delete removes the Silver row;
- invalid null keys fail the update;
- an outage within CDF and transaction-log retention recovers normally;
- a retention gap triggers controlled rehydration rather than silent loss;
- the runtime identity can read Bronze and mutate Silver but cannot administer
  the pipeline or unrelated schemas.
