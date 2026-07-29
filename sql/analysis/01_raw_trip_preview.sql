SELECT
    raw_trip_id,
    ingestion_id,
    pickup_datetime,
    dropoff_datetime,
    passenger_count,
    trip_distance,
    total_amount
FROM raw.taxi_trips
WHERE ingestion_id = 7
ORDER BY raw_trip_id
LIMIT 10;