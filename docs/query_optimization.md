# Query Optimization

## Purpose

This document records the query-performance analysis and physical optimization
work performed after completion of the dimensional model.

The optimization focused on the PostgreSQL analytical consumption path without
changing the validated business logic, analytical grain, eligibility rules, or
public columns of the existing daily and hourly mart views.

---

## Scope

The work evaluated:

- PostgreSQL execution plans.
- Sequential and index scans.
- Cardinality estimates.
- Buffer usage.
- JIT compilation.
- Selectivity of `ingestion_id`.
- Physical indexing of `marts.fact_trip`.
- The execution path of the daily and hourly analytical marts.
- Functional equivalence before and after optimization.

The following roadmap items remain outside this work:

- Automated tests.
- Power BI dashboard.
- Continuous integration.

---

## Objects Evaluated

The main objects evaluated were:

- `raw.taxi_trips`
- `staging.taxi_trips`
- `analytics.daily_trip_metrics`
- `analytics.hourly_trip_metrics`
- `marts.fact_trip`
- `marts.daily_mobility_summary`
- `marts.hourly_demand_profile`

The dimensional fact table contains 3,480,226 rows.

For ingestion 7:

- Fact rows: 3,475,226.
- Analytically eligible rows: 3,475,204.
- Rows outside the expected January 2025 period: 22.

---

## Initial Architecture

Before optimization, the final analytical path was:

```text
raw.taxi_trips
        |
        v
staging.taxi_trips
        |
        v
analytics.daily/hourly
        |
        v
marts summary views
```

`staging.taxi_trips` is a normal PostgreSQL view. Several calculated measures,
categorical descriptions, and quality flags are therefore evaluated when
queries execute.

The daily and hourly analytics views then aggregate those expressions, and the
summary marts perform additional aggregation or window calculations.

For the large ingestion, PostgreSQL had to scan approximately 3.48 million raw
trip rows before producing the small daily or hourly outputs.

---

## Baseline Performance

Performance was measured with:

```sql
EXPLAIN (ANALYZE, BUFFERS, SETTINGS, SUMMARY)
```

### Daily Mart

Query:

```sql
SELECT *
FROM marts.daily_mobility_summary
WHERE ingestion_id = 7
ORDER BY pickup_date;
```

Measured executions:

| Run | Execution Time |
|---:|---:|
| 1 | 11,046.066 ms |
| 2 | 10,814.904 ms |
| Average | 10,930.485 ms |

### Hourly Mart

Query:

```sql
SELECT *
FROM marts.hourly_demand_profile
WHERE ingestion_id = 7
ORDER BY pickup_hour;
```

Measured executions:

| Run | Execution Time |
|---:|---:|
| 1 | 9,521.399 ms |
| 2 | 9,764.991 ms |
| Average | 9,643.195 ms |

The dominant cost was the repeated evaluation and aggregation of the
staging-based path rather than the final window functions.

---

## JIT Evaluation

PostgreSQL JIT was enabled with the default configuration.

A controlled hourly test using:

```sql
SET LOCAL jit = off;
```

completed in 11,911.974 ms.

This was slower than the JIT-enabled baseline, so JIT remained enabled.

---

## Fact-Table Index Evaluation

Before optimization, `marts.fact_trip` only had its primary-key index on
`raw_trip_id`.

A selective query for the small ingestion used a parallel sequential scan even
though only 5,000 rows were required.

Baseline execution time:

```text
237.499 ms
```

The following index was created:

```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS
    idx_fact_trip_ingestion_id
ON marts.fact_trip (ingestion_id);
```

After index creation, the same selective ingestion query used:

```text
Index Scan using idx_fact_trip_ingestion_id
```

Execution time:

```text
6.156 ms
```

This represents approximately:

- 97.4% lower execution time.
- 38.6x acceleration.

For ingestion 7, which represents almost the entire fact table, PostgreSQL
continued to choose a sequential scan. This is appropriate because an index is
not selective when nearly every row must be read.

The planner therefore demonstrated the desired behavior:

- Selective ingestion: index scan.
- Nonselective ingestion: sequential scan.

---

## Architectural Decision

A fact-table prototype of the analytical aggregations was substantially faster
than repeatedly calculating the staging-based path.

However, changing the `analytics` views to depend on `marts.fact_trip` would
invert the existing analytical-layer dependency and make the `analytics` schema
depend on the downstream `marts` schema.

That design was rejected.

The selected architecture is:

```text
staging.taxi_trips
        |
        +-----------------------------+
        |                             |
        v                             v
analytics.daily/hourly           marts.fact_trip
        |                             |
        | validation reference        | optimized source
        |                             |
        +-------------------+---------+
                            |
                            v
                  marts summary views
```

The resulting responsibilities are:

### Analytics Layer

`analytics.daily_trip_metrics` and `analytics.hourly_trip_metrics`:

- Remain unchanged.
- Continue to depend on `staging.taxi_trips`.
- Preserve the original analytical implementation.
- Provide independent reconciliation references.

### Optimized Marts Layer

`marts.daily_mobility_summary` and `marts.hourly_demand_profile`:

- Preserve their existing grains and output columns.
- Aggregate directly from the physical fact table and dimensions.
- Apply the same completed-ingestion and expected-period eligibility rules.
- Continue to provide the same analytical results.
- Avoid repeatedly evaluating the full staging view for final consumption.

---

## Versioned Optimization Scripts

### Indexes

File:

`sql/optimization/01_create_query_optimization_indexes.sql`

Creates:

`idx_fact_trip_ingestion_id`

The script uses `CREATE INDEX CONCURRENTLY IF NOT EXISTS`.

`CREATE INDEX CONCURRENTLY` cannot execute inside an explicit PostgreSQL
transaction, so this script intentionally does not use `BEGIN` and `COMMIT`.

The script was reexecuted after the index already existed and PostgreSQL
returned:

```text
NOTICE: relation "idx_fact_trip_ingestion_id" already exists, skipping
```

This confirmed its idempotent behavior.

### Mart View Optimization

File:

`sql/optimization/02_optimize_mart_views.sql`

The script uses one transaction and redefines:

- `marts.daily_mobility_summary`
- `marts.hourly_demand_profile`

The script completed successfully with:

```text
BEGIN
CREATE VIEW
CREATE VIEW
COMMIT
```

---

## Daily Mart Validation

Before changing the production view, the complete optimized daily query was
compared bidirectionally with the existing mart across all represented
ingestions.

Result:

| Comparison | Count |
|---|---:|
| Existing minus optimized | 0 |
| Optimized minus existing | 0 |
| Existing row count | 43 |
| Optimized row count | 43 |

After deployment, the existing validation file was executed:

`sql/marts/02_validate_daily_mobility_summary.sql`

Results included:

- Grain violations: 0.
- Base-metric differences against `analytics.daily_trip_metrics`: 0.
- Window-metric differences: 0.
- Ingestion 1: 12 represented days and 5,000 trips.
- Ingestion 7: 31 represented days and 3,475,204 trips.
- Final ingestion-7 cumulative trip count: 3,475,204.
- Final ingestion-7 cumulative net total amount: 89,004,415.50.

The ingestion-7 rounded period shares sum to 99.9998 because individual shares
are stored after rounding to four decimal places.

---

## Hourly Mart Validation

Before changing the production view, the complete optimized hourly query was
compared bidirectionally with the existing mart across all represented
ingestions.

Result:

| Comparison | Count |
|---|---:|
| Existing minus optimized | 0 |
| Optimized minus existing | 0 |
| Existing row count | 48 |
| Optimized row count | 48 |

After deployment, the existing validation file was executed:

`sql/marts/04_validate_hourly_demand_profile.sql`

Results included:

- Grain violations: 0.
- Base-metric differences against `analytics.hourly_trip_metrics`: 0.
- Derived and window-metric differences: 0.
- Monetary-identity or percentage violations: 0.
- Both represented ingestions contain all 24 hours.
- Ingestion 7 represents 3,475,204 trips.
- Final ingestion-7 cumulative trip count: 3,475,204.
- Ingestion-7 net total amount: 89,004,415.50.
- Highest-demand hour: 18.
- Highest-demand-hour trip count: 267,951.

---

## Final Performance

After deploying the optimized mart definitions, both benchmark queries were
executed twice again.

### Daily Mart

| Run | Baseline | Optimized |
|---:|---:|---:|
| 1 | 11,046.066 ms | 3,333.850 ms |
| 2 | 10,814.904 ms | 3,318.311 ms |
| Average | 10,930.485 ms | 3,326.081 ms |

Result:

- Execution-time reduction: approximately 69.6%.
- Acceleration: approximately 3.29x.

### Hourly Mart

| Run | Baseline | Optimized |
|---:|---:|---:|
| 1 | 9,521.399 ms | 3,144.490 ms |
| 2 | 9,764.991 ms | 3,118.543 ms |
| Average | 9,643.195 ms | 3,131.517 ms |

Result:

- Execution-time reduction: approximately 67.5%.
- Acceleration: approximately 3.08x.

---

## Final Performance Summary

| Object | Baseline Average | Optimized Average | Reduction | Acceleration |
|---|---:|---:|---:|---:|
| Daily mobility summary | 10,930.485 ms | 3,326.081 ms | 69.6% | 3.29x |
| Hourly demand profile | 9,643.195 ms | 3,131.517 ms | 67.5% | 3.08x |

The optimization therefore reduced final mart execution times by roughly two
thirds while preserving exact analytical equivalence.

---

## Deployment Order

For a new environment, the optimization scripts must run only after the
dimensional model and base analytical marts exist.

Required order:

1. Create raw, staging, analytics, and base marts objects.
2. Create and load the dimensional model.
3. Execute `sql/optimization/01_create_query_optimization_indexes.sql`.
4. Execute `sql/optimization/02_optimize_mart_views.sql`.
5. Execute the daily and hourly mart validation scripts.

The original `sql/marts/01_create_daily_mobility_summary.sql` and
`sql/marts/03_create_hourly_demand_profile.sql` remain the base historical
definitions.

Executing those base creation scripts after the optimization override would
restore the previous staging/analytics-based mart definitions. The optimization
override must therefore be the final view-definition step in the current
deployment order.

---

## Reproduction Commands

Create or verify the physical index:

```powershell
Get-Content -Raw `
    .\sql\optimization\01_create_query_optimization_indexes.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db `
        -P pager=off
```

Apply the optimized mart definitions:

```powershell
Get-Content -Raw `
    .\sql\optimization\02_optimize_mart_views.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db `
        -P pager=off
```

Validate the daily mart:

```powershell
Get-Content -Raw `
    .\sql\marts\02_validate_daily_mobility_summary.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db `
        -P pager=off
```

Validate the hourly mart:

```powershell
Get-Content -Raw `
    .\sql\marts\04_validate_hourly_demand_profile.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db `
        -P pager=off
```

---

## Current Status

Query optimization is complete.

The current implementation has:

- A versioned selective fact-table index.
- Optimized daily and hourly mart definitions.
- Exact functional reconciliation against the unchanged analytics layer.
- Measured before-and-after execution plans.
- Reproducible SQL deployment commands.
- Documented performance improvements.

The next roadmap item is `Automated tests`.
