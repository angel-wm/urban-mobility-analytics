CREATE TABLE IF NOT EXISTS raw.ingestion_log (
    ingestion_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    source_file_name TEXT NOT NULL,
    taxi_type TEXT NOT NULL,

    period_year SMALLINT NOT NULL
        CHECK (period_year BETWEEN 2000 AND 2100),

    period_month SMALLINT NOT NULL
        CHECK (period_month BETWEEN 1 AND 12),

    file_size_bytes BIGINT
        CHECK (
            file_size_bytes IS NULL
            OR file_size_bytes >= 0
        ),

    status TEXT NOT NULL
        CHECK (
            status IN (
                'started',
                'completed',
                'failed',
                'skipped'
            )
        ),

    rows_read BIGINT NOT NULL DEFAULT 0
        CHECK (rows_read >= 0),

    rows_loaded BIGINT NOT NULL DEFAULT 0
        CHECK (rows_loaded >= 0),

    rows_rejected BIGINT NOT NULL DEFAULT 0
        CHECK (rows_rejected >= 0),

    started_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    completed_at TIMESTAMPTZ,

    error_message TEXT
);


CREATE TABLE IF NOT EXISTS raw.taxi_trips (
    raw_trip_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    ingestion_id BIGINT NOT NULL,

    vendor_id INTEGER,
    pickup_datetime TIMESTAMP,
    dropoff_datetime TIMESTAMP,
    passenger_count INTEGER,
    trip_distance DOUBLE PRECISION,
    ratecode_id INTEGER,
    store_and_fwd_flag TEXT,
    pickup_location_id INTEGER,
    dropoff_location_id INTEGER,
    payment_type INTEGER,

    fare_amount DOUBLE PRECISION,
    extra DOUBLE PRECISION,
    mta_tax DOUBLE PRECISION,
    tip_amount DOUBLE PRECISION,
    tolls_amount DOUBLE PRECISION,
    improvement_surcharge DOUBLE PRECISION,
    total_amount DOUBLE PRECISION,
    congestion_surcharge DOUBLE PRECISION,
    airport_fee DOUBLE PRECISION,
    cbd_congestion_fee DOUBLE PRECISION,

    loaded_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_taxi_trips_ingestion
        FOREIGN KEY (ingestion_id)
        REFERENCES raw.ingestion_log (ingestion_id)
);


CREATE INDEX IF NOT EXISTS idx_raw_taxi_trips_ingestion_id
    ON raw.taxi_trips (ingestion_id);