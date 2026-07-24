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