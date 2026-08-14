# Liquid clustering for CDC tables

> **Status:** design guidance; liquid clustering is not configured by the current pipeline scaffold.

## CDF and liquid clustering

Liquid clustering optimizes the physical layout of a Delta table for data skipping. It is not a CDC mechanism, does not replace a stable key/sequence, and does not make a plain append stream propagate updates or deletes. Normal reclustering/optimization changes file layout rather than the logical business rows that downstream CDC should apply.

Example:

```sql
ALTER TABLE silver.orders
CLUSTER BY (customer_id, country_code, order_date, status);

OPTIMIZE silver.orders;
```

Important key-selection rules:

- Liquid clustering supports up to four clustering keys.
- Keys are specified as columns, not as `ASC`/`DESC` sort expressions.
- Key order does **not** establish a strongest-to-weakest hierarchy. Databricks allows the keys in any order.
- More keys divide clustering across more dimensions. On smaller tables (less than about 10 TB), four keys can perform worse than two when a query filters only one column. This is the effect you were describing, but it is dilution across dimensions—not first-key precedence.
- Choose columns frequently used in selective query filters. If two candidates are highly correlated, keep only one.
- Clustering keys must have Delta statistics. By default, statistics are collected for the first 32 table columns unless configured differently.
- Changing keys affects future clustering decisions; run `OPTIMIZE` to recluster existing data and receive the benefit.
- Prefer `CLUSTER BY AUTO` for supported Unity Catalog managed tables when predictive optimization should adapt keys from observed workloads.

Do not automatically choose four keys merely because four are supported. Start with the smallest set justified by real query filters and validate it using query profiles and data-skipping metrics.


## References

- [Azure Databricks liquid clustering](https://learn.microsoft.com/en-us/azure/databricks/delta/clustering)
- [CDC documentation index](README.md)
