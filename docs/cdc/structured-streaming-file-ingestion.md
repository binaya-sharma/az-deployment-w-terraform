# Structured Streaming file ingestion

> **Status:** design and learning example; this S3 flow is not deployed by the current bundle.

### When plain streaming is sufficient

Plain `readStream`/`writeStream` is appropriate when the contract is genuinely append-only—for example immutable click events, audit records, or a Bronze table that deliberately stores every CDC envelope as a new event. It is not sufficient by itself for synchronizing a mutable source into a current-state target.

### Practical file-ingestion example with S3

Structured Streaming is not limited to files: it can consume Kafka, Delta/CDF, and other streaming sources. When the source **is** object storage, Databricks recommends Auto Loader for incremental file discovery.

Assume this S3 prefix initially contains two immutable files:

```text
s3://retail-landing/customers/
├── ingestion_1.json
└── ingestion_2.json
```

A file-ingestion stream can be defined as:

```python
from pyspark.sql import functions as F
from pyspark.sql.types import LongType, StringType, StructField, StructType

landing_path = "s3://retail-landing/customers/"
catalog = "dbw_azref_sandbox_centralindia_001"
target_table = f"{catalog}.bronze.customer_events"
state_root = f"/Volumes/{catalog}/ops/streaming_state/customers_bronze"
schema_path = f"{state_root}/schema"
checkpoint_path = f"{state_root}/checkpoint"

customer_schema = StructType(
    [
        StructField("customer_id", LongType(), nullable=False),
        StructField("name", StringType(), nullable=True),
        StructField("country_code", StringType(), nullable=True),
        StructField("status", StringType(), nullable=True),
    ]
)

source = (
    spark.readStream.format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", schema_path)
    .schema(customer_schema)
    .load(landing_path)
    .select(
        "*",
        F.col("_metadata.file_path").alias("_source_file"),
        F.current_timestamp().alias("_ingested_at"),
    )
)

query = (
    source.writeStream.format("delta")
    .outputMode("append")
    .option("checkpointLocation", checkpoint_path)
    .trigger(availableNow=True)
    .toTable(target_table)
)

query.awaitTermination()

# Operational verification: which files contributed records?
(
    spark.table(target_table)
    .groupBy("_source_file")
    .count()
    .orderBy("_source_file")
    .show(truncate=False)
)
```

Expected after the first run:

```text
_source_file                                      | count
s3://retail-landing/customers/ingestion_1.json   | ...
s3://retail-landing/customers/ingestion_2.json   | ...
```

After `ingestion_3.json` arrives, rerun the same code with the same checkpoint. The verification output gains `ingestion_3.json`; the earlier files are not normally ingested again.

Conceptual execution:

```text
First run
├── discover ingestion_1.json and ingestion_2.json
├── process both files
├── commit output to the Delta target
└── record source progress and completed batches in the checkpoint

Second run with the same checkpoint and no new files
└── process zero files

Later, ingestion_3.json arrives

Third run with the same checkpoint
├── skip ingestion_1.json and ingestion_2.json
├── process ingestion_3.json
└── advance the checkpoint
```

This is incremental and restartable because the source and checkpoint identify which files belong to completed micro-batches. If a run fails before a batch is committed, Spark can retry that batch after restart.

Important boundaries:

- Keep landing files immutable. Do not overwrite `ingestion_1.json` and expect the same path to behave like a database update. Deliver a new uniquely named file/event instead.
- Use one durable checkpoint per stream/target. Reusing a checkpoint across different streams is invalid; deleting or changing it can cause files to be rediscovered and reprocessed.
- A checkpoint provides source progress and recovery state, but not universal exactly-once behavior. A transactional Delta sink works with the streaming commit protocol; external APIs or custom `foreachBatch` side effects must implement their own idempotency using a batch ID, source key, or transactional upsert.
- Checkpoints should live in durable platform-managed storage with restricted access. The UC Volume path above is illustrative; on AWS it is ultimately backed by cloud object storage.
- `availableNow=True` is a good cost-conscious pattern for periodically processing all currently available files and then stopping. A continuously running trigger is justified only by the latency requirement.
- File ingestion propagates the records contained in newly discovered files. If an upstream system needs updates/deletes propagated, each file must carry an explicit CDC envelope, or the landed Delta table must expose CDF and a downstream apply engine must interpret it.

The core distinction is:

```text
new immutable files + checkpoint -> incremental append ingestion
CDF operation metadata + checkpoint + apply engine -> CDC state propagation
```


## References

- [Databricks Auto Loader](https://learn.microsoft.com/en-us/azure/databricks/ingestion/cloud-object-storage/auto-loader/)
- [Structured Streaming checkpoints](https://learn.microsoft.com/en-us/azure/databricks/structured-streaming/checkpoints)
- [CDC documentation index](README.md)
