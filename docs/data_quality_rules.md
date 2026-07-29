# Initial Data Quality Rules

## Purpose

This document defines the preliminary data quality rules identified during the
initial exploration of the January 2025 NYC Yellow Taxi trip dataset.

These rules are provisional. They will be reviewed while developing the
ingestion and transformation pipeline and after analyzing the complete monthly
dataset.

The raw source records will be preserved whenever possible. Suspicious or
invalid records should be classified and documented instead of being removed
without explanation.

---

## 1. Record Classification

Each trip record will eventually be assigned one of the following analytical
classifications:

- `valid`: The record passes the current operational quality checks.
- `suspicious`: The record contains unusual values that require review but may
  still represent a legitimate trip.
- `invalid_operational`: The record cannot be used reliably for duration,
  distance, or speed analysis.
- `negative_transaction`: The record contains a negative fare or total amount
  and may represent a refund, reversal, or correction.
- `outside_expected_period`: The pickup timestamp falls outside the month being
  processed.

A record may satisfy more than one condition. Therefore, the final pipeline may
store individual quality flags in addition to an overall classification.

---

## 2. Complete Duplicates

### Condition

A record is considered a complete duplicate when all its column values are
identical to a previous record.

### Initial Observation

No complete duplicates were found in the first Parquet row group.

### Preliminary Treatment

- Preserve the first occurrence.
- Flag later identical occurrences as duplicates.
- Do not assume that the absence of complete duplicates means that every trip
  is unique.
- Investigate a technical trip key because the source does not provide a direct
  unique trip identifier.

---

## 3. Non-Positive Trip Duration

### Condition

```text
dropoff_datetime <= pickup_datetime
```

### Initial Observation

A small number of records had zero or negative duration.

### Preliminary Treatment

- Preserve the source record in the raw layer.
- Mark the record as `invalid_operational`.
- Do not calculate average speed.
- Exclude it from duration and speed KPIs.
- Retain it for data quality reporting.

---

## 4. Negative Trip Distance

### Condition

```text
trip_distance < 0
```

### Initial Observation

No negative trip distances were found in the first Parquet row group.

### Preliminary Treatment

- Preserve the source record in the raw layer.
- Mark it as `invalid_operational`.
- Exclude it from distance and speed analysis.
- Include it in data quality reports.

---

## 5. Zero-Distance Trips

### Condition

```text
trip_distance == 0
```

### Initial Observation

Approximately 1.4% of the analyzed records had zero recorded distance.

### Preliminary Treatment

- Do not automatically classify the record as invalid.
- Mark it as `suspicious`.
- Review duration, fare, rate code, and pickup and drop-off locations.
- Exclude it from average speed calculations.
- Decide later whether it should be included in trip-count and revenue metrics.

Zero-distance records may represent cancellations, corrections, administrative
transactions, meter errors, or legitimate trips whose distance was not
recorded.

---

## 6. Negative Monetary Values

### Conditions

```text
fare_amount < 0
```

or:

```text
total_amount < 0
```

### Initial Observation

Approximately 2.2% of the analyzed records contained negative fare or total
amount values.

### Preliminary Treatment

- Preserve the record.
- Classify it as `negative_transaction`.
- Do not treat it automatically as a data error.
- Analyze it separately from normal revenue-generating trips.
- Include negative values when calculating net revenue.
- Exclude them when calculating gross positive revenue, if that metric is later
  required.

Negative values may represent reversals, refunds, corrections, or other
administrative adjustments.

---

## 7. Pickup Outside the Expected Period

### Condition

For the January 2025 file:

```text
pickup_datetime < 2025-01-01
```

or:

```text
pickup_datetime >= 2025-02-01
```

### Initial Observation

A very small number of pickup timestamps fell outside January 2025.

### Preliminary Treatment

- Preserve the record in the raw layer.
- Mark it as `outside_expected_period`.
- Exclude it from January operational KPIs unless the business rule later
  determines that the trip belongs to the period based on drop-off time or
  another criterion.
- Record the discrepancy in the ingestion quality summary.

The final pipeline must generate these date boundaries dynamically from the
year and month being processed.

---

## 8. Unusually High Average Speed

### Exploratory Condition

```text
average_speed_mph > 80
```

### Initial Observation

A small number of calculated speeds exceeded 80 mph.

### Preliminary Treatment

- Mark the record as `suspicious`.
- Do not use 80 mph as a definitive rejection threshold yet.
- Review trip duration and distance.
- Exclude records with non-positive duration before calculating speed.
- Reassess the threshold after analyzing the complete dataset.

The current threshold is an exploratory indicator rather than a formal
business rule.

---

## 9. Missing Values

### Initial Observation

No missing values were found in the analyzed first row group.

### Preliminary Treatment

- Continue validating null values during every ingestion.
- Do not assume that later row groups or future files have the same result.
- Define mandatory and optional columns before creating the final staging
  rules.
- Distinguish true null values from special codes such as `0`, `99`, or other
  undocumented placeholders.

---

## 10. Categorical Codes

The following fields require validation against the official data dictionary:

- `VendorID`
- `RatecodeID`
- `payment_type`
- `store_and_fwd_flag`
- `PULocationID`
- `DOLocationID`

### Preliminary Treatment

- Preserve the original source code.
- Map known codes to descriptive values in dimension or reference tables.
- Flag unknown codes instead of silently replacing them.
- Validate pickup and drop-off location identifiers against the official taxi
  zone reference file.

---

## 11. Raw-Layer Principle

The raw layer should preserve source values as closely as possible.

It should not silently:

- Remove negative transactions.
- Remove zero-distance trips.
- Correct timestamps.
- Replace unknown codes.
- Delete suspicious records.

Cleaning, classification, and analytical exclusions will occur in later
layers, especially `staging` and `analytics`.

---

## 12. Current Limitations

- The initial analysis used only the first Parquet row group.
- The quality percentages do not yet represent the complete month.
- The source does not provide a direct unique trip identifier.
- Categorical codes have not yet been validated against all official reference
  definitions.
- Current thresholds are exploratory and may change.

---

## 13. Staging Implementation Update

The initial rules in this document were defined before the complete January
2025 dataset was profiled.

The `staging.taxi_trips` view now implements the confirmed rules described
below. The original sections remain in this document as the historical basis
for the staging design.

### Record Preservation

The staging layer preserves one row for every row in `raw.taxi_trips`.

It does not:

- Delete suspicious records.
- Deduplicate trips.
- Correct source timestamps.
- Replace source category codes.
- Exclude negative transactions.
- Exclude records outside the expected period.

Quality conditions are represented through independent boolean flags.

### Operational Issues

The consolidated flag:

`has_operational_issue`

is activated when at least one of the following conditions is present:

- Pickup or drop-off timestamp is missing.
- Drop-off occurs at or before pickup.
- Trip distance is negative.

These conditions prevent reliable use of the record for basic duration,
distance, or speed analysis.

### Suspicious Conditions

The consolidated flag:

`has_suspicious_condition`

is activated when at least one of the following conditions is present:

- Trip duration is greater than 24 hours.
- Trip distance is zero.
- Rate code is the documented unknown code `99`.
- Payment type is the documented unknown code `5`.

These conditions require review but do not automatically invalidate the
record for every analytical purpose.

### Missing Flex Fare Attributes

The complete January 2025 dataset contains 540,149 rows where all the following
conditions occur together:

- `payment_type = 0`
- `passenger_count IS NULL`
- `ratecode_id IS NULL`
- `store_and_fwd_flag IS NULL`

Payment type `0` is documented as a Flex Fare trip.

The staging layer records the missing values through:

`has_missing_trip_attributes`

The pattern is not automatically included in `has_suspicious_condition`
because its business meaning has not been fully validated.

### Negative Transactions

The staging layer provides the following independent flags:

- `is_negative_fare`
- `is_negative_total_amount`
- `is_negative_transaction`

A negative transaction is preserved and may represent a refund, reversal,
correction, or another administrative transaction.

Negative values remain included in net monetary calculations unless a
downstream metric explicitly defines a different treatment.

### Expected Period

The flag:

`is_pickup_outside_expected_period`

compares `pickup_datetime` with boundaries generated dynamically from the
`period_year` and `period_month` stored in `raw.ingestion_log`.

The rule does not hard-code January 2025.

The expected interval is semi-open:

```text
pickup_datetime >= first day of the ingestion month
pickup_datetime < first day of the following month
```

### Speed Analysis

The derived field:

`average_speed_mph`

is calculated only when:

- Pickup timestamp is present.
- Drop-off timestamp is present.
- Drop-off occurs after pickup.
- Trip distance is greater than zero.

The corresponding flag is:

`is_valid_for_speed_analysis`

Records that do not meet these conditions retain a `NULL` average speed.

The exploratory threshold of 80 mph has not been implemented as a formal
quality rule.

### Category Validation

The staging layer preserves original categorical codes and adds descriptive
columns.

It distinguishes between:

- SQL `NULL`.
- A recognized code whose documented meaning is `Unknown`.
- A non-null code that is not recognized by the documented code set.

The following recognized codes represent documented unknown values:

- `ratecode_id = 99`
- `payment_type = 5`

The corresponding flags are:

- `is_documented_unknown_ratecode`
- `is_documented_unknown_payment_type`

Unrecognized values are represented through:

- `is_unrecognized_vendor`
- `is_unrecognized_ratecode`
- `is_unrecognized_payment_type`
- `is_unrecognized_store_and_fwd`

No unrecognized categorical codes were found in the January 2025 monthly
ingestion.

### Monetary Standardization

Monetary values remain `DOUBLE PRECISION` in the raw layer.

The staging view exposes them as:

`NUMERIC(12, 2)`

The conversion was validated against the January 2025 monthly ingestion.

No observed monetary value exceeded the selected precision, and no observed
value contained more than two decimal places.

### General Quality Indicator

The staging layer provides:

`has_any_quality_flag`

This flag is activated when at least one current detailed quality condition is
present.

The word `flag` is intentional. A flagged record is not necessarily erroneous
or unusable for every analysis.

Downstream models must select records according to the requirements of each
metric instead of automatically removing every flagged row.

### Rules Not Yet Formalized

The following exploratory conditions have not been implemented as definitive
staging rules:

- Average speed greater than 80 mph.
- Trip distance greater than 100 or 1,000 miles.
- Monetary amount greater than 1,000.
- Exact duplicate detection.
- Passenger-count validity thresholds.
- Taxi Zone identifier validation.
- A single mutually exclusive quality classification.

These rules require additional business validation, reference data, or
analysis before they can be formalized.