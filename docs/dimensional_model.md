# Dimensional Model

## Overview

The dimensional model provides a trip-level star schema for detailed mobility,
financial, operational, and data-quality analysis.

The model is stored in the PostgreSQL `marts` schema and is sourced from the
validated `staging.taxi_trips` view and the raw ingestion audit table.

The implementation preserves the complete staging population instead of
applying the analytical-period filters used by the daily and hourly analytical
views.

---

## Source Objects

The dimensional model depends on:

- `raw.ingestion_log`
- `staging.taxi_trips`

It does not replace or modify:

- `raw.taxi_trips`
- `staging.taxi_trips`
- `analytics.daily_trip_metrics`
- `analytics.hourly_trip_metrics`
- `marts.daily_mobility_summary`
- `marts.hourly_demand_profile`

---

## Dimensional Architecture

```text
raw.ingestion_log
        |
        v
marts.dim_ingestion

staging.taxi_trips
        |
        +--------------------+
        |                    |
        v                    v
categorical dimensions   date and hour dimensions
        |                    |
        +----------+---------+
                   |
                   v
            marts.fact_trip
```

The model uses a star-schema design with role-playing date and hour
dimensions.

---

## Model Grain

The grain of `marts.fact_trip` is:

> One row per `raw_trip_id`.

Validation confirmed:

- 3,480,226 staging rows.
- 3,480,226 fact rows.
- 3,480,226 distinct `raw_trip_id` values.
- 0 duplicated fact identifiers.
- 0 missing fact identifiers.
- 0 additional fact identifiers.

`raw_trip_id` is used as the fact-table primary key because it is globally
unique across the currently loaded ingestions.

`ingestion_id` remains in the fact table for lineage, auditability, and
separation between the development sample and the complete monthly ingestion.

---

## Dimensional Objects

The dimensional model contains:

- `marts.dim_ingestion`
- `marts.dim_date`
- `marts.dim_hour`
- `marts.dim_vendor`
- `marts.dim_rate_code`
- `marts.dim_payment_type`
- `marts.dim_store_and_fwd`
- `marts.fact_trip`

All objects are physical PostgreSQL tables.

---

# Dimensions

## `marts.dim_ingestion`

### Grain

One row per ingestion audit record.

### Key

- `ingestion_id`

The source identity from `raw.ingestion_log` is reused directly.

### Attributes

- Source file name.
- Taxi type.
- Source period.
- File size.
- Ingestion status.
- Read, loaded, and rejected row counts.
- Start and completion timestamps.
- Error message.

### Current Row Count

6 rows.

The dimension includes both completed and skipped ingestion attempts.

Only completed ingestions 1 and 7 currently have corresponding rows in
`marts.fact_trip`.

---

## `marts.dim_date`

### Grain

One row per calendar date.

### Key

- `date_key`

The key uses the `YYYYMMDD` integer format.

Example:

```text
20250131
```

### Role-Playing Relationships

The same dimension is referenced as:

- Pickup date.
- Drop-off date.

### Attributes

- Full date.
- Calendar year.
- Calendar quarter.
- Month number.
- English month name.
- Day of month.
- ISO day of week.
- English day name.
- ISO week.
- Weekend indicator.

### Current Coverage

- Minimum date: 2024-12-18.
- Maximum date: 2025-02-01.
- Row count: 46.
- Missing staging dates: 0.

The date range covers both pickup and drop-off timestamps.

The minimum date is retained even though it originates from an anomalous
drop-off timestamp. The dimensional layer does not silently correct source
values.

---

## `marts.dim_hour`

### Grain

One row per hour of day.

### Key

- `hour_key`

Valid keys range from 0 through 23.

### Role-Playing Relationships

The same dimension is referenced as:

- Pickup hour.
- Drop-off hour.

### Attributes

- Hour label.
- Day period.

### Day Period Classification

- Hours 00 through 05: `Night`.
- Hours 06 through 11: `Morning`.
- Hours 12 through 17: `Afternoon`.
- Hours 18 through 23: `Evening`.

### Current Row Count

24 rows, with no missing hours.

---

## `marts.dim_vendor`

### Grain

One row per vendor code.

### Keys

- Surrogate key: `vendor_key`.
- Source code: `vendor_id`.

### Attributes

- Vendor name.
- Unrecognized-code indicator.

### Current Row Count

4 rows.

The currently represented vendors are:

- Creative Mobile Technologies, LLC.
- Curb Mobility, LLC.
- Myle Technologies Inc.
- Helix.

---

## `marts.dim_rate_code`

### Grain

One row per rate-code state.

### Keys

- Surrogate key: `rate_code_key`.
- Source code: `ratecode_id`.

### Attributes

- Rate-code description.
- Unrecognized-code indicator.
- Documented-unknown indicator.
- Missing-value indicator.

### Current Row Count

8 rows.

The model distinguishes between:

- Standard documented rate codes.
- Source code `99`, described as `Unknown`.
- A missing source rate code represented as `Missing`.

A documented unknown value is not treated as equivalent to a missing value.

---

## `marts.dim_payment_type`

### Grain

One row per payment-type code.

### Keys

- Surrogate key: `payment_type_key`.
- Source code: `payment_type`.

### Attributes

- Payment-type description.
- Unrecognized-code indicator.
- Documented-unknown indicator.

### Current Row Count

6 rows.

The model preserves:

- Payment type `0` as `Flex Fare trip`.
- Payment type `5` as the documented `Unknown` value.

---

## `marts.dim_store_and_fwd`

### Grain

One row per store-and-forward state.

### Keys

- Surrogate key: `store_and_fwd_key`.
- Source value: `store_and_fwd_flag`.

### Attributes

- Store-and-forward description.
- Unrecognized-value indicator.
- Missing-value indicator.

### Current Row Count

3 rows.

The represented states are:

- `N`: not a store-and-forward trip.
- `Y`: store-and-forward trip.
- Missing source value represented as `Missing`.

---

# Fact Table

## `marts.fact_trip`

### Grain

One row per `raw_trip_id`.

### Primary Key

- `raw_trip_id`

### Foreign Keys

- `ingestion_id`
- `pickup_date_key`
- `dropoff_date_key`
- `pickup_hour_key`
- `dropoff_hour_key`
- `vendor_key`
- `rate_code_key`
- `payment_type_key`
- `store_and_fwd_key`

All foreign-key relationships are enforced by PostgreSQL constraints.

Validation found zero orphaned keys.

### Operational Attributes

The fact table preserves:

- Pickup timestamp.
- Drop-off timestamp.
- Pickup Location ID.
- Drop-off Location ID.
- Load timestamp.

The full timestamps are retained even though date and hour keys are also
available. This preserves detailed event timing while supporting dimensional
aggregation.

### Trip Measures

- Passenger count.
- Trip distance.
- Trip duration in minutes.
- Average speed in miles per hour.

### Monetary Measures

- Fare amount.
- Extra amount.
- MTA tax.
- Tip amount.
- Tolls amount.
- Improvement surcharge.
- Total amount.
- Congestion surcharge.
- Airport fee.
- CBD congestion fee.

All monetary columns retain the staging `NUMERIC(12, 2)` representation.

### Data-Quality Flags

The fact table preserves all detailed and aggregate staging flags:

- Missing datetime.
- Nonpositive duration.
- Duration over 24 hours.
- Negative distance.
- Zero distance.
- Pickup outside the expected period.
- Missing trip attributes.
- Negative fare.
- Negative total amount.
- Negative transaction.
- Unrecognized vendor.
- Unrecognized rate code.
- Unrecognized payment type.
- Unrecognized store-and-forward value.
- Documented unknown rate code.
- Documented unknown payment type.
- Operational issue.
- Suspicious condition.
- Any quality flag.
- Valid for speed analysis.

No quality flag causes automatic removal from the dimensional model.

---

# Data Population

## Current Counts

| Object | Row Count |
|---|---:|
| `marts.dim_ingestion` | 6 |
| `marts.dim_date` | 46 |
| `marts.dim_hour` | 24 |
| `marts.dim_vendor` | 4 |
| `marts.dim_rate_code` | 8 |
| `marts.dim_payment_type` | 6 |
| `marts.dim_store_and_fwd` | 3 |
| `marts.fact_trip` | 3,480,226 |

## Fact Rows by Ingestion

| Ingestion | Rows |
|---:|---:|
| 1 | 5,000 |
| 7 | 3,475,226 |

The four skipped ingestion records remain in `dim_ingestion`, but they do not
have fact rows.

---

# Relationship with Analytical Models

The dimensional fact table and the existing analytics models serve different
purposes.

`marts.fact_trip` preserves all staging rows.

For ingestion 7 it contains:

- 3,475,226 trips.
- Net `total_amount` of 89,005,026.80.

The monthly analytical views exclude records with pickup timestamps outside
the expected source period.

For ingestion 7 they represent:

- 3,475,204 trips.
- Net `total_amount` of 89,004,415.50.

The difference consists of the 22 trips whose pickup timestamps are outside
the expected January 2025 period.

This is intentional and is not a reconciliation error.

Following query optimization, `marts.daily_mobility_summary` and
`marts.hourly_demand_profile` aggregate directly from `marts.fact_trip` and
the supporting dimensions. They apply the same analytical eligibility rule by
excluding `is_pickup_outside_expected_period` rows.

The staging-based `analytics.daily_trip_metrics` and
`analytics.hourly_trip_metrics` views remain unchanged and serve as independent
references for reconciliation of the optimized marts.

---

# Missing, Unknown, and Unrecognized Values

The model keeps these states separate.

## Missing

The original source value is null or absent.

Examples:

- Missing rate code.
- Missing store-and-forward flag.

## Documented Unknown

The source provides a documented code whose defined meaning is `Unknown`.

Examples:

- Rate code `99`.
- Payment type `5`.

## Unrecognized

The source code is not included in the implemented mapping.

The model preserves the source code and the corresponding
`is_unrecognized_*` flag rather than replacing it silently.

---

# Taxi Zone Handling

`pickup_location_id` and `dropoff_location_id` are retained directly in
`marts.fact_trip`.

A Taxi Zone dimension was not created because the official Taxi Zone lookup
file is not currently present in the repository or local data directories.

The observed location identifiers:

- Are non-null.
- Are positive.
- Range from 1 through 265.
- Have not been validated against the official reference dataset.

Borough, zone name, and service-zone attributes must not be inferred without
the official lookup file.

---

# Load Process

The dimensional implementation is versioned in:

- `sql/dimensional/01_create_dimensional_tables.sql`
- `sql/dimensional/02_load_dimensions.sql`
- `sql/dimensional/03_load_fact_trip.sql`
- `sql/dimensional/04_validate_dimensional_model.sql`

## Execution Order

```powershell
Get-Content -Raw .\sql\dimensional\01_create_dimensional_tables.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\dimensional\02_load_dimensions.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\dimensional\03_load_fact_trip.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\dimensional\04_validate_dimensional_model.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -P pager=off `
        -U mobility_user `
        -d mobility_db
```

---

# Reexecution

The DDL uses `CREATE TABLE IF NOT EXISTS`.

The dimension and fact loads use `INSERT ... ON CONFLICT DO UPDATE`.

Validated reexecution:

- Did not create duplicate dimension members.
- Did not create duplicate fact rows.
- Preserved all object counts.
- Completed with successful transactions.

Surrogate key values have no business meaning. Their exact numeric assignments
may differ after a clean database rebuild because they are identity values.

The load scripts preserve existing surrogate keys when a source code already
exists.

The current upsert process does not delete dimensional or fact rows that are
removed from upstream sources. This is acceptable for the current
source-preserving and append-oriented pipeline, but it is not a general
deletion-synchronization mechanism.

`CREATE TABLE IF NOT EXISTS` also does not perform schema migrations when an
existing table definition changes.

---

# Validation

The validation script checks:

- Object row counts.
- Fact-table grain.
- Duplicate fact identifiers.
- Row-count reconciliation by ingestion.
- Missing and additional fact records.
- Foreign-key orphans.
- Ingestion audit reconciliation.
- Date-key correctness and date coverage.
- Hour coverage.
- Categorical-dimension reconciliation.
- Foreign-key derivation.
- Operational-column preservation.
- Measure preservation.
- Monetary preservation.
- Quality-flag preservation.
- Aggregate monetary reconciliation.

Validated results:

- Duplicate fact identifiers: 0.
- Missing fact records: 0.
- Additional fact records: 0.
- Foreign-key orphans: 0.
- Categorical differences: 0.
- Foreign-key derivation mismatches: 0.
- Operational and measure mismatches: 0.
- Monetary mismatches: 0.
- Quality-flag mismatches: 0.
- Aggregate monetary differences: 0.00.

---

# Known Limitations

- The model currently covers one development sample and one complete monthly
  ingestion.
- January 2025 is the only complete monthly source ingestion validated.
- Taxi Zone identifiers have not been validated against the official lookup.
- No Taxi Zone dimension is implemented.
- The selective `marts.fact_trip(ingestion_id)` index has been evaluated and
  versioned; broader surrogate-key and foreign-key indexing has not been
  exhaustively evaluated.
- Query performance has been measured with
  `EXPLAIN (ANALYZE, BUFFERS, SETTINGS, SUMMARY)`.
- No materialized analytical layer has been introduced.
- No slowly changing dimension Type 2 behavior is implemented.
- No automated Python test suite currently executes the dimensional checks.
- The load process performs upserts but does not delete obsolete target rows.

The completed query-optimization work, including index selection, execution
plans, performance measurements, architectural decisions, and validation
results, is documented in `docs/query_optimization.md`.

---

# Downstream Use

The model is prepared for:

- Detailed trip analysis.
- Dimensional SQL queries.
- Power BI star-schema relationships.
- Filtering by ingestion.
- Pickup and drop-off date analysis.
- Pickup and drop-off hour analysis.
- Vendor, rate-code, payment, and store-and-forward analysis.
- Financial analysis.
- Operational-quality analysis.

Consumers must filter by the intended `ingestion_id` unless combining
ingestions is an explicit analytical requirement.

For the complete January 2025 source population:

```sql
WHERE ingestion_id = 7
```

To reproduce the filtered analytical January population:

```sql
WHERE ingestion_id = 7
  AND NOT is_pickup_outside_expected_period
```



