BEGIN;


DROP VIEW IF EXISTS staging.taxi_trips;


CREATE VIEW staging.taxi_trips AS
SELECT
    t.raw_trip_id,
    t.ingestion_id,

    i.source_file_name,
    i.taxi_type,
    i.period_year,
    i.period_month,
    i.status AS ingestion_status,

    t.vendor_id,
    t.pickup_datetime,
    t.dropoff_datetime,
    t.passenger_count,
    t.trip_distance,
    t.ratecode_id,
    t.store_and_fwd_flag,
    t.pickup_location_id,
    t.dropoff_location_id,
    t.payment_type,

    CASE
        WHEN t.vendor_id IS NULL THEN NULL
        WHEN t.vendor_id = 1
            THEN 'Creative Mobile Technologies, LLC'
        WHEN t.vendor_id = 2
            THEN 'Curb Mobility, LLC'
        WHEN t.vendor_id = 6
            THEN 'Myle Technologies Inc'
        WHEN t.vendor_id = 7
            THEN 'Helix'
        ELSE 'Unrecognized'
    END AS vendor_name,

    CASE
        WHEN t.ratecode_id IS NULL THEN NULL
        WHEN t.ratecode_id = 1 THEN 'Standard rate'
        WHEN t.ratecode_id = 2 THEN 'JFK'
        WHEN t.ratecode_id = 3 THEN 'Newark'
        WHEN t.ratecode_id = 4
            THEN 'Nassau or Westchester'
        WHEN t.ratecode_id = 5
            THEN 'Negotiated fare'
        WHEN t.ratecode_id = 6 THEN 'Group ride'
        WHEN t.ratecode_id = 99 THEN 'Unknown'
        ELSE 'Unrecognized'
    END AS ratecode_name,

    CASE
        WHEN t.payment_type IS NULL THEN NULL
        WHEN t.payment_type = 0 THEN 'Flex Fare trip'
        WHEN t.payment_type = 1 THEN 'Credit card'
        WHEN t.payment_type = 2 THEN 'Cash'
        WHEN t.payment_type = 3 THEN 'No charge'
        WHEN t.payment_type = 4 THEN 'Dispute'
        WHEN t.payment_type = 5 THEN 'Unknown'
        WHEN t.payment_type = 6 THEN 'Voided trip'
        ELSE 'Unrecognized'
    END AS payment_type_name,

    CASE
        WHEN t.store_and_fwd_flag IS NULL THEN NULL
        WHEN t.store_and_fwd_flag = 'Y'
            THEN 'Store and forward trip'
        WHEN t.store_and_fwd_flag = 'N'
            THEN 'Not a store and forward trip'
        ELSE 'Unrecognized'
    END AS store_and_fwd_description,

    t.fare_amount::NUMERIC(12, 2)
        AS fare_amount,

    t.extra::NUMERIC(12, 2)
        AS extra,

    t.mta_tax::NUMERIC(12, 2)
        AS mta_tax,

    t.tip_amount::NUMERIC(12, 2)
        AS tip_amount,

    t.tolls_amount::NUMERIC(12, 2)
        AS tolls_amount,

    t.improvement_surcharge::NUMERIC(12, 2)
        AS improvement_surcharge,

    t.total_amount::NUMERIC(12, 2)
        AS total_amount,

    t.congestion_surcharge::NUMERIC(12, 2)
        AS congestion_surcharge,

    t.airport_fee::NUMERIC(12, 2)
        AS airport_fee,

    t.cbd_congestion_fee::NUMERIC(12, 2)
        AS cbd_congestion_fee,

    t.loaded_at,

    t.pickup_datetime::DATE AS pickup_date,

    EXTRACT(
        HOUR FROM t.pickup_datetime
    )::SMALLINT AS pickup_hour,

    EXTRACT(
        EPOCH FROM (
            t.dropoff_datetime - t.pickup_datetime
        )
    )::DOUBLE PRECISION / 60 AS trip_duration_minutes,

    CASE
        WHEN t.dropoff_datetime > t.pickup_datetime
            AND t.trip_distance > 0
        THEN
            t.trip_distance
            / (
                EXTRACT(
                    EPOCH FROM (
                        t.dropoff_datetime - t.pickup_datetime
                    )
                )::DOUBLE PRECISION / 3600
            )
        ELSE NULL
    END AS average_speed_mph,

    (
        t.pickup_datetime IS NULL
        OR t.dropoff_datetime IS NULL
    ) AS has_missing_datetime,

    COALESCE(
        t.dropoff_datetime <= t.pickup_datetime,
        FALSE
    ) AS is_nonpositive_duration,

    COALESCE(
        (
            t.dropoff_datetime - t.pickup_datetime
        ) > INTERVAL '24 hours',
        FALSE
    ) AS is_duration_over_24_hours,

    COALESCE(
        t.trip_distance < 0,
        FALSE
    ) AS is_negative_distance,

    COALESCE(
        t.trip_distance = 0,
        FALSE
    ) AS is_zero_distance,

    COALESCE(
        t.pickup_datetime
            < MAKE_DATE(
                i.period_year::INTEGER,
                i.period_month::INTEGER,
                1
            )::TIMESTAMP
        OR t.pickup_datetime
            >= (
                MAKE_DATE(
                    i.period_year::INTEGER,
                    i.period_month::INTEGER,
                    1
                )::TIMESTAMP
                + INTERVAL '1 month'
            ),
        FALSE
    ) AS is_pickup_outside_expected_period,

    (
        t.passenger_count IS NULL
        OR t.ratecode_id IS NULL
        OR t.store_and_fwd_flag IS NULL
    ) AS has_missing_trip_attributes,

    COALESCE(
        t.fare_amount < 0,
        FALSE
    ) AS is_negative_fare,

    COALESCE(
        t.total_amount < 0,
        FALSE
    ) AS is_negative_total_amount,

    COALESCE(
        t.fare_amount < 0
        OR t.total_amount < 0,
        FALSE
    ) AS is_negative_transaction,

    COALESCE(
        t.vendor_id NOT IN (1, 2, 6, 7),
        FALSE
    ) AS is_unrecognized_vendor,

    COALESCE(
        t.ratecode_id NOT IN (
            1,
            2,
            3,
            4,
            5,
            6,
            99
        ),
        FALSE
    ) AS is_unrecognized_ratecode,

    COALESCE(
        t.payment_type NOT IN (
            0,
            1,
            2,
            3,
            4,
            5,
            6
        ),
        FALSE
    ) AS is_unrecognized_payment_type,

    COALESCE(
        t.store_and_fwd_flag NOT IN ('Y', 'N'),
        FALSE
    ) AS is_unrecognized_store_and_fwd,

    COALESCE(
        t.ratecode_id = 99,
        FALSE
    ) AS is_documented_unknown_ratecode,

    COALESCE(
        t.payment_type = 5,
        FALSE
    ) AS is_documented_unknown_payment_type,

    (
        t.pickup_datetime IS NULL
        OR t.dropoff_datetime IS NULL
        OR COALESCE(
            t.dropoff_datetime <= t.pickup_datetime,
            FALSE
        )
        OR COALESCE(
            t.trip_distance < 0,
            FALSE
        )
    ) AS has_operational_issue,

    (
        COALESCE(
            (
                t.dropoff_datetime - t.pickup_datetime
            ) > INTERVAL '24 hours',
            FALSE
        )
        OR COALESCE(
            t.trip_distance = 0,
            FALSE
        )
        OR COALESCE(
            t.ratecode_id = 99,
            FALSE
        )
        OR COALESCE(
            t.payment_type = 5,
            FALSE
        )
    ) AS has_suspicious_condition,

    (
        t.pickup_datetime IS NULL
        OR t.dropoff_datetime IS NULL
        OR COALESCE(
            t.dropoff_datetime <= t.pickup_datetime,
            FALSE
        )
        OR COALESCE(
            (
                t.dropoff_datetime - t.pickup_datetime
            ) > INTERVAL '24 hours',
            FALSE
        )
        OR COALESCE(
            t.trip_distance < 0,
            FALSE
        )
        OR COALESCE(
            t.trip_distance = 0,
            FALSE
        )
        OR COALESCE(
            t.pickup_datetime
                < MAKE_DATE(
                    i.period_year::INTEGER,
                    i.period_month::INTEGER,
                    1
                )::TIMESTAMP
            OR t.pickup_datetime
                >= (
                    MAKE_DATE(
                        i.period_year::INTEGER,
                        i.period_month::INTEGER,
                        1
                    )::TIMESTAMP
                    + INTERVAL '1 month'
                ),
            FALSE
        )
        OR (
            t.passenger_count IS NULL
            OR t.ratecode_id IS NULL
            OR t.store_and_fwd_flag IS NULL
        )
        OR COALESCE(
            t.fare_amount < 0
            OR t.total_amount < 0,
            FALSE
        )
        OR COALESCE(
            t.vendor_id NOT IN (1, 2, 6, 7),
            FALSE
        )
        OR COALESCE(
            t.ratecode_id NOT IN (
                1,
                2,
                3,
                4,
                5,
                6,
                99
            ),
            FALSE
        )
        OR COALESCE(
            t.payment_type NOT IN (
                0,
                1,
                2,
                3,
                4,
                5,
                6
            ),
            FALSE
        )
        OR COALESCE(
            t.store_and_fwd_flag NOT IN ('Y', 'N'),
            FALSE
        )
        OR COALESCE(
            t.ratecode_id = 99,
            FALSE
        )
        OR COALESCE(
            t.payment_type = 5,
            FALSE
        )
    ) AS has_any_quality_flag,

    COALESCE(
        t.pickup_datetime IS NOT NULL
        AND t.dropoff_datetime IS NOT NULL
        AND t.dropoff_datetime > t.pickup_datetime
        AND t.trip_distance > 0,
        FALSE
    ) AS is_valid_for_speed_analysis
FROM raw.taxi_trips AS t
INNER JOIN raw.ingestion_log AS i
    ON t.ingestion_id = i.ingestion_id;

COMMIT;