-- Dimensional model validation.
-- Queries that return violation rows must return zero rows.

-- 1. Row counts for all dimensional objects.
SELECT
    'dim_ingestion' AS object_name,
    COUNT(*) AS row_count
FROM marts.dim_ingestion

UNION ALL

SELECT
    'dim_date',
    COUNT(*)
FROM marts.dim_date

UNION ALL

SELECT
    'dim_hour',
    COUNT(*)
FROM marts.dim_hour

UNION ALL

SELECT
    'dim_vendor',
    COUNT(*)
FROM marts.dim_vendor

UNION ALL

SELECT
    'dim_rate_code',
    COUNT(*)
FROM marts.dim_rate_code

UNION ALL

SELECT
    'dim_payment_type',
    COUNT(*)
FROM marts.dim_payment_type

UNION ALL

SELECT
    'dim_store_and_fwd',
    COUNT(*)
FROM marts.dim_store_and_fwd

UNION ALL

SELECT
    'fact_trip',
    COUNT(*)
FROM marts.fact_trip

ORDER BY object_name;

-- 2. Fact-table grain validation.
SELECT
    COUNT(*) AS fact_row_count,
    COUNT(DISTINCT raw_trip_id)
        AS distinct_raw_trip_count,
    COUNT(*) - COUNT(DISTINCT raw_trip_id)
        AS duplicate_raw_trip_count
FROM marts.fact_trip;

SELECT
    raw_trip_id,
    COUNT(*) AS row_count
FROM marts.fact_trip
GROUP BY raw_trip_id
HAVING COUNT(*) <> 1
ORDER BY row_count DESC, raw_trip_id
LIMIT 100;

-- 3. Reconciliation by ingestion.
WITH staging_counts AS (
    SELECT
        ingestion_id,
        COUNT(*) AS staging_row_count
    FROM staging.taxi_trips
    GROUP BY ingestion_id
),
fact_counts AS (
    SELECT
        ingestion_id,
        COUNT(*) AS fact_row_count
    FROM marts.fact_trip
    GROUP BY ingestion_id
)
SELECT
    COALESCE(
        staging_counts.ingestion_id,
        fact_counts.ingestion_id
    ) AS ingestion_id,

    staging_counts.staging_row_count,
    fact_counts.fact_row_count,

    COALESCE(staging_counts.staging_row_count, 0)
        - COALESCE(fact_counts.fact_row_count, 0)
        AS row_count_difference
FROM staging_counts
FULL OUTER JOIN fact_counts
    ON fact_counts.ingestion_id =
        staging_counts.ingestion_id
ORDER BY ingestion_id;

-- Must return zero rows.
WITH staging_counts AS (
    SELECT
        ingestion_id,
        COUNT(*) AS staging_row_count
    FROM staging.taxi_trips
    GROUP BY ingestion_id
),
fact_counts AS (
    SELECT
        ingestion_id,
        COUNT(*) AS fact_row_count
    FROM marts.fact_trip
    GROUP BY ingestion_id
)
SELECT
    COALESCE(
        staging_counts.ingestion_id,
        fact_counts.ingestion_id
    ) AS ingestion_id,

    staging_counts.staging_row_count,
    fact_counts.fact_row_count
FROM staging_counts
FULL OUTER JOIN fact_counts
    ON fact_counts.ingestion_id =
        staging_counts.ingestion_id
WHERE staging_counts.staging_row_count
    IS DISTINCT FROM fact_counts.fact_row_count
ORDER BY ingestion_id;

-- 4. Missing or additional fact identifiers.
-- Must return zero counts.
SELECT
    COUNT(*) FILTER (
        WHERE st.raw_trip_id IS NULL
    ) AS additional_fact_trip_count,

    COUNT(*) FILTER (
        WHERE ft.raw_trip_id IS NULL
    ) AS missing_fact_trip_count
FROM staging.taxi_trips AS st
FULL OUTER JOIN marts.fact_trip AS ft
    ON ft.raw_trip_id = st.raw_trip_id;

-- 5. Foreign-key orphan validation.
-- Every orphan count must be zero.
SELECT
    COUNT(*) FILTER (
        WHERE di.ingestion_id IS NULL
    ) AS ingestion_orphan_count,

    COUNT(*) FILTER (
        WHERE pickup_date.date_key IS NULL
    ) AS pickup_date_orphan_count,

    COUNT(*) FILTER (
        WHERE dropoff_date.date_key IS NULL
    ) AS dropoff_date_orphan_count,

    COUNT(*) FILTER (
        WHERE pickup_hour.hour_key IS NULL
    ) AS pickup_hour_orphan_count,

    COUNT(*) FILTER (
        WHERE dropoff_hour.hour_key IS NULL
    ) AS dropoff_hour_orphan_count,

    COUNT(*) FILTER (
        WHERE vendor.vendor_key IS NULL
    ) AS vendor_orphan_count,

    COUNT(*) FILTER (
        WHERE rate_code.rate_code_key IS NULL
    ) AS rate_code_orphan_count,

    COUNT(*) FILTER (
        WHERE payment.payment_type_key IS NULL
    ) AS payment_type_orphan_count,

    COUNT(*) FILTER (
        WHERE store_fwd.store_and_fwd_key IS NULL
    ) AS store_and_fwd_orphan_count
FROM marts.fact_trip AS ft

LEFT JOIN marts.dim_ingestion AS di
    ON di.ingestion_id = ft.ingestion_id

LEFT JOIN marts.dim_date AS pickup_date
    ON pickup_date.date_key = ft.pickup_date_key

LEFT JOIN marts.dim_date AS dropoff_date
    ON dropoff_date.date_key = ft.dropoff_date_key

LEFT JOIN marts.dim_hour AS pickup_hour
    ON pickup_hour.hour_key = ft.pickup_hour_key

LEFT JOIN marts.dim_hour AS dropoff_hour
    ON dropoff_hour.hour_key = ft.dropoff_hour_key

LEFT JOIN marts.dim_vendor AS vendor
    ON vendor.vendor_key = ft.vendor_key

LEFT JOIN marts.dim_rate_code AS rate_code
    ON rate_code.rate_code_key = ft.rate_code_key

LEFT JOIN marts.dim_payment_type AS payment
    ON payment.payment_type_key =
        ft.payment_type_key

LEFT JOIN marts.dim_store_and_fwd AS store_fwd
    ON store_fwd.store_and_fwd_key =
        ft.store_and_fwd_key;

-- 6. Ingestion dimension reconciliation.
-- Must return zero rows.
SELECT
    COALESCE(
        raw_log.ingestion_id,
        dim_ingestion.ingestion_id
    ) AS ingestion_id
FROM raw.ingestion_log AS raw_log
FULL OUTER JOIN marts.dim_ingestion AS dim_ingestion
    ON dim_ingestion.ingestion_id =
        raw_log.ingestion_id
WHERE raw_log.ingestion_id IS NULL
   OR dim_ingestion.ingestion_id IS NULL
   OR raw_log.source_file_name
        IS DISTINCT FROM
            dim_ingestion.source_file_name
   OR raw_log.taxi_type
        IS DISTINCT FROM dim_ingestion.taxi_type
   OR raw_log.period_year
        IS DISTINCT FROM dim_ingestion.period_year
   OR raw_log.period_month
        IS DISTINCT FROM dim_ingestion.period_month
   OR raw_log.file_size_bytes
        IS DISTINCT FROM
            dim_ingestion.file_size_bytes
   OR raw_log.status
        IS DISTINCT FROM
            dim_ingestion.ingestion_status
   OR raw_log.rows_read
        IS DISTINCT FROM dim_ingestion.rows_read
   OR raw_log.rows_loaded
        IS DISTINCT FROM dim_ingestion.rows_loaded
   OR raw_log.rows_rejected
        IS DISTINCT FROM
            dim_ingestion.rows_rejected
   OR raw_log.started_at
        IS DISTINCT FROM dim_ingestion.started_at
   OR raw_log.completed_at
        IS DISTINCT FROM
            dim_ingestion.completed_at
   OR raw_log.error_message
        IS DISTINCT FROM
            dim_ingestion.error_message
ORDER BY ingestion_id;

-- 7. Date-dimension validation.
SELECT
    MIN(full_date) AS minimum_date,
    MAX(full_date) AS maximum_date,
    COUNT(*) AS date_count,
    COUNT(DISTINCT date_key)
        AS distinct_date_key_count,
    COUNT(DISTINCT full_date)
        AS distinct_full_date_count
FROM marts.dim_date;

-- Must return zero rows.
SELECT
    date_key,
    full_date
FROM marts.dim_date
WHERE date_key
        <> TO_CHAR(full_date, 'YYYYMMDD')::INTEGER
   OR calendar_year
        <> EXTRACT(YEAR FROM full_date)::SMALLINT
   OR calendar_quarter
        <> EXTRACT(QUARTER FROM full_date)::SMALLINT
   OR month_number
        <> EXTRACT(MONTH FROM full_date)::SMALLINT
   OR day_of_month
        <> EXTRACT(DAY FROM full_date)::SMALLINT
   OR day_of_week
        <> EXTRACT(ISODOW FROM full_date)::SMALLINT
   OR iso_week
        <> EXTRACT(WEEK FROM full_date)::SMALLINT
   OR is_weekend
        <> (
            EXTRACT(ISODOW FROM full_date)::INTEGER
            IN (6, 7)
        )
ORDER BY full_date;

-- Every staging date must be represented.
-- Must return zero rows.
WITH staging_dates AS (
    SELECT pickup_datetime::DATE AS full_date
    FROM staging.taxi_trips

    UNION

    SELECT dropoff_datetime::DATE
    FROM staging.taxi_trips
)
SELECT
    staging_dates.full_date
FROM staging_dates
LEFT JOIN marts.dim_date
    ON dim_date.full_date =
        staging_dates.full_date
WHERE dim_date.date_key IS NULL
ORDER BY staging_dates.full_date;

-- 8. Hour-dimension validation.
SELECT
    MIN(hour_key) AS minimum_hour,
    MAX(hour_key) AS maximum_hour,
    COUNT(*) AS hour_count,
    COUNT(DISTINCT hour_key)
        AS distinct_hour_count
FROM marts.dim_hour;

-- Must return zero rows.
SELECT
    expected_hours.hour_key
FROM GENERATE_SERIES(0, 23)
    AS expected_hours(hour_key)
LEFT JOIN marts.dim_hour
    ON dim_hour.hour_key =
        expected_hours.hour_key
WHERE dim_hour.hour_key IS NULL
ORDER BY expected_hours.hour_key;

-- 9. Categorical-dimension reconciliation.
-- Every difference count must be zero.
WITH expected_vendors AS (
    SELECT DISTINCT
        vendor_id,
        vendor_name,
        is_unrecognized_vendor
    FROM staging.taxi_trips
),
vendor_differences AS (
    (
        SELECT
            vendor_id,
            vendor_name,
            is_unrecognized_vendor
        FROM expected_vendors

        EXCEPT

        SELECT
            vendor_id,
            vendor_name,
            is_unrecognized_vendor
        FROM marts.dim_vendor
    )

    UNION ALL

    (
        SELECT
            vendor_id,
            vendor_name,
            is_unrecognized_vendor
        FROM marts.dim_vendor

        EXCEPT

        SELECT
            vendor_id,
            vendor_name,
            is_unrecognized_vendor
        FROM expected_vendors
    )
),
expected_rate_codes AS (
    SELECT DISTINCT
        ratecode_id,
        COALESCE(ratecode_name, 'Missing')
            AS ratecode_name,
        is_unrecognized_ratecode,
        is_documented_unknown_ratecode,
        ratecode_id IS NULL AS is_missing
    FROM staging.taxi_trips
),
rate_code_differences AS (
    (
        SELECT *
        FROM expected_rate_codes

        EXCEPT

        SELECT
            ratecode_id,
            ratecode_name,
            is_unrecognized_ratecode,
            is_documented_unknown_ratecode,
            is_missing
        FROM marts.dim_rate_code
    )

    UNION ALL

    (
        SELECT
            ratecode_id,
            ratecode_name,
            is_unrecognized_ratecode,
            is_documented_unknown_ratecode,
            is_missing
        FROM marts.dim_rate_code

        EXCEPT

        SELECT *
        FROM expected_rate_codes
    )
),
expected_payment_types AS (
    SELECT DISTINCT
        payment_type,
        payment_type_name,
        is_unrecognized_payment_type,
        is_documented_unknown_payment_type
    FROM staging.taxi_trips
),
payment_type_differences AS (
    (
        SELECT *
        FROM expected_payment_types

        EXCEPT

        SELECT
            payment_type,
            payment_type_name,
            is_unrecognized_payment_type,
            is_documented_unknown_payment_type
        FROM marts.dim_payment_type
    )

    UNION ALL

    (
        SELECT
            payment_type,
            payment_type_name,
            is_unrecognized_payment_type,
            is_documented_unknown_payment_type
        FROM marts.dim_payment_type

        EXCEPT

        SELECT *
        FROM expected_payment_types
    )
),
expected_store_and_fwd AS (
    SELECT DISTINCT
        store_and_fwd_flag,
        COALESCE(
            store_and_fwd_description,
            'Missing'
        ) AS store_and_fwd_description,
        is_unrecognized_store_and_fwd,
        store_and_fwd_flag IS NULL AS is_missing
    FROM staging.taxi_trips
),
store_and_fwd_differences AS (
    (
        SELECT *
        FROM expected_store_and_fwd

        EXCEPT

        SELECT
            store_and_fwd_flag,
            store_and_fwd_description,
            is_unrecognized_store_and_fwd,
            is_missing
        FROM marts.dim_store_and_fwd
    )

    UNION ALL

    (
        SELECT
            store_and_fwd_flag,
            store_and_fwd_description,
            is_unrecognized_store_and_fwd,
            is_missing
        FROM marts.dim_store_and_fwd

        EXCEPT

        SELECT *
        FROM expected_store_and_fwd
    )
)
SELECT
    (
        SELECT COUNT(*)
        FROM vendor_differences
    ) AS vendor_difference_count,

    (
        SELECT COUNT(*)
        FROM rate_code_differences
    ) AS rate_code_difference_count,

    (
        SELECT COUNT(*)
        FROM payment_type_differences
    ) AS payment_type_difference_count,

    (
        SELECT COUNT(*)
        FROM store_and_fwd_differences
    ) AS store_and_fwd_difference_count;

-- 10. Fact foreign-key derivation validation.
-- Every mismatch count must be zero.
SELECT
    COUNT(*) FILTER (
        WHERE ft.pickup_date_key
            IS DISTINCT FROM
                TO_CHAR(
                    st.pickup_datetime::DATE,
                    'YYYYMMDD'
                )::INTEGER
    ) AS pickup_date_key_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.dropoff_date_key
            IS DISTINCT FROM
                TO_CHAR(
                    st.dropoff_datetime::DATE,
                    'YYYYMMDD'
                )::INTEGER
    ) AS dropoff_date_key_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.pickup_hour_key
            IS DISTINCT FROM
                EXTRACT(
                    HOUR FROM st.pickup_datetime
                )::SMALLINT
    ) AS pickup_hour_key_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.dropoff_hour_key
            IS DISTINCT FROM
                EXTRACT(
                    HOUR FROM st.dropoff_datetime
                )::SMALLINT
    ) AS dropoff_hour_key_mismatch_count,

    COUNT(*) FILTER (
        WHERE vendor.vendor_id
            IS DISTINCT FROM st.vendor_id
    ) AS vendor_key_mismatch_count,

    COUNT(*) FILTER (
        WHERE rate_code.ratecode_id
            IS DISTINCT FROM st.ratecode_id
    ) AS rate_code_key_mismatch_count,

    COUNT(*) FILTER (
        WHERE payment.payment_type
            IS DISTINCT FROM st.payment_type
    ) AS payment_type_key_mismatch_count,

    COUNT(*) FILTER (
        WHERE store_fwd.store_and_fwd_flag
            IS DISTINCT FROM st.store_and_fwd_flag
    ) AS store_and_fwd_key_mismatch_count
FROM staging.taxi_trips AS st

INNER JOIN marts.fact_trip AS ft
    ON ft.raw_trip_id = st.raw_trip_id

INNER JOIN marts.dim_vendor AS vendor
    ON vendor.vendor_key = ft.vendor_key

INNER JOIN marts.dim_rate_code AS rate_code
    ON rate_code.rate_code_key =
        ft.rate_code_key

INNER JOIN marts.dim_payment_type AS payment
    ON payment.payment_type_key =
        ft.payment_type_key

INNER JOIN marts.dim_store_and_fwd AS store_fwd
    ON store_fwd.store_and_fwd_key =
        ft.store_and_fwd_key;

-- 11. Fact operational and measure preservation.
-- Every mismatch count must be zero.
SELECT
    COUNT(*) FILTER (
        WHERE ft.ingestion_id
            IS DISTINCT FROM st.ingestion_id
    ) AS ingestion_id_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.pickup_datetime
            IS DISTINCT FROM st.pickup_datetime
    ) AS pickup_datetime_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.dropoff_datetime
            IS DISTINCT FROM st.dropoff_datetime
    ) AS dropoff_datetime_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.pickup_location_id
            IS DISTINCT FROM st.pickup_location_id
    ) AS pickup_location_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.dropoff_location_id
            IS DISTINCT FROM st.dropoff_location_id
    ) AS dropoff_location_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.passenger_count
            IS DISTINCT FROM st.passenger_count
    ) AS passenger_count_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.trip_distance
            IS DISTINCT FROM st.trip_distance
    ) AS trip_distance_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.trip_duration_minutes
            IS DISTINCT FROM
                st.trip_duration_minutes
    ) AS trip_duration_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.average_speed_mph
            IS DISTINCT FROM st.average_speed_mph
    ) AS average_speed_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.loaded_at
            IS DISTINCT FROM st.loaded_at
    ) AS loaded_at_mismatch_count
FROM staging.taxi_trips AS st
INNER JOIN marts.fact_trip AS ft
    ON ft.raw_trip_id = st.raw_trip_id;

-- 12. Monetary preservation.
-- Every mismatch count must be zero.
SELECT
    COUNT(*) FILTER (
        WHERE ft.fare_amount
            IS DISTINCT FROM st.fare_amount
    ) AS fare_amount_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.extra
            IS DISTINCT FROM st.extra
    ) AS extra_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.mta_tax
            IS DISTINCT FROM st.mta_tax
    ) AS mta_tax_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.tip_amount
            IS DISTINCT FROM st.tip_amount
    ) AS tip_amount_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.tolls_amount
            IS DISTINCT FROM st.tolls_amount
    ) AS tolls_amount_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.improvement_surcharge
            IS DISTINCT FROM
                st.improvement_surcharge
    ) AS improvement_surcharge_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.total_amount
            IS DISTINCT FROM st.total_amount
    ) AS total_amount_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.congestion_surcharge
            IS DISTINCT FROM
                st.congestion_surcharge
    ) AS congestion_surcharge_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.airport_fee
            IS DISTINCT FROM st.airport_fee
    ) AS airport_fee_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.cbd_congestion_fee
            IS DISTINCT FROM
                st.cbd_congestion_fee
    ) AS cbd_congestion_fee_mismatch_count
FROM staging.taxi_trips AS st
INNER JOIN marts.fact_trip AS ft
    ON ft.raw_trip_id = st.raw_trip_id;

-- 13. Quality-flag preservation.
-- Every mismatch count must be zero.
SELECT
    COUNT(*) FILTER (
        WHERE ft.has_missing_datetime
            IS DISTINCT FROM
                st.has_missing_datetime
    ) AS missing_datetime_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_nonpositive_duration
            IS DISTINCT FROM
                st.is_nonpositive_duration
    ) AS nonpositive_duration_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_duration_over_24_hours
            IS DISTINCT FROM
                st.is_duration_over_24_hours
    ) AS long_duration_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_negative_distance
            IS DISTINCT FROM
                st.is_negative_distance
    ) AS negative_distance_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_zero_distance
            IS DISTINCT FROM st.is_zero_distance
    ) AS zero_distance_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_pickup_outside_expected_period
            IS DISTINCT FROM
                st.is_pickup_outside_expected_period
    ) AS outside_period_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.has_missing_trip_attributes
            IS DISTINCT FROM
                st.has_missing_trip_attributes
    ) AS missing_attributes_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_negative_fare
            IS DISTINCT FROM st.is_negative_fare
    ) AS negative_fare_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_negative_total_amount
            IS DISTINCT FROM
                st.is_negative_total_amount
    ) AS negative_total_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_negative_transaction
            IS DISTINCT FROM
                st.is_negative_transaction
    ) AS negative_transaction_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_unrecognized_vendor
            IS DISTINCT FROM
                st.is_unrecognized_vendor
    ) AS vendor_flag_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_unrecognized_ratecode
            IS DISTINCT FROM
                st.is_unrecognized_ratecode
    ) AS ratecode_flag_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_unrecognized_payment_type
            IS DISTINCT FROM
                st.is_unrecognized_payment_type
    ) AS payment_flag_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_unrecognized_store_and_fwd
            IS DISTINCT FROM
                st.is_unrecognized_store_and_fwd
    ) AS store_and_fwd_flag_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_documented_unknown_ratecode
            IS DISTINCT FROM
                st.is_documented_unknown_ratecode
    ) AS documented_ratecode_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_documented_unknown_payment_type
            IS DISTINCT FROM
                st.is_documented_unknown_payment_type
    ) AS documented_payment_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.has_operational_issue
            IS DISTINCT FROM
                st.has_operational_issue
    ) AS operational_issue_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.has_suspicious_condition
            IS DISTINCT FROM
                st.has_suspicious_condition
    ) AS suspicious_condition_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.has_any_quality_flag
            IS DISTINCT FROM
                st.has_any_quality_flag
    ) AS any_quality_flag_mismatch_count,

    COUNT(*) FILTER (
        WHERE ft.is_valid_for_speed_analysis
            IS DISTINCT FROM
                st.is_valid_for_speed_analysis
    ) AS speed_eligibility_mismatch_count
FROM staging.taxi_trips AS st
INNER JOIN marts.fact_trip AS ft
    ON ft.raw_trip_id = st.raw_trip_id;

-- 14. Aggregate monetary reconciliation by ingestion.
-- Every difference must equal zero.
WITH staging_amounts AS (
    SELECT
        ingestion_id,
        SUM(fare_amount) AS fare_amount,
        SUM(extra) AS extra,
        SUM(mta_tax) AS mta_tax,
        SUM(tip_amount) AS tip_amount,
        SUM(tolls_amount) AS tolls_amount,
        SUM(improvement_surcharge)
            AS improvement_surcharge,
        SUM(total_amount) AS total_amount,
        SUM(congestion_surcharge)
            AS congestion_surcharge,
        SUM(airport_fee) AS airport_fee,
        SUM(cbd_congestion_fee)
            AS cbd_congestion_fee
    FROM staging.taxi_trips
    GROUP BY ingestion_id
),
fact_amounts AS (
    SELECT
        ingestion_id,
        SUM(fare_amount) AS fare_amount,
        SUM(extra) AS extra,
        SUM(mta_tax) AS mta_tax,
        SUM(tip_amount) AS tip_amount,
        SUM(tolls_amount) AS tolls_amount,
        SUM(improvement_surcharge)
            AS improvement_surcharge,
        SUM(total_amount) AS total_amount,
        SUM(congestion_surcharge)
            AS congestion_surcharge,
        SUM(airport_fee) AS airport_fee,
        SUM(cbd_congestion_fee)
            AS cbd_congestion_fee
    FROM marts.fact_trip
    GROUP BY ingestion_id
)
SELECT
    staging_amounts.ingestion_id,

    staging_amounts.fare_amount
        - fact_amounts.fare_amount
        AS fare_amount_difference,

    staging_amounts.extra
        - fact_amounts.extra
        AS extra_difference,

    staging_amounts.mta_tax
        - fact_amounts.mta_tax
        AS mta_tax_difference,

    staging_amounts.tip_amount
        - fact_amounts.tip_amount
        AS tip_amount_difference,

    staging_amounts.tolls_amount
        - fact_amounts.tolls_amount
        AS tolls_amount_difference,

    staging_amounts.improvement_surcharge
        - fact_amounts.improvement_surcharge
        AS improvement_surcharge_difference,

    staging_amounts.total_amount
        - fact_amounts.total_amount
        AS total_amount_difference,

    staging_amounts.congestion_surcharge
        - fact_amounts.congestion_surcharge
        AS congestion_surcharge_difference,

    staging_amounts.airport_fee
        - fact_amounts.airport_fee
        AS airport_fee_difference,

    staging_amounts.cbd_congestion_fee
        - fact_amounts.cbd_congestion_fee
        AS cbd_congestion_fee_difference
FROM staging_amounts
INNER JOIN fact_amounts
    ON fact_amounts.ingestion_id =
        staging_amounts.ingestion_id
ORDER BY staging_amounts.ingestion_id;

-- 15. Current dimensional-model summary.
SELECT
    ft.ingestion_id,
    di.source_file_name,
    di.ingestion_status,
    COUNT(*) AS trip_count,
    MIN(ft.pickup_datetime)
        AS minimum_pickup_datetime,
    MAX(ft.pickup_datetime)
        AS maximum_pickup_datetime,
    SUM(ft.total_amount)
        AS total_amount
FROM marts.fact_trip AS ft
INNER JOIN marts.dim_ingestion AS di
    ON di.ingestion_id = ft.ingestion_id
GROUP BY
    ft.ingestion_id,
    di.source_file_name,
    di.ingestion_status
ORDER BY ft.ingestion_id;
