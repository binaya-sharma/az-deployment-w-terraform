"""SQL definitions for a small, deterministic medallion pipeline."""

import re
from decimal import Decimal

_IDENTIFIER = re.compile(r"^[a-z][a-z0-9_]*$")


def object_name(catalog: str, schema: str, table: str) -> str:
    """Return a validated three-level Unity Catalog object name."""
    parts = (catalog, schema, table)
    if not all(_IDENTIFIER.fullmatch(part) for part in parts):
        raise ValueError("Catalog, schema, and table names must be lowercase SQL identifiers")
    return ".".join(f"`{part}`" for part in parts)


def net_amount(quantity: int, unit_price: str, discount_percent: str) -> Decimal:
    """Calculate a deterministic expected net amount for unit tests."""
    gross = Decimal(quantity) * Decimal(unit_price)
    return gross * (Decimal("1") - Decimal(discount_percent) / Decimal("100"))


def bronze_statements(catalog: str) -> list[str]:
    customers = object_name(catalog, "bronze", "customers")
    products = object_name(catalog, "bronze", "products")
    sales = object_name(catalog, "bronze", "sales")
    return [
        f"""CREATE OR REPLACE TABLE {customers} AS
            SELECT * FROM VALUES
              ('C001', '  Asha Sharma ', 'Kathmandu', 'gold'),
              ('C002', 'Bikash Rai', 'Pokhara', 'silver'),
              ('C003', 'Mina Thapa', 'Lalitpur', NULL)
            AS source(customer_id, customer_name, city, loyalty_tier)""",
        f"""CREATE OR REPLACE TABLE {products} AS
            SELECT * FROM VALUES
              ('P001', 'Coffee Beans', 'grocery', 12.50),
              ('P002', 'Travel Mug', 'home', 18.00),
              ('P003', 'Tea Selection', 'grocery', 9.75)
            AS source(product_id, product_name, category, unit_price)""",
        f"""CREATE OR REPLACE TABLE {sales} AS
            SELECT * FROM VALUES
              ('S001', timestamp('2026-08-01 10:00:00'), 'C001', 'P001', 2, 10.0),
              ('S002', timestamp('2026-08-01 11:30:00'), 'C002', 'P002', 1, 0.0),
              ('S003', timestamp('2026-08-02 09:15:00'), 'C001', 'P003', 3, 5.0)
            AS source(sale_id, sale_ts, customer_id, product_id, quantity, discount_percent)""",
    ]


def silver_statements(catalog: str) -> list[str]:
    bronze_customers = object_name(catalog, "bronze", "customers")
    bronze_products = object_name(catalog, "bronze", "products")
    bronze_sales = object_name(catalog, "bronze", "sales")
    silver_customers = object_name(catalog, "silver", "customers")
    silver_products = object_name(catalog, "silver", "products")
    silver_sales = object_name(catalog, "silver", "sales")
    return [
        f"""CREATE OR REPLACE TABLE {silver_customers} AS
            SELECT customer_id, trim(customer_name) AS customer_name,
                   initcap(trim(city)) AS city,
                   coalesce(lower(loyalty_tier), 'standard') AS loyalty_tier
            FROM {bronze_customers}
            WHERE customer_id IS NOT NULL""",
        f"""CREATE OR REPLACE TABLE {silver_products} AS
            SELECT product_id, trim(product_name) AS product_name,
                   lower(category) AS category, cast(unit_price AS DECIMAL(12,2)) AS unit_price
            FROM {bronze_products}
            WHERE product_id IS NOT NULL AND unit_price >= 0""",
        f"""CREATE OR REPLACE TABLE {silver_sales} AS
            SELECT sale_id, sale_ts, customer_id, product_id, quantity,
                   cast(discount_percent AS DECIMAL(5,2)) AS discount_percent
            FROM {bronze_sales}
            WHERE sale_id IS NOT NULL AND quantity > 0
              AND discount_percent BETWEEN 0 AND 100""",
    ]


def gold_statements(catalog: str) -> list[str]:
    customers = object_name(catalog, "silver", "customers")
    products = object_name(catalog, "silver", "products")
    sales = object_name(catalog, "silver", "sales")
    dim_customer = object_name(catalog, "gold", "dim_customer")
    dim_product = object_name(catalog, "gold", "dim_product")
    fact_sales = object_name(catalog, "gold", "fact_sales")
    return [
        f"CREATE OR REPLACE TABLE {dim_customer} AS SELECT * FROM {customers}",
        f"CREATE OR REPLACE TABLE {dim_product} AS SELECT * FROM {products}",
        f"""CREATE OR REPLACE TABLE {fact_sales} AS
            SELECT s.sale_id, s.sale_ts, s.customer_id, s.product_id, s.quantity,
                   p.unit_price, s.discount_percent,
                   cast(s.quantity * p.unit_price AS DECIMAL(14,2)) AS gross_amount,
                   cast(s.quantity * p.unit_price * (1 - s.discount_percent / 100)
                        AS DECIMAL(14,2)) AS net_amount
            FROM {sales} s
            INNER JOIN {dim_customer} c ON s.customer_id = c.customer_id
            INNER JOIN {dim_product} p ON s.product_id = p.product_id""",
    ]


def statements_for(layer: str, catalog: str) -> list[str]:
    """Return statements for exactly one pipeline layer."""
    builders = {
        "bronze": bronze_statements,
        "silver": silver_statements,
        "gold": gold_statements,
    }
    try:
        return builders[layer](catalog)
    except KeyError as exc:
        raise ValueError(f"Unsupported layer: {layer}") from exc
