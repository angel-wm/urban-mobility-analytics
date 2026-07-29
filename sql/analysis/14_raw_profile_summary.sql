SELECT
    COUNT(*) AS total_rows,

    SUM(
        CASE
            WHEN payment_type = 0 THEN 1
            ELSE 0
        END
    ) AS payment_type_zero_rows,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN payment_type = 0 THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        4
    ) AS payment_type_zero_percentage,

    SUM(
        CASE
            WHEN trip_distance = 0 THEN 1
            ELSE 0
        END
    ) AS zero_distance_rows,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN trip_distance = 0 THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        4
    ) AS zero_distance_percentage,

    SUM(
        CASE
            WHEN fare_amount < 0 THEN 1
            ELSE 0
        END
    ) AS negative_fare_rows,

    SUM(
        CASE
            WHEN total_amount < 0 THEN 1
            ELSE 0
        END
    ) AS negative_total_rows,

    SUM(
        CASE
            WHEN dropoff_datetime <= pickup_datetime THEN 1
            ELSE 0
        END
    ) AS nonpositive_duration_rows,

    SUM(
        CASE
            WHEN dropoff_datetime - pickup_datetime > INTERVAL '24 hours'
                THEN 1
            ELSE 0
        END
    ) AS duration_over_24_hours_rows,

    SUM(
        CASE
            WHEN pickup_datetime < TIMESTAMP '2025-01-01 00:00:00'
                OR pickup_datetime >= TIMESTAMP '2025-02-01 00:00:00'
                THEN 1
            ELSE 0
        END
    ) AS pickup_outside_january_rows

FROM raw.taxi_trips
WHERE ingestion_id = 7;