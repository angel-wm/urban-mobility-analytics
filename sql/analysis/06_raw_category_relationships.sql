SELECT
    COUNT(*) AS payment_type_zero_and_both_null
FROM raw.taxi_trips
WHERE ingestion_id = 7
    AND payment_type = 0
    AND passenger_count IS NULL
    AND ratecode_id IS NULL;

SELECT
    COUNT(*) AS payment_type_zero_with_any_value
FROM raw.taxi_trips
WHERE ingestion_id = 7
    AND payment_type = 0
    AND (
        passenger_count IS NOT NULL
        OR ratecode_id IS NOT NULL
    );

SELECT
    COUNT(*) AS nonzero_payment_type_with_any_null
FROM raw.taxi_trips
WHERE ingestion_id = 7
    AND payment_type <> 0
    AND (
        passenger_count IS NULL
        OR ratecode_id IS NULL
    );