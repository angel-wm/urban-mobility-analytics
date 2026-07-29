SELECT
    COUNT(*) AS total_raw_trip_rows
FROM raw.taxi_trips;

SELECT
    COUNT(*) AS sample_trip_rows
FROM raw.taxi_trips
WHERE ingestion_id = 1;

SELECT
    COUNT(*) AS january_2025_trip_rows
FROM raw.taxi_trips
WHERE ingestion_id = 7;