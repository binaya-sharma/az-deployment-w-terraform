"""Databricks Python wheel entry point."""

import argparse

from retail_analytics.pipeline import statements_for


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run one retail medallion layer")
    parser.add_argument("--layer", choices=("bronze", "silver", "gold"), required=True)
    parser.add_argument("--catalog", required=True)
    return parser.parse_args()


def main() -> None:
    from pyspark.sql import SparkSession

    args = parse_args()
    spark = SparkSession.getActiveSession() or SparkSession.builder.getOrCreate()
    for statement in statements_for(args.layer, args.catalog):
        spark.sql(statement)
    print(f"Completed {args.layer} layer in catalog {args.catalog}")
