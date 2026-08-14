"""Apply a source Delta table's Change Data Feed to Silver current state."""

from pyspark import pipelines as dp
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.getActiveSession()
if spark is None:
    raise RuntimeError("An active Spark session is required by the CDC pipeline.")

SOURCE_TABLE = spark.conf.get("source_table")


@dp.temporary_view(name="customer_cdf_events")
def customer_cdf_events():
    """Normalize Delta CDF rows into the operation contract expected by Auto CDC."""
    return (
        spark.readStream.option("readChangeFeed", "true")
        .table(SOURCE_TABLE)
        .filter(F.col("_change_type").isin("insert", "update_postimage", "delete"))
        .withColumn(
            "operation",
            F.when(F.col("_change_type") == "delete", F.lit("DELETE")).otherwise(F.lit("UPSERT")),
        )
    )


dp.create_streaming_table(
    name="customers_current",
    comment="SCD Type 1 customer state maintained from Bronze Delta CDF.",
    cluster_by=["customer_id"],
    expect_all_or_fail={"customer_id_is_present": "customer_id IS NOT NULL"},
)

dp.create_auto_cdc_flow(
    name="apply_customer_cdf",
    target="customers_current",
    source="customer_cdf_events",
    keys=["customer_id"],
    sequence_by=F.struct("_commit_version", "_commit_timestamp"),
    apply_as_deletes=F.expr("operation = 'DELETE'"),
    except_column_list=[
        "operation",
        "_change_type",
        "_commit_version",
        "_commit_timestamp",
    ],
    stored_as_scd_type=1,
)
