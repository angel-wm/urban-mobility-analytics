SELECT
    MIN(pickup_datetime) AS minimum_pickup_datetime,
    MAX(pickup_datetime) AS maximum_pickup_datetime,
    MIN(dropoff_datetime) AS minimum_dropoff_datetime,
    MAX(dropoff_datetime) AS maximum_dropoff_datetime
FROM raw.taxi_trips
WHERE ingestion_id = 7;

SELECT
    COUNT(*) AS total_rows,
    SUM(
        CASE
            WHEN pickup_datetime < TIMESTAMP '2025-01-01 00:00:00'
                THEN 1
            ELSE 0
        END
    ) AS pickup_before_january,
    SUM(
        CASE
            WHEN pickup_datetime >= TIMESTAMP '2025-01-01 00:00:00'
                AND pickup_datetime < TIMESTAMP '2025-02-01 00:00:00'
                THEN 1
            ELSE 0
        END
    ) AS pickup_during_january,
    SUM(
        CASE
            WHEN pickup_datetime >= TIMESTAMP '2025-02-01 00:00:00'
                THEN 1
            ELSE 0
        END
    ) AS pickup_after_january
FROM raw.taxi_trips
WHERE ingestion_id = 7;

SELECT
    COUNT(*) - COUNT(pickup_datetime) AS pickup_datetime_null_rows,
    COUNT(*) - COUNT(dropoff_datetime) AS dropoff_datetime_null_rows,
    SUM(
        CASE
            WHEN dropoff_datetime <= pickup_datetime
                THEN 1
            ELSE 0
        END
    ) AS nonpositive_duration_rows,
    SUM(
        CASE
            WHEN dropoff_datetime - pickup_datetime > INTERVAL '24 hours'
                THEN 1
            ELSE 0
        END
    ) AS duration_over_24_hours_rows
FROM raw.taxi_trips
WHERE ingestion_id = 7;

SELECT
    raw_trip_id,
    pickup_datetime,
    dropoff_datetime,
    dropoff_datetime - pickup_datetime AS trip_duration,
    trip_distance,
    total_amount
FROM raw.taxi_trips
WHERE ingestion_id = 7
    AND dropoff_datetime <= pickup_datetime
ORDER BY trip_duration, raw_trip_id
LIMIT 10;