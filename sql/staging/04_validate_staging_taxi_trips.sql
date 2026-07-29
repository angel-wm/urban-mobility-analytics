SELECT
    (
        SELECT COUNT(*)
        FROM raw.taxi_trips
    ) AS raw_rows,

    (
        SELECT COUNT(*)
        FROM staging.taxi_trips
    ) AS staging_rows;


SELECT
    ingestion_id,
    COUNT(*) AS trip_count,
    COUNT(DISTINCT raw_trip_id)
        AS distinct_raw_trip_ids
FROM staging.taxi_trips
GROUP BY ingestion_id
ORDER BY ingestion_id;


SELECT
    COUNT(*) AS total_rows,

    COUNT(*) FILTER (
        WHERE has_missing_datetime
    ) AS missing_datetime_rows,

    COUNT(*) FILTER (
        WHERE is_nonpositive_duration
    ) AS nonpositive_duration_rows,

    COUNT(*) FILTER (
        WHERE is_duration_over_24_hours
    ) AS duration_over_24_hours_rows,

    COUNT(*) FILTER (
        WHERE is_negative_distance
    ) AS negative_distance_rows,

    COUNT(*) FILTER (
        WHERE is_zero_distance
    ) AS zero_distance_rows,

    COUNT(*) FILTER (
        WHERE is_pickup_outside_expected_period
    ) AS pickup_outside_period_rows,

    COUNT(*) FILTER (
        WHERE has_missing_trip_attributes
    ) AS missing_trip_attribute_rows,

    COUNT(*) FILTER (
        WHERE is_negative_fare
    ) AS negative_fare_rows,

    COUNT(*) FILTER (
        WHERE is_negative_total_amount
    ) AS negative_total_amount_rows,

    COUNT(*) FILTER (
        WHERE is_negative_transaction
    ) AS negative_transaction_rows

FROM staging.taxi_trips
WHERE ingestion_id = 7;


SELECT
    COUNT(*) FILTER (
        WHERE is_unrecognized_vendor
    ) AS unrecognized_vendor_rows,

    COUNT(*) FILTER (
        WHERE is_unrecognized_ratecode
    ) AS unrecognized_ratecode_rows,

    COUNT(*) FILTER (
        WHERE is_unrecognized_payment_type
    ) AS unrecognized_payment_type_rows,

    COUNT(*) FILTER (
        WHERE is_unrecognized_store_and_fwd
    ) AS unrecognized_store_and_fwd_rows,

    COUNT(*) FILTER (
        WHERE is_documented_unknown_ratecode
    ) AS documented_unknown_ratecode_rows,

    COUNT(*) FILTER (
        WHERE is_documented_unknown_payment_type
    ) AS documented_unknown_payment_rows

FROM staging.taxi_trips
WHERE ingestion_id = 7;


SELECT
    COUNT(*) FILTER (
        WHERE has_operational_issue
    ) AS operational_issue_rows,

    COUNT(*) FILTER (
        WHERE has_suspicious_condition
    ) AS suspicious_condition_rows,

    COUNT(*) FILTER (
        WHERE has_any_quality_flag
    ) AS any_quality_flag_rows,

    COUNT(*) FILTER (
        WHERE is_valid_for_speed_analysis
    ) AS valid_for_speed_rows,

    COUNT(*) FILTER (
        WHERE average_speed_mph IS NOT NULL
    ) AS calculated_speed_rows

FROM staging.taxi_trips
WHERE ingestion_id = 7;


SELECT
    COUNT(*) AS inconsistent_speed_rows
FROM staging.taxi_trips
WHERE ingestion_id = 7
    AND (
        is_valid_for_speed_analysis
        <> (average_speed_mph IS NOT NULL)
    );