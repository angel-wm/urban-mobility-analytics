SELECT
    COUNT(*) AS total_rows,
    SUM(
        CASE
            WHEN trip_distance = 0 THEN 1
            ELSE 0
        END
    ) AS zero_distance_rows,
    SUM(
        CASE
            WHEN trip_distance > 100 THEN 1
            ELSE 0
        END
    ) AS distance_over_100_rows,
    SUM(
        CASE
            WHEN trip_distance > 1_000 THEN 1
            ELSE 0
        END
    ) AS distance_over_1000_rows
FROM raw.taxi_trips
WHERE ingestion_id = 7;

SELECT
    SUM(
        CASE
            WHEN fare_amount < 0 THEN 1
            ELSE 0
        END
    ) AS negative_fare_rows,
    SUM(
        CASE
            WHEN fare_amount = 0 THEN 1
            ELSE 0
        END
    ) AS zero_fare_rows,
    SUM(
        CASE
            WHEN fare_amount > 1_000 THEN 1
            ELSE 0
        END
    ) AS fare_over_1000_rows
FROM raw.taxi_trips
WHERE ingestion_id = 7;

SELECT
    SUM(
        CASE
            WHEN total_amount < 0 THEN 1
            ELSE 0
        END
    ) AS negative_total_rows,
    SUM(
        CASE
            WHEN total_amount = 0 THEN 1
            ELSE 0
        END
    ) AS zero_total_rows,
    SUM(
        CASE
            WHEN total_amount > 1_000 THEN 1
            ELSE 0
        END
    ) AS total_over_1000_rows
FROM raw.taxi_trips
WHERE ingestion_id = 7;