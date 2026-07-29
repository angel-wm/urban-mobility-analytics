SELECT
    CASE
        WHEN store_and_fwd_flag IS NULL THEN '[NULL]'
        WHEN store_and_fwd_flag = '' THEN '[EMPTY STRING]'
        ELSE store_and_fwd_flag
    END AS store_and_fwd_value,
    COUNT(*) AS trip_count
FROM raw.taxi_trips
WHERE ingestion_id = 7
GROUP BY
    CASE
        WHEN store_and_fwd_flag IS NULL THEN '[NULL]'
        WHEN store_and_fwd_flag = '' THEN '[EMPTY STRING]'
        ELSE store_and_fwd_flag
    END
ORDER BY trip_count DESC;

SELECT
    vendor_id,
    COUNT(*) AS trip_count
FROM raw.taxi_trips
WHERE ingestion_id = 7
GROUP BY vendor_id
HAVING COUNT(*) < 2_000
ORDER BY trip_count;

SELECT
    payment_type,
    COUNT(*) AS trip_count
FROM raw.taxi_trips
WHERE ingestion_id = 7
GROUP BY payment_type
HAVING COUNT(*) < 100_000
ORDER BY trip_count;