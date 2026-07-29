SELECT
    raw_trip_id,
    vendor_id,
    pickup_datetime,
    passenger_count,
    ratecode_id,
    payment_type
FROM raw.taxi_trips
WHERE ingestion_id = 7
    AND passenger_count IS NULL
ORDER BY raw_trip_id
LIMIT 10;

SELECT
    COUNT(*) AS both_columns_null
FROM raw.taxi_trips
WHERE ingestion_id = 7
    AND passenger_count IS NULL
    AND ratecode_id IS NULL;

SELECT
    COUNT(*) AS only_passenger_count_null
FROM raw.taxi_trips
WHERE ingestion_id = 7
    AND passenger_count IS NULL
    AND ratecode_id IS NOT NULL;

SELECT
    COUNT(*) AS only_ratecode_id_null
FROM raw.taxi_trips
WHERE ingestion_id = 7
    AND passenger_count IS NOT NULL
    AND ratecode_id IS NULL;