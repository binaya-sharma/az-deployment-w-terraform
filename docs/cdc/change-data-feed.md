# Change Data Feed processing

> **Status:** design and learning example; CDF processing is not deployed by the current bundle.

## Why Lakeflow Auto CDC

The preferred implementation is a serverless Lakeflow Spark Declarative Pipeline using Auto CDC. It provides managed handling for ordered inserts, updates, deletes, and SCD Type 1 or Type 2 targets, avoiding custom `foreachBatch` and `MERGE` state logic for the normal CDC path.

Delta Change Data Feed and Structured Streaming serve different purposes:

- Change Data Feed is a Delta table feature that exposes row-level change semantics and commit metadata.
- Structured Streaming is the incremental execution engine. It can consume CDF with `readStream`, but it neither creates CDF nor propagates updates/deletes into a current-state target by itself.
- Auto CDC applies the ordered changes to target state.

If the upstream boundary is already a Delta table, enable and consume CDF there. For a database or event system, use its supported connector or streaming interface and normalize its envelope in Bronze.

### Enable Change Data Feed

For the established per-table (legacy) CDF mode, enable it when creating the table:

```sql
CREATE TABLE bronze.customers (
  customer_id BIGINT,
  name STRING,
  country_code STRING,
  status STRING
)
TBLPROPERTIES (delta.enableChangeDataFeed = true);
```

Or enable it on an existing table:

```sql
ALTER TABLE bronze.customers
SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
```

Verify the property:

```sql
SHOW TBLPROPERTIES bronze.customers ('delta.enableChangeDataFeed');
```

Only changes committed after enablement are present in legacy CDF. Turning it off creates an unqueryable gap. Record the enablement version and initial-snapshot boundary before starting downstream processing.

Current Azure Databricks versions also provide automatic CDF based on row tracking/row lineage for supported Unity Catalog tables. At the time this guide was updated, automatic CDF was a Public Preview with specific runtime and table requirements. The stable implementation decision for this project must be made against the runtime and feature status selected for production; do not silently mix automatic and legacy CDF.

## Practical example: why streaming alone is not CDC

Assume the source is a current-state Delta table:

```text
customers
customer_id | name | country | status
101         | Asha | NP      | ACTIVE
```

Three source transactions occur:

1. Insert customer `102`.
2. Update customer `101` from `ACTIVE` to `INACTIVE`.
3. Delete customer `102`.

### Plain incremental `readStream` and `writeStream`

This looks incremental, but it is not a complete CDC implementation:

```python
(
    spark.readStream.table("bronze.customers")
    .writeStream.option("checkpointLocation", checkpoint_path)
    .toTable("silver.customers")
)
```

Structured Streaming tracks which new source commits/files it has processed. That solves incremental execution and restartability, but the ordinary Delta streaming source is designed around appended data. It does not turn an update or delete in a current-state source into an instruction that mutates the matching target row.

Depending on the source operation and options, non-append changes can fail the stream or be skipped/treated as newly observed data. Skipping change commits prevents the pipeline from receiving the update and delete; treating rewritten rows as appends can create duplicates. An append `writeStream` also appends received rows—it does not perform a key-based target `UPDATE` or `DELETE`.

The incorrect target can therefore retain stale data:

```text
silver.customers
101 | Asha | NP | ACTIVE   <- update was not applied
102 | ...                  <- delete was not applied
```

### CDF supplies change semantics

When Change Data Feed is enabled before these transactions, reading the source with `readChangeFeed` yields change records with metadata:

```python
cdf = spark.readStream.option("readChangeFeed", "true").table("bronze.customers")
```

Conceptually, the feed contains:

```text
customer_id | status   | _change_type       | _commit_version
102         | ACTIVE   | insert             | 20
101         | ACTIVE   | update_preimage    | 21
101         | INACTIVE | update_postimage   | 21
102         | ACTIVE   | delete             | 22
```

CDF answers **what changed and in which commit**. Structured Streaming answers **how to consume new feed versions incrementally and recover from checkpoints**.

### The target still needs an apply engine

This is still incomplete:

```python
cdf.writeStream.toTable("silver.customers")
```

It creates an append-only history of change events; it does not maintain a current-state target. To propagate source state, an apply engine must interpret the operation, key, and sequence:

```text
insert/update_postimage -> insert or update customer_id
delete                  -> delete customer_id
update_preimage         -> audit/history input; not the new current value
```

For this project, Lakeflow Auto CDC is preferred because it applies ordered inserts, updates, and deletes and supports SCD Type 1/2 without custom merge state. A custom alternative is `foreachBatch` plus an idempotent Delta `MERGE`, but that code must handle duplicates, ordering, replay, multiple source rows for one key, deletes, checkpoint recovery, and observability.


## CDF limitations and design consequences

- CDF records changes only after it is enabled; it does not reconstruct earlier history. Perform an explicit initial snapshot, then continue from a recorded CDF version/timestamp.
- CDF is not a permanent event archive. Legacy CDF change files use the table retention policy and are deleted by `VACUUM`; changes reconstructed from the transaction log also disappear when the corresponding versions are cleaned up. A checkpoint cannot recover a feed version that no longer exists.
- The default `VACUUM` retention threshold for data files is seven days, while transaction-log cleanup is separate and commonly has a longer default. Do not treat either default as a recovery SLA. Set retention from the maximum consumer outage/replay requirement, monitor lag, and archive CDF into an append-only Bronze history when permanent recovery is required.
- Lowering retention saves storage but shortens time travel and CDC replay. Databricks recommends at least seven days because overly aggressive `VACUUM` can also endanger long-running operations.
- Starting from a version that is no longer available fails. Monitor consumer lag and treat an unrecoverable gap as a controlled re-hydration event.
- CDF describes changes made to a Delta table. It cannot invent delete/update semantics when the upstream only delivers snapshots without keys, operations, or reliable ordering.
- Update preimages and postimages must not both be applied as current rows. Apply the correct image using a deterministic sequence.
- Commit versions order one table's Delta commits; they do not provide a global business order across independent tables.
- Schema changes require compatibility planning and tests. Consumers should fail safely instead of silently dropping or miscasting columns.
- A checkpoint records stream progress; it does not replace target keys, sequence rules, constraints, or audit metrics.
- Multiple downstream consumers need independent checkpoints. Deleting or reusing one can cause replay, gaps, or conflicting progress.

The production pattern is:

```text
initial snapshot
-> enable/confirm CDF boundary
-> read CDF incrementally with a durable checkpoint
-> validate and order changes
-> Auto CDC (preferred) or idempotent foreachBatch + MERGE
-> current-state/SCD target
-> audit counts and last applied source version
```


## References

- [Azure Databricks Change Data Feed](https://learn.microsoft.com/en-us/azure/databricks/tables/features/change-data-feed)
- [Azure Databricks `VACUUM`](https://learn.microsoft.com/en-us/azure/databricks/tables/operations/vacuum)
- [CDC documentation index](README.md)
