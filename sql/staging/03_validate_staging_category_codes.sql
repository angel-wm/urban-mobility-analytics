SELECT
    'vendor_id' AS field_name,
    COALESCE(
        vendor_id::TEXT,
        'NULL'
    ) AS field_value,
    COUNT(*) AS row_count
FROM staging.taxi_trips
WHERE ingestion_id = 7
GROUP BY vendor_id

UNION ALL

SELECT
    'ratecode_id' AS field_name,
    COALESCE(
        ratecode_id::TEXT,
        'NULL'
    ) AS field_value,
    COUNT(*) AS row_count
FROM staging.taxi_trips
WHERE ingestion_id = 7
GROUP BY ratecode_id

UNION ALL

SELECT
    'payment_type' AS field_name,
    COALESCE(
        payment_type::TEXT,
        'NULL'
    ) AS field_value,
    COUNT(*) AS row_count
FROM staging.taxi_trips
WHERE ingestion_id = 7
GROUP BY payment_type

UNION ALL

SELECT
    'store_and_fwd_flag' AS field_name,
    COALESCE(
        store_and_fwd_flag,
        'NULL'
    ) AS field_value,
    COUNT(*) AS row_count
FROM staging.taxi_trips
WHERE ingestion_id = 7
GROUP BY store_and_fwd_flag

ORDER BY
    field_name,
    field_value;


SELECT
    COUNT(*) FILTER (
        WHERE vendor_id IS NOT NULL
            AND vendor_id NOT IN (1, 2, 6, 7)
    ) AS unrecognized_vendor_rows,

    COUNT(*) FILTER (
        WHERE ratecode_id IS NOT NULL
            AND ratecode_id NOT IN (
                1,
                2,
                3,
                4,
                5,
                6,
                99
            )
    ) AS unrecognized_ratecode_rows,

    COUNT(*) FILTER (
        WHERE payment_type IS NOT NULL
            AND payment_type NOT IN (
                0,
                1,
                2,
                3,
                4,
                5,
                6
            )
    ) AS unrecognized_payment_type_rows,

    COUNT(*) FILTER (
        WHERE store_and_fwd_flag IS NOT NULL
            AND store_and_fwd_flag NOT IN ('Y', 'N')
    ) AS unrecognized_store_and_fwd_rows,

    COUNT(*) FILTER (
        WHERE ratecode_id = 99
    ) AS documented_unknown_ratecode_rows,

    COUNT(*) FILTER (
        WHERE payment_type = 5
    ) AS documented_unknown_payment_rows

FROM staging.taxi_trips
WHERE ingestion_id = 7;