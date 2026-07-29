# Raw Data SQL Profile

## Purpose

This document summarizes the SQL profiling performed on the January 2025 NYC TLC Yellow Taxi data stored in `raw.taxi_trips`.

The analysis is limited to:

- `ingestion_id = 7`
- Source file: `yellow_tripdata_2025-01.parquet`
- Ingestion status: `completed`
- Expected period: January 2025

The sample ingestion with `ingestion_id = 1` is excluded from the monthly profile.

## Dataset Scope

The completed monthly ingestion contains:

- 3,475,226 rows read from the Parquet file.
- 3,475,226 rows loaded into PostgreSQL.
- 0 technically rejected rows.
- 0 orphan trip rows.
- 0 differences between `rows_loaded` and the physical database row count.

The complete `raw.taxi_trips` table contains 3,480,226 rows because it also includes 5,000 rows from the development sample.

## Ingestion Relationships

The relationship between `raw.taxi_trips` and `raw.ingestion_log` was validated through `ingestion_id`.

Confirmed results:

- Completed ingestions have matching log and database row counts.
- Skipped ingestions contain no trip rows.
- No trip rows reference a missing ingestion log.
- The January monthly data belongs to ingestion 7.

## Null Patterns

The following columns contain 540,149 null values:

- `passenger_count`
- `ratecode_id`
- `store_and_fwd_flag`

These null values occur in exactly the same rows where:

- `payment_type = 0`

No rows were found where only one of `passenger_count` or `ratecode_id` was null.

`payment_type`, `fare_amount`, `total_amount`, `pickup_datetime`, and `dropoff_datetime` contain no null values.

The meaning of `payment_type = 0` and its relationship with the missing values has not yet been validated against the official NYC TLC data dictionary.

## Category Distributions

### Payment Type

| Payment type | Trip count |
|---:|---:|
| 0 | 540,149 |
| 1 | 2,444,393 |
| 2 | 390,429 |
| 3 | 23,773 |
| 4 | 76,481 |
| 5 | 1 |

### Passenger Count

| Passenger count | Trip count |
|---:|---:|
| 0 | 24,656 |
| 1 | 2,322,434 |
| 2 | 407,761 |
| 3 | 91,409 |
| 4 | 59,009 |
| 5 | 17,786 |
| 6 | 12,004 |
| 7 | 4 |
| 8 | 11 |
| 9 | 3 |
| NULL | 540,149 |

### Rate Code

| Rate code | Trip count |
|---:|---:|
| 1 | 2,756,472 |
| 2 | 94,420 |
| 3 | 8,622 |
| 4 | 7,092 |
| 5 | 26,501 |
| 6 | 7 |
| 99 | 41,963 |
| NULL | 540,149 |

### Vendor

The dataset contains the following `vendor_id` values:

- 1
- 2
- 6
- 7

The least frequent values are:

| Vendor ID | Trip count |
|---:|---:|
| 6 | 489 |
| 7 | 1,206 |

The meanings of vendor IDs 6 and 7 have not yet been validated against the official source documentation.

### Store and Forward Flag

| Value | Trip count |
|---|---:|
| N | 2,927,431 |
| Y | 7,646 |
| NULL | 540,149 |

## Numeric Profile

### Trip Distance

- Minimum: 0
- Maximum: 276,423.57
- Average: approximately 5.8551
- Total: approximately 20,347,886.73
- Zero-distance rows: 90,893
- Rows over 100 distance units: 162
- Rows over 1,000 distance units: 116

The maximum and other very large distances are suspicious and require later quality classification.

### Fare Amount

- Minimum: -900
- Maximum: 863,372.12
- Average: approximately 17.0818
- Negative values: 144,118 rows
- Zero values: 1,398 rows
- Values over 1,000: 3 rows

### Total Amount

- Minimum: -901
- Maximum: 863,380.37
- Average: approximately 25.6113
- Negative values: 63,037 rows
- Zero values: 559 rows
- Values over 1,000: 3 rows

### Relationship Between Fare and Total Amount

The negative-value combinations are:

| Condition | Row count |
|---|---:|
| Negative fare and negative total | 62,716 |
| Negative fare and nonnegative total | 81,402 |
| Nonnegative fare and negative total | 321 |

Negative fares and negative totals therefore do not describe exactly the same records.

## Temporal Profile

### Pickup Range

- Minimum: `2024-12-31 20:47:55`
- Maximum: `2025-02-01 00:00:44`

### Dropoff Range

- Minimum: `2024-12-18 07:52:40`
- Maximum: `2025-02-01 23:44:11`

### Pickup Period Distribution

| Period | Row count |
|---|---:|
| Before January 2025 | 21 |
| During January 2025 | 3,475,204 |
| After January 2025 | 1 |

A total of 22 pickup timestamps fall outside January 2025.

### Duration Conditions

- Nonpositive durations: 2,051 rows.
- Durations over 24 hours: 20 rows.
- Null pickup timestamps: 0.
- Null dropoff timestamps: 0.

At least one extreme record has a dropoff timestamp more than 35 days before its pickup timestamp.

## Consolidated Quality Indicators

| Indicator | Rows | Percentage |
|---|---:|---:|
| `payment_type = 0` | 540,149 | 15.5428% |
| Zero trip distance | 90,893 | 2.6155% |
| Negative fare | 144,118 | 4.1469% |
| Negative total amount | 63,037 | 1.8139% |
| Nonpositive duration | 2,051 | 0.0590% |
| Duration over 24 hours | 20 | 0.0006% |
| Pickup outside January | 22 | 0.0006% |

Percentages are calculated against the 3,475,226 rows belonging to ingestion 7.

## Interpretation Principles

The `raw` layer preserves source records and does not automatically remove analytical anomalies.

The following conditions are therefore documented but not deleted:

- Missing categorical values.
- Zero distances.
- Negative monetary values.
- Nonpositive durations.
- Extremely large distances or amounts.
- Timestamps outside the expected monthly period.
- Rare or undocumented category values.

These findings will inform the design of quality flags and standardized fields in the future `staging` layer.

## Limitations

- The analysis covers only January 2025.
- Category meanings have not yet been validated against the official NYC TLC data dictionary.
- Thresholds such as distance