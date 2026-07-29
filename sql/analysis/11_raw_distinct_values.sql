SELECT DISTINCT
    vendor_id
FROM raw.taxi_trips
WHERE ingestion_id = 7
ORDER BY vendor_id;

SELECT DISTINCT
    store_and_fwd_flag
FROM raw.taxi_trips
WHERE ingestion_id = 7
ORDER BY store_and_fwd_flag;

SELECT DISTINCT
    payment_type
FROM raw.taxi_trips
WHERE ingestion_id = 7
ORDER BY payment_type;

SELECT
    vendor_id,
    payment_type,
    COUNT(*) AS trip_count
FROM raw.taxi_trips
WHERE ingestion_id = 7
GROUP BY
    vendor_id,
    payment_type
ORDER BY
    vendor_id,
    payment_type;