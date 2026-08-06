BEGIN;

CREATE TABLE IF NOT EXISTS marts.dim_ingestion (
    ingestion_id BIGINT PRIMARY KEY,
    source_file_name TEXT NOT NULL,
    taxi_type TEXT NOT NULL,
    period_year SMALLINT NOT NULL,
    period_month SMALLINT NOT NULL,
    file_size_bytes BIGINT,
    ingestion_status TEXT NOT NULL,
    rows_read BIGINT NOT NULL,
    rows_loaded BIGINT NOT NULL,
    rows_rejected BIGINT NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,

    CONSTRAINT chk_dim_ingestion_period_year
        CHECK (period_year BETWEEN 2000 AND 2100),

    CONSTRAINT chk_dim_ingestion_period_month
        CHECK (period_month BETWEEN 1 AND 12),

    CONSTRAINT chk_dim_ingestion_file_size
        CHECK (
            file_size_bytes IS NULL
            OR file_size_bytes >= 0
        ),

    CONSTRAINT chk_dim_ingestion_status
        CHECK (
            ingestion_status IN (
                'started',
                'completed',
                'failed',
                'skipped'
            )
        ),

    CONSTRAINT chk_dim_ingestion_rows_read
        CHECK (rows_read >= 0),

    CONSTRAINT chk_dim_ingestion_rows_loaded
        CHECK (rows_loaded >= 0),

    CONSTRAINT chk_dim_ingestion_rows_rejected
        CHECK (rows_rejected >= 0)
);

CREATE TABLE IF NOT EXISTS marts.dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    calendar_year SMALLINT NOT NULL,
    calendar_quarter SMALLINT NOT NULL,
    month_number SMALLINT NOT NULL,
    month_name TEXT NOT NULL,
    day_of_month SMALLINT NOT NULL,
    day_of_week SMALLINT NOT NULL,
    day_name TEXT NOT NULL,
    iso_week SMALLINT NOT NULL,
    is_weekend BOOLEAN NOT NULL,

    CONSTRAINT chk_dim_date_calendar_quarter
        CHECK (calendar_quarter BETWEEN 1 AND 4),

    CONSTRAINT chk_dim_date_month_number
        CHECK (month_number BETWEEN 1 AND 12),

    CONSTRAINT chk_dim_date_day_of_month
        CHECK (day_of_month BETWEEN 1 AND 31),

    CONSTRAINT chk_dim_date_day_of_week
        CHECK (day_of_week BETWEEN 1 AND 7),

    CONSTRAINT chk_dim_date_iso_week
        CHECK (iso_week BETWEEN 1 AND 53)
);

CREATE TABLE IF NOT EXISTS marts.dim_hour (
    hour_key SMALLINT PRIMARY KEY,
    hour_label TEXT NOT NULL UNIQUE,
    day_period TEXT NOT NULL,

    CONSTRAINT chk_dim_hour_key
        CHECK (hour_key BETWEEN 0 AND 23),

    CONSTRAINT chk_dim_hour_day_period
        CHECK (
            day_period IN (
                'Night',
                'Morning',
                'Afternoon',
                'Evening'
            )
        )
);

CREATE TABLE IF NOT EXISTS marts.dim_vendor (
    vendor_key SMALLINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    vendor_id INTEGER NOT NULL UNIQUE,
    vendor_name TEXT NOT NULL,
    is_unrecognized_vendor BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS marts.dim_rate_code (
    rate_code_key SMALLINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    ratecode_id INTEGER,
    ratecode_name TEXT NOT NULL,
    is_unrecognized_ratecode BOOLEAN NOT NULL,
    is_documented_unknown_ratecode BOOLEAN NOT NULL,
    is_missing BOOLEAN NOT NULL,

    CONSTRAINT uq_dim_rate_code_ratecode_id
        UNIQUE NULLS NOT DISTINCT (ratecode_id),

    CONSTRAINT chk_dim_rate_code_missing
        CHECK (
            is_missing = (ratecode_id IS NULL)
        )
);

CREATE TABLE IF NOT EXISTS marts.dim_payment_type (
    payment_type_key SMALLINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    payment_type INTEGER NOT NULL UNIQUE,
    payment_type_name TEXT NOT NULL,
    is_unrecognized_payment_type BOOLEAN NOT NULL,
    is_documented_unknown_payment_type BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS marts.dim_store_and_fwd (
    store_and_fwd_key SMALLINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    store_and_fwd_flag TEXT,
    store_and_fwd_description TEXT NOT NULL,
    is_unrecognized_store_and_fwd BOOLEAN NOT NULL,
    is_missing BOOLEAN NOT NULL,

    CONSTRAINT uq_dim_store_and_fwd_flag
        UNIQUE NULLS NOT DISTINCT (store_and_fwd_flag),

    CONSTRAINT chk_dim_store_and_fwd_missing
        CHECK (
            is_missing = (store_and_fwd_flag IS NULL)
        )
);

CREATE TABLE IF NOT EXISTS marts.fact_trip (
    raw_trip_id BIGINT PRIMARY KEY,

    ingestion_id BIGINT NOT NULL,
    pickup_date_key INTEGER NOT NULL,
    dropoff_date_key INTEGER NOT NULL,
    pickup_hour_key SMALLINT NOT NULL,
    dropoff_hour_key SMALLINT NOT NULL,
    vendor_key SMALLINT NOT NULL,
    rate_code_key SMALLINT NOT NULL,
    payment_type_key SMALLINT NOT NULL,
    store_and_fwd_key SMALLINT NOT NULL,

    pickup_datetime TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    dropoff_datetime TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    pickup_location_id INTEGER NOT NULL,
    dropoff_location_id INTEGER NOT NULL,

    passenger_count INTEGER,
    trip_distance DOUBLE PRECISION,
    trip_duration_minutes DOUBLE PRECISION,
    average_speed_mph DOUBLE PRECISION,

    fare_amount NUMERIC(12, 2),
    extra NUMERIC(12, 2),
    mta_tax NUMERIC(12, 2),
    tip_amount NUMERIC(12, 2),
    tolls_amount NUMERIC(12, 2),
    improvement_surcharge NUMERIC(12, 2),
    total_amount NUMERIC(12, 2),
    congestion_surcharge NUMERIC(12, 2),
    airport_fee NUMERIC(12, 2),
    cbd_congestion_fee NUMERIC(12, 2),

    loaded_at TIMESTAMP WITH TIME ZONE,

    has_missing_datetime BOOLEAN,
    is_nonpositive_duration BOOLEAN,
    is_duration_over_24_hours BOOLEAN,
    is_negative_distance BOOLEAN,
    is_zero_distance BOOLEAN,
    is_pickup_outside_expected_period BOOLEAN,
    has_missing_trip_attributes BOOLEAN,
    is_negative_fare BOOLEAN,
    is_negative_total_amount BOOLEAN,
    is_negative_transaction BOOLEAN,
    is_unrecognized_vendor BOOLEAN,
    is_unrecognized_ratecode BOOLEAN,
    is_unrecognized_payment_type BOOLEAN,
    is_unrecognized_store_and_fwd BOOLEAN,
    is_documented_unknown_ratecode BOOLEAN,
    is_documented_unknown_payment_type BOOLEAN,
    has_operational_issue BOOLEAN,
    has_suspicious_condition BOOLEAN,
    has_any_quality_flag BOOLEAN,
    is_valid_for_speed_analysis BOOLEAN,

    CONSTRAINT fk_fact_trip_ingestion
        FOREIGN KEY (ingestion_id)
        REFERENCES marts.dim_ingestion (ingestion_id),

    CONSTRAINT fk_fact_trip_pickup_date
        FOREIGN KEY (pickup_date_key)
        REFERENCES marts.dim_date (date_key),

    CONSTRAINT fk_fact_trip_dropoff_date
        FOREIGN KEY (dropoff_date_key)
        REFERENCES marts.dim_date (date_key),

    CONSTRAINT fk_fact_trip_pickup_hour
        FOREIGN KEY (pickup_hour_key)
        REFERENCES marts.dim_hour (hour_key),

    CONSTRAINT fk_fact_trip_dropoff_hour
        FOREIGN KEY (dropoff_hour_key)
        REFERENCES marts.dim_hour (hour_key),

    CONSTRAINT fk_fact_trip_vendor
        FOREIGN KEY (vendor_key)
        REFERENCES marts.dim_vendor (vendor_key),

    CONSTRAINT fk_fact_trip_rate_code
        FOREIGN KEY (rate_code_key)
        REFERENCES marts.dim_rate_code (rate_code_key),

    CONSTRAINT fk_fact_trip_payment_type
        FOREIGN KEY (payment_type_key)
        REFERENCES marts.dim_payment_type (payment_type_key),

    CONSTRAINT fk_fact_trip_store_and_fwd
        FOREIGN KEY (store_and_fwd_key)
        REFERENCES marts.dim_store_and_fwd (store_and_fwd_key),

    CONSTRAINT chk_fact_trip_pickup_location
        CHECK (pickup_location_id > 0),

    CONSTRAINT chk_fact_trip_dropoff_location
        CHECK (dropoff_location_id > 0)
);

COMMIT;
