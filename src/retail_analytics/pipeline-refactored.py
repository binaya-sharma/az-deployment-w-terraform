"""SQL definitions for a small, deterministic medallion pipeline."""

import re
from decimal import Decimal
from typing import Callable

_IDENTIFIER_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")

SUPPORTED_LAYERS = ("bronze", "silver", "gold")


def object_name(catalog: str, schema: str, table: str) -> str:
    """Return a validated three-level Unity Catalog object name."""
    parts = (catalog, schema, table)

    if not all(_IDENTIFIER_PATTERN.fullmatch(part) for part in parts):
        raise ValueError(
            "Catalog, schema, and table names must be lowercase SQL identifiers"
        )

    return ".".join(f"`{part}`" for part in parts)


def table(catalog: str, layer: str, name: str) -> str:
    """Return a validated table name for a medallion layer."""
    if layer not in SUPPORTED_LAYERS:
        raise ValueError(f"Unsupported layer: {layer}")

    return object_name(catalog, layer, name)


def net_amount(
    quantity: int,
    unit_price: str,
    discount_percent: str,
) -> Decimal:
    """Calculate a deterministic expected net amount for unit tests."""
    quantity_value = Decimal(quantity)
    price = Decimal(unit_price)
    discount = Decimal(discount_percent)

    gross = quantity_value * price
    discount_factor = Decimal("1") - discount / Decimal("100")

    return gross * discount_factor


def bronze_statements(catalog: str) -> list[str]:
    """Create empty Bronze source contracts."""

    customers = table(catalog, "bronze", "customers")
    products = table(catalog, "bronze", "products")
    sales = table(catalog, "bronze", "sales")

    return [
        f"""
        CREATE OR REPLACE TABLE {customers} (
            customer_id STRING,
            customer_name STRING,
            city STRING,
            loyalty_tier STRING
        )
        USING DELTA
        """.strip(),
        f"""
        CREATE OR REPLACE TABLE {products} (
            product_id STRING,
            product_name STRING,
            category STRING,
            unit_price DECIMAL(12,2)
        )
        USING DELTA
        """.strip(),
        f"""
        CREATE OR REPLACE TABLE {sales} (
            sale_id STRING,
            sale_ts TIMESTAMP,
            customer_id STRING,
            product_id STRING,
            quantity INT,
            discount_percent DECIMAL(5,2)
        )
        USING DELTA
        """.strip(),
    ]


def silver_statements(catalog: str) -> list[str]:
    """Create cleaned Silver tables from Bronze."""

    bronze_customers = table(catalog, "bronze", "customers")
    bronze_products = table(catalog, "bronze", "products")
    bronze_sales = table(catalog, "bronze", "sales")

    silver_customers = table(catalog, "silver", "customers")
    silver_products = table(catalog, "silver", "products")
    silver_sales = table(catalog, "silver", "sales")

    return [
        f"""
        CREATE OR REPLACE TABLE {silver_customers} AS
        SELECT
            customer_id,
            trim(customer_name) AS customer_name,
            initcap(trim(city)) AS city,
            coalesce(lower(loyalty_tier), 'standard') AS loyalty_tier
        FROM {bronze_customers}
        WHERE customer_id IS NOT NULL
        """.strip(),
        f"""
        CREATE OR REPLACE TABLE {silver_products} AS
        SELECT
            product_id,
            trim(product_name) AS product_name,
            lower(category) AS category,
            cast(unit_price AS DECIMAL(12,2)) AS unit_price
        FROM {bronze_products}
        WHERE product_id IS NOT NULL
          AND unit_price >= 0
        """.strip(),
        f"""
        CREATE OR REPLACE TABLE {silver_sales} AS
        SELECT
            sale_id,
            sale_ts,
            customer_id,
            product_id,
            quantity,
            cast(discount_percent AS DECIMAL(5,2)) AS discount_percent
        FROM {bronze_sales}
        WHERE sale_id IS NOT NULL
          AND quantity > 0
          AND discount_percent BETWEEN 0 AND 100
        """.strip(),
    ]


def gold_statements(catalog: str) -> list[str]:
    """Create business-facing Gold dimensions and facts."""

    silver_customers = table(catalog, "silver", "customers")
    silver_products = table(catalog, "silver", "products")
    silver_sales = table(catalog, "silver", "sales")

    dim_customer = table(catalog, "gold", "dim_customer")
    dim_product = table(catalog, "gold", "dim_product")
    fact_sales = table(catalog, "gold", "fact_sales")

    return [
        f"""
        CREATE OR REPLACE TABLE {dim_customer} AS
        SELECT *
        FROM {silver_customers}
        """.strip(),
        f"""
        CREATE OR REPLACE TABLE {dim_product} AS
        SELECT *
        FROM {silver_products}
        """.strip(),
        f"""
        CREATE OR REPLACE TABLE {fact_sales} AS
        SELECT
            s.sale_id,
            s.sale_ts,
            s.customer_id,
            s.product_id,
            s.quantity,
            p.unit_price,
            s.discount_percent,
            cast(
                s.quantity * p.unit_price
                AS DECIMAL(14,2)
            ) AS gross_amount,
            cast(
                s.quantity
                * p.unit_price
                * (1 - s.discount_percent / 100)
                AS DECIMAL(14,2)
            ) AS net_amount
        FROM {silver_sales} AS s
        INNER JOIN {dim_customer} AS c
            ON s.customer_id = c.customer_id
        INNER JOIN {dim_product} AS p
            ON s.product_id = p.product_id
        """.strip(),
    ]


_LAYER_BUILDERS: dict[str, Callable[[str], list[str]]] = {
    "bronze": bronze_statements,
    "silver": silver_statements,
    "gold": gold_statements,
}


def statements_for(layer: str, catalog: str) -> list[str]:
    """Return SQL statements for exactly one pipeline layer."""

    builder = _LAYER_BUILDERS.get(layer)

    if builder is None:
        raise ValueError(
            f"Unsupported layer: {layer}. "
            f"Expected one of: {', '.join(SUPPORTED_LAYERS)}"
        )

    return builder(catalog)
