# Staging Taxi Trips Model

## Purpose

This document describes the staging model created from the NYC TLC Yellow Taxi
trip records stored in the `raw` schema.

The staging layer provides:

- Traceability to the original raw records.
- Standardized analytical data types.
- Human-readable categorical descriptions.
- Derived temporal and operational fields.
- Independent data quality flags.
- Reproducible validation queries.

The staging layer does not modify, delete, deduplicate, or correct records in
the raw layer.

---

## Database Object

The staging model is implemented as:

`staging.taxi_trips`

Object type:

`PostgreSQL view`

The view definition is versioned in:

`sql/staging/01_create_staging_taxi_trips.sql`

A normal view was selected for the first implementation because it:

- Does not duplicate the raw dataset physically.
- Always reflects the current raw records.
- Keeps the transformation declarative and reproducible.
- Avoids introducing incremental loading logic before it is required.
- Can be replaced by a materialized or physical model later if performance
  measurements justify the change.

---

## Grain

Each row in `staging.taxi_trips` represents exactly one row from:

`raw.taxi_trips`

The technical lineage key is:

`raw_trip_id`

The validated relationship is:

`raw.raw_trip_id -> staging.raw_trip_id`

No aggregation, deduplication, or row filtering occurs in the staging view.

---

## Sources

The view reads from:

- `raw.taxi_trips`
- `raw.ingestion_log`

The tables are joined through:

`ingestion_id`

The ingestion metadata added to each staging row includes:

- `source_file_name`
- `taxi_type`
- `period_year`
- `period_month`
- `ingestion_status`

The view does not filter by ingestion status or ingestion ID.

As a result, it currently contains:

- The 5,000-row development sample associated with `ingestion_id = 1`.
- The 3,475,226-row January 2025 monthly ingestion associated with
  `ingestion_id = 7`.

Analyses intended to represent the complete January 2025 dataset must use:

```sql
WHERE ingestion_id = 7
```

---

## Row-Count Validation

The following counts were validated after creating the view:

| Scope | Raw rows | Staging rows |
|---|---:|---:|
| Complete current raw layer | 3,480,226 | 3,480,226 |
| Development sample, ingestion 1 | 5,000 | 5,000 |
| January 2025, ingestion 7 | 3,475,226 | 3,475,226 |

For every current ingestion represented in the view:

`COUNT(*) = COUNT(DISTINCT raw_trip_id)`

This confirms that the join does not lose or multiply trip records.

---

## Traceability Columns

The following columns preserve record and ingestion lineage:

| Column | Purpose |
|---|---|
| `raw_trip_id` | Technical identifier of the original raw trip |
| `ingestion_id` | Identifier of the ingestion that loaded the trip |
| `source_file_name` | Name of the source Parquet file |
| `taxi_type` | Taxi dataset type |
| `period_year` | Expected ingestion year |
| `period_month` | Expected ingestion month |
| `ingestion_status` | Status stored in the ingestion log |
| `loaded_at` | Timestamp when the raw trip was loaded |

---

## Original Trip Attributes

The view preserves the original normalized attributes from the raw table,
including:

- Vendor code.
- Pickup and drop-off timestamps.
- Passenger count.
- Trip distance.
- Rate code.
- Store-and-forward flag.
- Pickup and drop-off location IDs.
- Payment type.
- Itemized monetary amounts.

Original categorical codes remain available even when a descriptive column is
also provided.

---

## Monetary Type Standardization

The raw table stores monetary values as:

`DOUBLE PRECISION`

The staging view exposes the monetary columns as:

`NUMERIC(12, 2)`

The standardized columns are:

- `fare_amount`
- `extra`
- `mta_tax`
- `tip_amount`
- `tolls_amount`
- `improvement_surcharge`
- `total_amount`
- `congestion_surcharge`
- `airport_fee`
- `cbd_congestion_fee`

The conversion was validated against `ingestion_id = 7`.

Confirmed results:

- The largest observed absolute monetary value is `863380.37`.
- No observed monetary value contains more than two decimal places.
- No January 2025 value loses observed decimal precision when converted to
  `NUMERIC(12, 2)`.

The raw values remain unchanged in `raw.taxi_trips`.

The validation query is versioned in:

`sql/staging/02_validate_staging_amount_types.sql`

---

## Categorical Descriptions

Categorical descriptions are based on the official NYC TLC Yellow Taxi trip
record data dictionary dated March 18, 2025.

### Vendor

| Code | Description |
|---:|---|
| 1 | Creative Mobile Technologies, LLC |
| 2 | Curb Mobility, LLC |
| 6 | Myle Technologies Inc |
| 7 | Helix |

The descriptive staging column is:

`vendor_name`

### Rate Code

| Code | Description |
|---:|---|
| 1 | Standard rate |
| 2 | JFK |
| 3 | Newark |
| 4 | Nassau or Westchester |
| 5 | Negotiated fare |
| 6 | Group ride |
| 99 | Unknown |

The descriptive staging column is:

`ratecode_name`

The source dictionary defines code `99` as a recognized unknown value. It is
therefore preserved as `99` rather than converted to `NULL`.

### Payment Type

| Code | Description |
|---:|---|
| 0 | Flex Fare trip |
| 1 | Credit card |
| 2 | Cash |
| 3 | No charge |
| 4 | Dispute |
| 5 | Unknown |
| 6 | Voided trip |

The descriptive staging column is:

`payment_type_name`

Code `5` is a recognized value whose documented meaning is `Unknown`.

### Store and Forward

| Code | Description |
|---|---|
| Y | Store and forward trip |
| N | Not a store and forward trip |

The descriptive staging column is:

`store_and_fwd_description`

A source `NULL` remains `NULL` and is not replaced with `N`.

### Unrecognized Values

If a future source contains a non-null categorical code outside the documented
sets, its descriptive value will be:

`Unrecognized`

The January 2025 validation found no unrecognized values in these four fields.

The category validation query is versioned in:

`sql/staging/03_validate_staging_category_codes.sql`

---

## Derived Fields

### `pickup_date`

The calendar date extracted from `pickup_datetime`.

Example:

`2025-01-15 14:37:21 -> 2025-01-15`

### `pickup_hour`

The pickup hour represented as an integer from 0 through 23.

Example:

`2025-01-15 14:37:21 -> 14`

### `trip_duration_minutes`

Trip duration calculated as:

`dropoff_datetime - pickup_datetime`

The resulting interval is converted to seconds and divided by 60.

Negative and zero durations are preserved in this field so that they remain
observable through the corresponding quality flag.

### `average_speed_mph`

Average speed is calculated as:

`trip_distance / trip duration in hours`

The value is calculated only when:

- Pickup timestamp is present.
- Drop-off timestamp is present.
- Drop-off occurs after pickup.
- Trip distance is greater than zero.

Otherwise, `average_speed_mph` is `NULL`.

No exploratory maximum-speed threshold is applied in the staging view.

---

## Detailed Quality Flags

Quality flags are independent boolean columns. A single trip may activate more
than one flag.

### `has_missing_datetime`

`TRUE` when either the pickup or drop-off timestamp is missing.

### `is_nonpositive_duration`

`TRUE` when:

`dropoff_datetime <= pickup_datetime`

These records are not reliable for duration or speed analysis.

### `is_duration_over_24_hours`

`TRUE` when the calculated duration is greater than 24 hours.

This is currently treated as a suspicious condition, not an automatic
rejection rule.

### `is_negative_distance`

`TRUE` when:

`trip_distance < 0`

### `is_zero_distance`

`TRUE` when:

`trip_distance = 0`

Zero-distance records are preserved and treated as suspicious rather than
automatically invalid.

### `is_pickup_outside_expected_period`

`TRUE` when the pickup timestamp falls outside the year and month stored in the
corresponding ingestion log.

The expected boundaries are generated dynamically from:

- `period_year`
- `period_month`

The rule uses a semi-open interval:

```text
pickup_datetime >= first day of the month
pickup_datetime < first day of the following month
```

### `has_missing_trip_attributes`

`TRUE` when at least one of the following is missing:

- `passenger_count`
- `ratecode_id`
- `store_and_fwd_flag`

For January 2025, these missing values occur together in the rows where
`payment_type = 0`.

Because `payment_type = 0` is documented as a Flex Fare trip, the missing
attribute pattern is recorded but is not automatically classified as an error.

### `is_negative_fare`

`TRUE` when:

`fare_amount < 0`

### `is_negative_total_amount`

`TRUE` when:

`total_amount < 0`

### `is_negative_transaction`

`TRUE` when either the fare amount or total amount is negative.

Negative transactions are preserved because they may represent refunds,
reversals, corrections, or other administrative transactions.

### Unrecognized Category Flags

The following flags identify non-null codes outside the documented sets:

- `is_unrecognized_vendor`
- `is_unrecognized_ratecode`
- `is_unrecognized_payment_type`
- `is_unrecognized_store_and_fwd`

All four counts are zero for `ingestion_id = 7`.

### Documented Unknown Flags

The following flags distinguish recognized codes whose documented meaning is
unknown:

- `is_documented_unknown_ratecode`
- `is_documented_unknown_payment_type`

These are different from unrecognized codes and from SQL `NULL` values.

---

## Consolidated Quality Flags

### `has_operational_issue`

`TRUE` when the record has at least one condition that prevents reliable basic
operational analysis:

- Missing pickup or drop-off timestamp.
- Non-positive duration.
- Negative trip distance.

### `has_suspicious_condition`

`TRUE` when the record contains at least one condition requiring review:

- Duration greater than 24 hours.
- Zero trip distance.
- Rate code documented as unknown.
- Payment type documented as unknown.

Missing Flex Fare attributes are intentionally not included in this
consolidated suspicious flag because their business meaning has not been fully
validated.

### `has_any_quality_flag`

`TRUE` when the record activates at least one current detailed quality flag,
including:

- Operational issues.
- Suspicious conditions.
- Missing trip attributes.
- Pickup outside the expected period.
- Negative transaction.
- Unrecognized categorical code.
- Documented unknown categorical code.

This name deliberately uses the word `flag` rather than `issue`. A flagged
record is not necessarily erroneous or unusable for every analytical purpose.

### `is_valid_for_speed_analysis`

`TRUE` when:

- Both timestamps are present.
- Drop-off occurs after pickup.
- Trip distance is greater than zero.

The logic was validated against `average_speed_mph`.

Confirmed result:

`is_valid_for_speed_analysis = (average_speed_mph IS NOT NULL)`

No inconsistent rows were found.

---

## January 2025 Validation Results

The following results were confirmed for `ingestion_id = 7`:

| Indicator | Rows |
|---|---:|
| Total rows | 3,475,226 |
| Missing timestamp | 0 |
| Non-positive duration | 2,051 |
| Duration over 24 hours | 20 |
| Negative distance | 0 |
| Zero distance | 90,893 |
| Pickup outside expected period | 22 |
| Missing trip attributes | 540,149 |
| Negative fare | 144,118 |
| Negative total amount | 63,037 |
| Negative transaction | 144,439 |
| Unrecognized vendor | 0 |
| Unrecognized rate code | 0 |
| Unrecognized payment type | 0 |
| Unrecognized store-and-forward value | 0 |
| Documented unknown rate code | 41,963 |
| Documented unknown payment type | 1 |
| Operational issue | 2,051 |
| Suspicious condition | 130,003 |
| Any quality flag | 674,526 |
| Valid for speed analysis | 3,382,974 |
| Calculated speed | 3,382,974 |
| Inconsistent speed flag | 0 |

The consolidated counts represent unions of overlapping conditions. Individual
flag counts must not be added directly.

---

## Validation Script

The complete staging validation is versioned in:

`sql/staging/04_validate_staging_taxi_trips.sql`

It validates:

- Raw-to-staging row-count parity.
- `raw_trip_id` uniqueness.
- Counts by ingestion.
- Detailed quality flags.
- Categorical flags.
- Consolidated flags.
- Speed-calculation consistency.

---

## Deployment

Run the staging view definition from the repository root:

```powershell
Get-Content -Raw .\sql\staging\01_create_staging_taxi_trips.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db
```

The script performs the following operations inside a PostgreSQL transaction:

1. Begins a transaction.
2. Drops the existing staging view if it exists.
3. Recreates the view from the versioned definition.
4. Commits the transaction.

The script does not use `CASCADE`.

If view creation fails before the commit, the transaction is rolled back and
the previous committed database state is preserved.

---

## Validation

Run the main validation script from the repository root:

```powershell
Get-Content -Raw .\sql\staging\04_validate_staging_taxi_trips.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db
```

The validation script contains only read operations.

---

## Limitations

- The implementation has been validated only against January 2025.
- The view currently includes both the development sample and the complete
  monthly ingestion.
- Taxi Zone descriptions are not yet joined to the pickup and drop-off
  location IDs.
- No exact-duplicate detection is implemented for the complete monthly data.
- The source does not provide a direct business trip identifier.
- Extreme-distance, extreme-amount, and high-speed thresholds remain
  exploratory and are not formal staging flags.
- Missing attributes associated with Flex Fare trips have not been confirmed
  as source errors.
- The view is not materialized and has no indexes of its own.
- Query performance has not yet been evaluated with `EXPLAIN ANALYZE`.
- A single mutually exclusive quality classification has not been defined.
- The current staging layer does not exclude records from downstream metrics;
  consumers must select the appropriate flags for each analytical use case.

---

## Downstream Use

The staging view is prepared for later use by:

- Advanced SQL analysis.
- Analytics-layer transformations.
- Dimensional modeling.
- Data marts.
- Python exploratory analysis.
- Power BI.

Downstream models should use detailed flags rather than assuming that every
flagged record must be removed.

The raw layer remains the source-preserving record of the original ingested
data.