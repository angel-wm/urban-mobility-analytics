SELECT
    MAX(ABS(fare_amount)) AS max_abs_fare_amount,
    MAX(ABS(extra)) AS max_abs_extra,
    MAX(ABS(mta_tax)) AS max_abs_mta_tax,
    MAX(ABS(tip_amount)) AS max_abs_tip_amount,
    MAX(ABS(tolls_amount)) AS max_abs_tolls_amount,
    MAX(ABS(improvement_surcharge)) AS max_abs_improvement_surcharge,
    MAX(ABS(total_amount)) AS max_abs_total_amount,
    MAX(ABS(congestion_surcharge)) AS max_abs_congestion_surcharge,
    MAX(ABS(airport_fee)) AS max_abs_airport_fee,
    MAX(ABS(cbd_congestion_fee)) AS max_abs_cbd_congestion_fee
FROM raw.taxi_trips
WHERE ingestion_id = 7;


SELECT
    COUNT(*) FILTER (
        WHERE fare_amount IS NOT NULL
            AND fare_amount::NUMERIC
                <> ROUND(fare_amount::NUMERIC, 2)
    ) AS fare_amount_over_2_decimals,

    COUNT(*) FILTER (
        WHERE extra IS NOT NULL
            AND extra::NUMERIC
                <> ROUND(extra::NUMERIC, 2)
    ) AS extra_over_2_decimals,

    COUNT(*) FILTER (
        WHERE mta_tax IS NOT NULL
            AND mta_tax::NUMERIC
                <> ROUND(mta_tax::NUMERIC, 2)
    ) AS mta_tax_over_2_decimals,

    COUNT(*) FILTER (
        WHERE tip_amount IS NOT NULL
            AND tip_amount::NUMERIC
                <> ROUND(tip_amount::NUMERIC, 2)
    ) AS tip_amount_over_2_decimals,

    COUNT(*) FILTER (
        WHERE tolls_amount IS NOT NULL
            AND tolls_amount::NUMERIC
                <> ROUND(tolls_amount::NUMERIC, 2)
    ) AS tolls_amount_over_2_decimals,

    COUNT(*) FILTER (
        WHERE improvement_surcharge IS NOT NULL
            AND improvement_surcharge::NUMERIC
                <> ROUND(
                    improvement_surcharge::NUMERIC,
                    2
                )
    ) AS improvement_surcharge_over_2_decimals,

    COUNT(*) FILTER (
        WHERE total_amount IS NOT NULL
            AND total_amount::NUMERIC
                <> ROUND(total_amount::NUMERIC, 2)
    ) AS total_amount_over_2_decimals,

    COUNT(*) FILTER (
        WHERE congestion_surcharge IS NOT NULL
            AND congestion_surcharge::NUMERIC
                <> ROUND(
                    congestion_surcharge::NUMERIC,
                    2
                )
    ) AS congestion_surcharge_over_2_decimals,

    COUNT(*) FILTER (
        WHERE airport_fee IS NOT NULL
            AND airport_fee::NUMERIC
                <> ROUND(airport_fee::NUMERIC, 2)
    ) AS airport_fee_over_2_decimals,

    COUNT(*) FILTER (
        WHERE cbd_congestion_fee IS NOT NULL
            AND cbd_congestion_fee::NUMERIC
                <> ROUND(
                    cbd_congestion_fee::NUMERIC,
                    2
                )
    ) AS cbd_congestion_fee_over_2_decimals
FROM raw.taxi_trips
WHERE ingestion_id = 7;