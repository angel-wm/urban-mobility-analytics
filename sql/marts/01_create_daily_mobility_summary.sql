BEGIN;


CREATE OR REPLACE VIEW marts.daily_mobility_summary AS
WITH daily_metrics AS (
    SELECT
        ingestion_id,
        source_file_name,
        taxi_type,
        period_year,
        period_month,
        pickup_date,
        trip_count,
        operational_issue_trip_count,
        suspicious_condition_trip_count,
        any_quality_flag_trip_count,
        negative_transaction_trip_count,
        valid_speed_trip_count,
        total_trip_distance,
        average_trip_distance,
        average_trip_duration_minutes,
        average_speed_mph,
        positive_total_amount,
        negative_total_amount,
        net_total_amount,
        average_total_amount
    FROM analytics.daily_trip_metrics
),

window_metrics AS (
    SELECT
        ingestion_id,
        source_file_name,
        taxi_type,
        period_year,
        period_month,
        pickup_date,
        trip_count,
        operational_issue_trip_count,
        suspicious_condition_trip_count,
        any_quality_flag_trip_count,
        negative_transaction_trip_count,
        valid_speed_trip_count,
        total_trip_distance,
        average_trip_distance,
        average_trip_duration_minutes,
        average_speed_mph,
        positive_total_amount,
        negative_total_amount,
        net_total_amount,
        average_total_amount,

        LAG(trip_count) OVER (
            PARTITION BY ingestion_id
            ORDER BY pickup_date
        ) AS previous_day_trip_count,

        SUM(trip_count) OVER (
            PARTITION BY ingestion_id
            ORDER BY pickup_date
            ROWS BETWEEN UNBOUNDED PRECEDING
                AND CURRENT ROW
        ) AS cumulative_trip_count,

        SUM(net_total_amount) OVER (
            PARTITION BY ingestion_id
            ORDER BY pickup_date
            ROWS BETWEEN UNBOUNDED PRECEDING
                AND CURRENT ROW
        ) AS cumulative_net_total_amount,

        AVG(trip_count) OVER (
            PARTITION BY ingestion_id
            ORDER BY pickup_date
            ROWS BETWEEN 6 PRECEDING
                AND CURRENT ROW
        ) AS rolling_7_day_average_trip_count,

        RANK() OVER (
            PARTITION BY ingestion_id
            ORDER BY trip_count DESC
        ) AS trip_demand_rank,

        SUM(trip_count) OVER (
            PARTITION BY ingestion_id
        ) AS ingestion_trip_count

    FROM daily_metrics
)

SELECT
    ingestion_id,
    source_file_name,
    taxi_type,
    period_year,
    period_month,
    pickup_date,
    trip_count,
    operational_issue_trip_count,
    suspicious_condition_trip_count,
    any_quality_flag_trip_count,
    negative_transaction_trip_count,
    valid_speed_trip_count,
    total_trip_distance,
    average_trip_distance,
    average_trip_duration_minutes,
    average_speed_mph,
    positive_total_amount,
    negative_total_amount,
    net_total_amount,
    average_total_amount,
    previous_day_trip_count,

    (
        trip_count
        - previous_day_trip_count
    ) AS daily_trip_count_change,

    CASE
        WHEN previous_day_trip_count IS NULL
            OR previous_day_trip_count = 0
        THEN NULL
        ELSE ROUND(
            (
                (
                    trip_count
                    - previous_day_trip_count
                )::NUMERIC
                / previous_day_trip_count
            ) * 100,
            2
        )::NUMERIC(12, 2)
    END AS daily_trip_count_change_percentage,

    cumulative_trip_count::BIGINT
        AS cumulative_trip_count,

    ROUND(
        cumulative_net_total_amount,
        2
    )::NUMERIC(18, 2)
        AS cumulative_net_total_amount,

    ROUND(
        rolling_7_day_average_trip_count,
        2
    )::NUMERIC(12, 2)
        AS rolling_7_day_average_trip_count,

    trip_demand_rank,

    ROUND(
        (
            trip_count::NUMERIC
            / NULLIF(
                ingestion_trip_count,
                0
            )
        ) * 100,
        4
    )::NUMERIC(8, 4)
        AS period_trip_share_percentage

FROM window_metrics;


COMMIT;