SELECT
    COUNT(*) AS total_rows,
    COUNT(passenger_count) AS passenger_count_not_null,
    COUNT(*) - COUNT(passenger_count) AS passenger_count_null
FROM raw.taxi_trips
WHERE ingestion_id = 7;

SELECT
    COUNT(*) AS total_rows,
    COUNT(ratecode_id) AS ratecode_id_not_null,
    COUNT(*) - COUNT(ratecode_id) AS ratecode_id_null
FROM raw.taxi_trips
WHERE ingestion_id = 7;

SELECT
    COUNT(*) AS total_rows,
    COUNT(payment_type) AS payment_type_not_null,
    COUNT(*) - COUNT(payment_type) AS payment_type_null
FROM raw.taxi_trips
WHERE ingestion_id = 7;