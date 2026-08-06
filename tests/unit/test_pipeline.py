from decimal import Decimal

import pytest

from retail_analytics.pipeline import net_amount, object_name, statements_for


def test_object_name_builds_three_level_identifier() -> None:
    assert object_name("retail_sandbox", "gold", "fact_sales") == (
        "`retail_sandbox`.`gold`.`fact_sales`"
    )


def test_object_name_rejects_injection_or_qualified_input() -> None:
    with pytest.raises(ValueError):
        object_name("retail_sandbox; drop catalog", "gold", "fact_sales")


def test_net_amount_uses_decimal_arithmetic() -> None:
    assert net_amount(3, "9.75", "5") == Decimal("27.7875")


@pytest.mark.parametrize("layer, expected_count", [("bronze", 3), ("silver", 3), ("gold", 3)])
def test_each_layer_has_three_idempotent_statements(layer: str, expected_count: int) -> None:
    statements = statements_for(layer, "retail_sandbox")
    assert len(statements) == expected_count
    assert all("CREATE OR REPLACE TABLE" in statement for statement in statements)


def test_unknown_layer_is_rejected() -> None:
    with pytest.raises(ValueError, match="Unsupported layer"):
        statements_for("platinum", "retail_sandbox")
