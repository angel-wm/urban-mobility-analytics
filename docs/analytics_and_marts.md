# Analytics and Marts Models

## Purpose

This document describes the analytics-layer and marts-layer models built from
`staging.taxi_trips`.

The models provide reusable daily and hourly mobility metrics while preserving
ingestion-level traceability. They also demonstrate advanced SQL techniques,
including common table expressions, conditional aggregation, window functions,
rolling averages, cumulative metrics, ranking, and reconciliation across data
layers.

The implementation does not modify or remove records from the raw or staging
layers.

---

## Data Flow

```text
raw.taxi_trips
        |
        v
staging.taxi_trips
        |
        +------------------------------+
        |                              |
        v                              v
analytics.daily_trip_metrics   analytics.hourly_trip_metrics
        |                              |
        v                              v
marts.daily_mobility_summary   marts.hourly_demand_profile
```

---

## Source Model

All analytics and mart models ultimately depend on:

`staging.taxi_trips`

The staging view provides:

- Ingestion metadata.
- Original categorical codes.
- Human-readable categorical descriptions.
- Standardized monetary values.
- Pickup date and hour.
- Trip duration.
- Average speed.
- Detailed data-quality flags.
- Consolidated data-quality flags.

The source grain is one row per `raw_trip_id`.

---

## Common Eligibility Rules

Both analytics models use the following eligibility rules:

- `ingestion_status = 'completed'`
- `pickup_date IS NOT NULL`
- `is_pickup_outside_expected_period = FALSE`

The hourly model additionally requires:

- `pickup_hour IS NOT NULL`

These rules ensure that each output row can be assigned to the expected
calendar period and analytical grain.

The models do not apply a blanket exclusion based on
`has_any_quality_flag`.

Negative transactions remain part of net monetary metrics. Positive and
negative amounts are also exposed separately.

---

# Analytics Layer

## `analytics.daily_trip_metrics`

### Object Type

PostgreSQL view.

### Definition File

`sql/analytics/01_create_daily_trip_metrics.sql`

### Validation File

`sql/analytics/02_validate_daily_trip_metrics.sql`

### Grain

One row per:

- `ingestion_id`
- `pickup_date`

The ingestion identifier is part of the grain to prevent a development sample
and a complete monthly ingestion from being combined.

### Purpose

The view provides reusable daily mobility, financial, operational, and
data-quality metrics.

### Dimensions and Traceability

- `ingestion_id`
- `source_file_name`
- `taxi_type`
- `period_year`
- `period_month`
- `pickup_date`

### Count Metrics

- `trip_count`
- `operational_issue_trip_count`
- `suspicious_condition_trip_count`
- `any_quality_flag_trip_count`
- `negative_transaction_trip_count`
- `valid_speed_trip_count`

### Distance, Duration, and Speed Metrics

- `total_trip_distance`
- `average_trip_distance`
- `average_trip_duration_minutes`
- `average_speed_mph`

Negative distances are excluded from distance aggregates.

Average duration excludes operational issues and durations greater than 24
hours.

Average speed uses only records where
`is_valid_for_speed_analysis = TRUE`.

### Monetary Metrics

- `positive_total_amount`
- `negative_total_amount`
- `net_total_amount`
- `average_total_amount`

The following identity must hold at the daily grain:

```text
positive_total_amount
+ negative_total_amount
= net_total_amount
```

`negative_total_amount` remains negative.

### SQL Techniques

- Common table expressions.
- Conditional aggregation with `FILTER`.
- `COUNT`, `SUM`, and `AVG`.
- Explicit numeric casting.
- Reusable ingestion-aware grouping.

### January 2025 Validation

For `ingestion_id = 7`:

- Represented dates: 31.
- Represented trips: 3,475,204.
- First date: January 1, 2025.
- Last date: January 31, 2025.
- Positive total amount: 90,661,905.07.
- Negative total amount: -1,657,489.57.
- Net total amount: 89,004,415.50.

The complete ingestion contains 3,475,226 rows. The analytics model represents
3,475,204 rows because 22 trips have pickup timestamps outside the expected
monthly period.

### Validation Results

The validation confirmed:

- One row per ingestion and pickup date.
- No grain violations.
- Exact reconciliation of counts against staging.
- Exact reconciliation of monetary metrics against staging.
- No monetary identity violations.
- No output dates outside the expected period.

---

## `analytics.hourly_trip_metrics`

### Object Type

PostgreSQL view.

### Definition File

`sql/analytics/03_create_hourly_trip_metrics.sql`

### Validation File

`sql/analytics/04_validate_hourly_trip_metrics.sql`

### Grain

One row per:

- `ingestion_id`
- `pickup_date`
- `pickup_hour`

### Purpose

The view provides date-hour mobility metrics that can be aggregated into
hourly demand profiles or consumed directly for detailed time-series analysis.

### Dimensions and Traceability

- `ingestion_id`
- `source_file_name`
- `taxi_type`
- `period_year`
- `period_month`
- `pickup_date`
- `pickup_hour`

### Metrics

The hourly view exposes the same metric categories as the daily analytics
view:

- Trip counts.
- Quality-condition counts.
- Valid-speed counts.
- Distance metrics.
- Duration metrics.
- Speed metrics.
- Positive, negative, net, and average total amounts.

### SQL Techniques

- Common table expressions.
- Conditional aggregation with `FILTER`.
- Multi-column analytical grain.
- Explicit numeric casting.
- Reconciliation between hourly and daily grains.

### January 2025 Validation

For `ingestion_id = 7`:

- Represented date-hour combinations: 744.
- Represented dates: 31.
- Represented hours: 24.
- Represented trips: 3,475,204.
- First hour: 0.
- Last hour: 23.

The 744 rows correspond to:

```text
31 dates × 24 hours = 744 date-hour combinations
```

### Validation Results

The validation confirmed:

- One row per ingestion, date, and hour.
- No grain violations.
- Exact reconciliation against staging.
- Exact reconciliation against the daily analytics layer when hourly rows are
  aggregated by date.
- No invalid hours.
- No dates outside the expected period.

---

# Marts Layer

## `marts.daily_mobility_summary`

### Object Type

PostgreSQL view.

### Definition File

`sql/marts/01_create_daily_mobility_summary.sql`

### Validation File

`sql/marts/02_validate_daily_mobility_summary.sql`

### Grain

One row per:

- `ingestion_id`
- `pickup_date`

### Source

`analytics.daily_trip_metrics`

### Purpose

The mart enriches the daily analytical metrics with time-series indicators
suitable for reporting and dashboard consumption.

### Window Metrics

#### Previous-Day Demand

`previous_day_trip_count`

Calculated with `LAG`.

#### Daily Absolute Change

`daily_trip_count_change`

Calculated as:

```text
trip_count - previous_day_trip_count
```

#### Daily Percentage Change

`daily_trip_count_change_percentage`

The first represented date returns `NULL` because no previous day exists.

#### Cumulative Trips

`cumulative_trip_count`

Calculated with an ordered cumulative `SUM`.

#### Cumulative Net Amount

`cumulative_net_total_amount`

Calculated with an ordered cumulative `SUM`.

#### Seven-Day Rolling Average

`rolling_7_day_average_trip_count`

Calculated with:

```sql
ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
```

The first six dates use a progressively growing window. Starting with the
seventh date, the metric uses seven rows.

#### Demand Ranking

`trip_demand_rank`

Calculated with `RANK`, ordered by descending daily trip count.

#### Period Share

`period_trip_share_percentage`

Represents each date's percentage of the ingestion-level trip count.

### January 2025 Validation

For `ingestion_id = 7`:

- Represented dates: 31.
- Represented trips: 3,475,204.
- Final cumulative trip count: 3,475,204.
- Final cumulative net total amount: 89,004,415.50.
- Best demand rank: 1.
- Lowest demand rank: 31.

The sum of individually rounded daily period shares is 99.9998 percent. This
minor difference from 100 percent is caused by rounding each daily
participation to four decimal places.

### Validation Results

The validation confirmed:

- No grain violations.
- Exact reconciliation against `analytics.daily_trip_metrics`.
- No differences in recalculated window functions.
- Correct final cumulative totals.
- Correct handling of the first row in previous-day comparisons.

---

## `marts.hourly_demand_profile`

### Object Type

PostgreSQL view.

### Definition File

`sql/marts/03_create_hourly_demand_profile.sql`

### Validation File

`sql/marts/04_validate_hourly_demand_profile.sql`

### Grain

One row per:

- `ingestion_id`
- `pickup_hour`

### Source

`analytics.hourly_trip_metrics`

### Purpose

The mart summarizes the demand and quality behavior of each hour across all
represented dates within an ingestion.

### Base Metrics

- `represented_day_count`
- `trip_count`
- `average_daily_trip_count`
- Quality-condition counts.
- Quality-condition percentages.
- Positive total amount.
- Negative total amount.
- Net total amount.
- Average net total amount per trip.

### Window Metrics

#### Previous-Hour Demand

`previous_hour_trip_count`

Calculated with `LAG`, ordered from hour 0 through hour 23.

This comparison is linear and does not treat hour 0 as following hour 23.

#### Hourly Absolute Change

`hourly_trip_count_change`

#### Hourly Percentage Change

`hourly_trip_count_change_percentage`

Hour 0 returns `NULL` because no previous hour exists in the ordered
partition.

#### Cumulative Demand

`cumulative_trip_count`

Calculated from hour 0 through the current hour.

#### Three-Hour Rolling Average

`rolling_3_hour_average_trip_count`

Calculated with:

```sql
ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
```

#### Demand Ranking

`demand_rank`

Calculated with `RANK`, ordered by descending hourly trip count.

#### Period Share

`period_trip_share_percentage`

Represents each hour's share of all trips in the ingestion.

### January 2025 Validation

For `ingestion_id = 7`:

- Represented hours: 24.
- Represented trips: 3,475,204.
- First hour: 0.
- Last hour: 23.
- Final cumulative trip count: 3,475,204.
- Net total amount: 89,004,415.50.
- Highest-demand hour: 18.
- Trips during the highest-demand hour: 267,951.
- Rounded period shares: 100.0000 percent.

### Validation Results

The validation confirmed:

- One row per ingestion and pickup hour.
- No grain violations.
- Exact reconciliation against `analytics.hourly_trip_metrics`.
- No differences in recalculated derived metrics.
- No differences in recalculated window functions.
- Valid monetary identities.
- Percentages within the expected range of 0 to 100.
- Correct cumulative totals and rankings.

---

# Deployment Order

The models must be created in dependency order:

```powershell
Get-Content -Raw .\sql\analytics\01_create_daily_trip_metrics.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\analytics\03_create_hourly_trip_metrics.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\marts\01_create_daily_mobility_summary.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\marts\03_create_hourly_demand_profile.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db
```

The validation scripts should then be executed:

```powershell
Get-Content -Raw .\sql\analytics\02_validate_daily_trip_metrics.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\analytics\04_validate_hourly_trip_metrics.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\marts\02_validate_daily_mobility_summary.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\marts\04_validate_hourly_demand_profile.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db
```

---

# Reexecution

All four objects use `CREATE OR REPLACE VIEW`.

The scripts can be reexecuted safely while the existing view column interfaces
remain compatible with PostgreSQL replacement rules.

No script:

- Drops raw data.
- Drops staging data.
- Uses `CASCADE`.
- Deletes source records.
- Materializes duplicate copies of the source dataset.

---

# Known Limitations

- The models are normal views and have no indexes of their own.
- Query performance has not yet been evaluated with `EXPLAIN ANALYZE`.
- January 2025 is the only complete monthly ingestion currently validated.
- The development sample remains visible as a separate ingestion.
- The models do not validate pickup or dropoff locations against an official
  Taxi Zone dimension.
- The models do not implement a mutually exclusive quality classification.
- The models do not automatically remove every trip with a quality flag.
- Exploratory distance, amount, and speed thresholds have not been formalized
  as downstream filters.
- Rankings and rolling calculations operate only on represented rows.
- The hourly previous-value comparison is linear from hour 0 to hour 23 and is
  not circular.

---

# Downstream Use

The models are prepared for use by:

- Advanced SQL analysis.
- Operational and quality reporting.
- Python exploratory analysis.
- Power BI dashboards.
- Daily mobility trend analysis.
- Hourly demand analysis.
- Revenue and adjustment analysis.
- Future dimensional models.

Consumers must filter by the intended `ingestion_id` unless combining
ingestions is an explicit analytical requirement.

For the complete January 2025 Yellow Taxi dataset, use:

```sql
WHERE ingestion_id = 7
```