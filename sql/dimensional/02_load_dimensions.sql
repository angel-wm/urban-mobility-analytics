BEGIN;

INSERT INTO marts.dim_ingestion (
    ingestion_id,
    source_file_name,
    taxi_type,
    period_year,
    period_month,
    file_size_bytes,
    ingestion_status,
    rows_read,
    rows_loaded,
    rows_rejected,
    started_at,
    completed_at,
    error_message
)
SELECT
    ingestion_id,
    source_file_name,
    taxi_type,
    period_year,
    period_month,
    file_size_bytes,
    status,
    rows_read,
    rows_loaded,
    rows_rejected,
    started_at,
    completed_at,
    error_message
FROM raw.ingestion_log
ON CONFLICT (ingestion_id)
DO UPDATE SET
    source_file_name = EXCLUDED.source_file_name,
    taxi_type = EXCLUDED.taxi_type,
    period_year = EXCLUDED.period_year,
    period_month = EXCLUDED.period_month,
    file_size_bytes = EXCLUDED.file_size_bytes,
    ingestion_status = EXCLUDED.ingestion_status,
    rows_read = EXCLUDED.rows_read,
    rows_loaded = EXCLUDED.rows_loaded,
    rows_rejected = EXCLUDED.rows_rejected,
    started_at = EXCLUDED.started_at,
    completed_at = EXCLUDED.completed_at,
    error_message = EXCLUDED.error_message;

WITH date_bounds AS (
    SELECT
        LEAST(
            MIN(pickup_datetime::DATE),
            MIN(dropoff_datetime::DATE)
        ) AS minimum_date,
        GREATEST(
            MAX(pickup_datetime::DATE),
            MAX(dropoff_datetime::DATE)
        ) AS maximum_date
    FROM staging.taxi_trips
),
calendar_dates AS (
    SELECT
        GENERATE_SERIES(
            minimum_date,
            maximum_date,
            INTERVAL '1 day'
        )::DATE AS full_date
    FROM date_bounds
)
INSERT INTO marts.dim_date (
    date_key,
    full_date,
    calendar_year,
    calendar_quarter,
    month_number,
    month_name,
    day_of_month,
    day_of_week,
    day_name,
    iso_week,
    is_weekend
)
SELECT
    TO_CHAR(full_date, 'YYYYMMDD')::INTEGER,
    full_date,
    EXTRACT(YEAR FROM full_date)::SMALLINT,
    EXTRACT(QUARTER FROM full_date)::SMALLINT,
    EXTRACT(MONTH FROM full_date)::SMALLINT,

    CASE EXTRACT(MONTH FROM full_date)::INTEGER
        WHEN 1 THEN 'January'
        WHEN 2 THEN 'February'
        WHEN 3 THEN 'March'
        WHEN 4 THEN 'April'
        WHEN 5 THEN 'May'
        WHEN 6 THEN 'June'
        WHEN 7 THEN 'July'
        WHEN 8 THEN 'August'
        WHEN 9 THEN 'September'
        WHEN 10 THEN 'October'
        WHEN 11 THEN 'November'
        WHEN 12 THEN 'December'
    END,

    EXTRACT(DAY FROM full_date)::SMALLINT,
    EXTRACT(ISODOW FROM full_date)::SMALLINT,

    CASE EXTRACT(ISODOW FROM full_date)::INTEGER
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
        WHEN 7 THEN 'Sunday'
    END,

    EXTRACT(WEEK FROM full_date)::SMALLINT,

    EXTRACT(ISODOW FROM full_date)::INTEGER IN (6, 7)
FROM calendar_dates
ON CONFLICT (date_key)
DO UPDATE SET
    full_date = EXCLUDED.full_date,
    calendar_year = EXCLUDED.calendar_year,
    calendar_quarter = EXCLUDED.calendar_quarter,
    month_number = EXCLUDED.month_number,
    month_name = EXCLUDED.month_name,
    day_of_month = EXCLUDED.day_of_month,
    day_of_week = EXCLUDED.day_of_week,
    day_name = EXCLUDED.day_name,
    iso_week = EXCLUDED.iso_week,
    is_weekend = EXCLUDED.is_weekend;

INSERT INTO marts.dim_hour (
    hour_key,
    hour_label,
    day_period
)
SELECT
    hour_number::SMALLINT,
    LPAD(hour_number::TEXT, 2, '0') || ':00',

    CASE
        WHEN hour_number BETWEEN 0 AND 5 THEN 'Night'
        WHEN hour_number BETWEEN 6 AND 11 THEN 'Morning'
        WHEN hour_number BETWEEN 12 AND 17 THEN 'Afternoon'
        ELSE 'Evening'
    END
FROM GENERATE_SERIES(0, 23) AS hours(hour_number)
ON CONFLICT (hour_key)
DO UPDATE SET
    hour_label = EXCLUDED.hour_label,
    day_period = EXCLUDED.day_period;

INSERT INTO marts.dim_vendor (
    vendor_id,
    vendor_name,
    is_unrecognized_vendor
)
SELECT DISTINCT
    vendor_id,
    vendor_name,
    is_unrecognized_vendor
FROM staging.taxi_trips
ON CONFLICT (vendor_id)
DO UPDATE SET
    vendor_name = EXCLUDED.vendor_name,
    is_unrecognized_vendor =
        EXCLUDED.is_unrecognized_vendor;

INSERT INTO marts.dim_rate_code (
    ratecode_id,
    ratecode_name,
    is_unrecognized_ratecode,
    is_documented_unknown_ratecode,
    is_missing
)
SELECT DISTINCT
    ratecode_id,
    COALESCE(ratecode_name, 'Missing'),
    is_unrecognized_ratecode,
    is_documented_unknown_ratecode,
    ratecode_id IS NULL
FROM staging.taxi_trips
ON CONFLICT ON CONSTRAINT uq_dim_rate_code_ratecode_id
DO UPDATE SET
    ratecode_name = EXCLUDED.ratecode_name,
    is_unrecognized_ratecode =
        EXCLUDED.is_unrecognized_ratecode,
    is_documented_unknown_ratecode =
        EXCLUDED.is_documented_unknown_ratecode,
    is_missing = EXCLUDED.is_missing;

INSERT INTO marts.dim_payment_type (
    payment_type,
    payment_type_name,
    is_unrecognized_payment_type,
    is_documented_unknown_payment_type
)
SELECT DISTINCT
    payment_type,
    payment_type_name,
    is_unrecognized_payment_type,
    is_documented_unknown_payment_type
FROM staging.taxi_trips
ON CONFLICT (payment_type)
DO UPDATE SET
    payment_type_name = EXCLUDED.payment_type_name,
    is_unrecognized_payment_type =
        EXCLUDED.is_unrecognized_payment_type,
    is_documented_unknown_payment_type =
        EXCLUDED.is_documented_unknown_payment_type;

INSERT INTO marts.dim_store_and_fwd (
    store_and_fwd_flag,
    store_and_fwd_description,
    is_unrecognized_store_and_fwd,
    is_missing
)
SELECT DISTINCT
    store_and_fwd_flag,
    COALESCE(
        store_and_fwd_description,
        'Missing'
    ),
    is_unrecognized_store_and_fwd,
    store_and_fwd_flag IS NULL
FROM staging.taxi_trips
ON CONFLICT ON CONSTRAINT uq_dim_store_and_fwd_flag
DO UPDATE SET
    store_and_fwd_description =
        EXCLUDED.store_and_fwd_description,
    is_unrecognized_store_and_fwd =
        EXCLUDED.is_unrecognized_store_and_fwd,
    is_missing = EXCLUDED.is_missing;

COMMIT;
