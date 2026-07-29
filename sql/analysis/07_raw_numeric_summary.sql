SELECT
    COUNT(*) AS total_rows,
    MIN(trip_distance) AS minimum_trip_distance,
    MAX(trip_distance) AS maximum_trip_distance,
    AVG(trip_distance) AS average_trip_distance,
    SUM(trip_distance) AS total_trip_distance
FROM raw.taxi_trips
WHERE ingestion_id = 7;

SELECT
    MIN(fare_amount) AS minimum_fare_amount,
    MAX(fare_amount) AS maximum_fare_amount,
    AVG(fare_amount) AS average_fare_amount,
    SUM(fare_amount) AS total_fare_amount
FROM raw.taxi_trips
WHERE ingestion_id = 7;

SELECT
    MIN(total_amount) AS minimum_total_amount,
    MAX(total_amount) AS maximum_total_amount,
    AVG(total_amount) AS average_total_amount,
    SUM(total_amount) AS total_amount_sum
FROM raw.taxi_trips
WHERE ingestion_id = 7;