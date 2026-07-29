SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(fare_amount) AS fare_amount_null_rows,
    COUNT(*) - COUNT(total_amount) AS total_amount_null_rows
FROM raw.taxi_trips
WHERE ingestion_id = 7;

SELECT
    COUNT(*) AS both_amounts_negative
FROM raw.taxi_trips
WHERE ingestion_id = 7
    AND fare_amount < 0
    AND total_amount < 0;

SELECT
    COUNT(*) AS negative_fare_nonnegative_total
FROM raw.taxi_trips
WHERE ingestion_id = 7
    AND fare_amount < 0
    AND total_amount >= 0;

SELECT
    COUNT(*) AS nonnegative_fare_negative_total
FROM raw.taxi_trips
WHERE ingestion_id = 7
    AND fare_amount >= 0
    AND total_amount < 0;