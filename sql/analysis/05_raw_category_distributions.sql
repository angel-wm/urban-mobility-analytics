SELECT
    payment_type,
    COUNT(*) AS trip_count
FROM raw.taxi_trips
WHERE ingestion_id = 7
GROUP BY payment_type
ORDER BY trip_count DESC;

SELECT
    passenger_count,
    COUNT(*) AS trip_count
FROM raw.taxi_trips
WHERE ingestion_id = 7
GROUP BY passenger_count
ORDER BY passenger_count;

SELECT
    ratecode_id,
    COUNT(*) AS trip_count
FROM raw.taxi_trips
WHERE ingestion_id = 7
GROUP BY ratecode_id
ORDER BY ratecode_id;