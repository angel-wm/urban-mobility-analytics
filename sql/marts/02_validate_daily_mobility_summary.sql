-- Validate the grain and represented date range.

SELECT
    ingestion_id,
    COUNT(*) AS mart_row_count,
    COUNT(DISTINCT pickup_date) AS distinct_pickup_dates,
    SUM(trip_count) AS represented_trip_count,
    MIN(pickup_date) AS first_pickup_date,
    MAX(pickup_date) AS last_pickup_date
FROM marts.daily_mobility_summary
GROUP BY ingestion_id
ORDER BY ingestion_id;


-- A result from this query indicates a grain violation.

SELECT
    ingestion_id,
    pickup_date,
    COUNT(*) AS row_count
FROM marts.daily_mobility_summary
GROUP BY
    ingestion_id,
    pickup_date
HAVING COUNT(*) <> 1
ORDER BY
    ingestion_id,
    pickup_date;


-- Reconcile the mart base metrics against the analytics layer.

WITH analytics_totals AS (
    SELECT
        ingestion_id,
        COUNT(*) AS expected_day_count,
        SUM(trip_count) AS expected_trip_count,
        SUM(
            operational_issue_trip_count
        ) AS expected_operational_issue_trip_count,
        SUM(
            suspicious_condition_trip_count
        ) AS expected_suspicious_condition_trip_count,
        SUM(
            any_quality_flag_trip_count
        ) AS expected_any_quality_flag_trip_count,
        SUM(
            negative_transaction_trip_count
        ) AS expected_negative_transaction_trip_count,
        SUM(
            valid_speed_trip_count
        ) AS expected_valid_speed_trip_count,
        SUM(
            positive_total_amount
        ) AS expected_positive_total_amount,
        SUM(
            negative_total_amount
        ) AS expected_negative_total_amount,
        SUM(
            net_total_amount
        ) AS expected_net_total_amount
    FROM analytics.daily_trip_metrics
    GROUP BY ingestion_id
),

mart_totals AS (
    SELECT
        ingestion_id,
        COUNT(*) AS actual_day_count,
        SUM(trip_count) AS actual_trip_count,
        SUM(
            operational_issue_trip_count
        ) AS actual_operational_issue_trip_count,
        SUM(
            suspicious_condition_trip_count
        ) AS actual_suspicious_condition_trip_count,
        SUM(
            any_quality_flag_trip_count
        ) AS actual_any_quality_flag_trip_count,
        SUM(
            negative_transaction_trip_count
        ) AS actual_negative_transaction_trip_count,
        SUM(
            valid_speed_trip_count
        ) AS actual_valid_speed_trip_count,
        SUM(
            positive_total_amount
        ) AS actual_positive_total_amount,
        SUM(
            negative_total_amount
        ) AS actual_negative_total_amount,
        SUM(
            net_total_amount
        ) AS actual_net_total_amount
    FROM marts.daily_mobility_summary
    GROUP BY ingestion_id
)

SELECT
    COALESCE(
        a.ingestion_id,
        m.ingestion_id
    ) AS ingestion_id,

    m.actual_day_count
        - a.expected_day_count
        AS day_count_difference,

    m.actual_trip_count
        - a.expected_trip_count
        AS trip_count_difference,

    m.actual_operational_issue_trip_count
        - a.expected_operational_issue_trip_count
        AS operational_issue_difference,

    m.actual_suspicious_condition_trip_count
        - a.expected_suspicious_condition_trip_count
        AS suspicious_condition_difference,

    m.actual_any_quality_flag_trip_count
        - a.expected_any_quality_flag_trip_count
        AS any_quality_flag_difference,

    m.actual_negative_transaction_trip_count
        - a.expected_negative_transaction_trip_count
        AS negative_transaction_difference,

    m.actual_valid_speed_trip_count
        - a.expected_valid_speed_trip_count
        AS valid_speed_difference,

    m.actual_positive_total_amount
        - a.expected_positive_total_amount
        AS positive_total_amount_difference,

    m.actual_negative_total_amount
        - a.expected_negative_total_amount
        AS negative_total_amount_difference,

    m.actual_net_total_amount
        - a.expected_net_total_amount
        AS net_total_amount_difference

FROM analytics_totals AS a
FULL OUTER JOIN mart_totals AS m
    ON a.ingestion_id = m.ingestion_id
ORDER BY ingestion_id;


-- Recalculate all window metrics from the analytics layer.

WITH base_metrics AS (
    SELECT
        ingestion_id,
        pickup_date,
        trip_count,
        net_total_amount,

        LAG(trip_count) OVER (
            PARTITION BY ingestion_id
            ORDER BY pickup_date
        ) AS expected_previous_day_trip_count,

        SUM(trip_count) OVER (
            PARTITION BY ingestion_id
            ORDER BY pickup_date
            ROWS BETWEEN UNBOUNDED PRECEDING
                AND CURRENT ROW
        )::BIGINT AS expected_cumulative_trip_count,

        ROUND(
            SUM(net_total_amount) OVER (
                PARTITION BY ingestion_id
                ORDER BY pickup_date
                ROWS BETWEEN UNBOUNDED PRECEDING
                    AND CURRENT ROW
            ),
            2
        )::NUMERIC(18, 2)
            AS expected_cumulative_net_total_amount,

        ROUND(
            AVG(trip_count) OVER (
                PARTITION BY ingestion_id
                ORDER BY pickup_date
                ROWS BETWEEN 6 PRECEDING
                    AND CURRENT ROW
            ),
            2
        )::NUMERIC(12, 2)
            AS expected_rolling_7_day_average_trip_count,

        RANK() OVER (
            PARTITION BY ingestion_id
            ORDER BY trip_count DESC
        ) AS expected_trip_demand_rank,

        SUM(trip_count) OVER (
            PARTITION BY ingestion_id
        ) AS expected_ingestion_trip_count

    FROM analytics.daily_trip_metrics
),

expected_metrics AS (
    SELECT
        ingestion_id,
        pickup_date,
        expected_previous_day_trip_count,

        (
            trip_count
            - expected_previous_day_trip_count
        ) AS expected_daily_trip_count_change,

        CASE
            WHEN expected_previous_day_trip_count IS NULL
                OR expected_previous_day_trip_count = 0
            THEN NULL
            ELSE ROUND(
                (
                    (
                        trip_count
                        - expected_previous_day_trip_count
                    )::NUMERIC
                    / expected_previous_day_trip_count
                ) * 100,
                2
            )::NUMERIC(12, 2)
        END AS expected_daily_trip_count_change_percentage,

        expected_cumulative_trip_count,
        expected_cumulative_net_total_amount,
        expected_rolling_7_day_average_trip_count,
        expected_trip_demand_rank,

        ROUND(
            (
                trip_count::NUMERIC
                / NULLIF(
                    expected_ingestion_trip_count,
                    0
                )
            ) * 100,
            4
        )::NUMERIC(8, 4)
            AS expected_period_trip_share_percentage

    FROM base_metrics
)

SELECT
    COALESCE(
        e.ingestion_id,
        m.ingestion_id
    ) AS ingestion_id,

    COALESCE(
        e.pickup_date,
        m.pickup_date
    ) AS pickup_date,

    m.previous_day_trip_count,
    e.expected_previous_day_trip_count,

    m.daily_trip_count_change,
    e.expected_daily_trip_count_change,

    m.daily_trip_count_change_percentage,
    e.expected_daily_trip_count_change_percentage,

    m.cumulative_trip_count,
    e.expected_cumulative_trip_count,

    m.cumulative_net_total_amount,
    e.expected_cumulative_net_total_amount,

    m.rolling_7_day_average_trip_count,
    e.expected_rolling_7_day_average_trip_count,

    m.trip_demand_rank,
    e.expected_trip_demand_rank,

    m.period_trip_share_percentage,
    e.expected_period_trip_share_percentage

FROM expected_metrics AS e
FULL OUTER JOIN marts.daily_mobility_summary AS m
    ON e.ingestion_id = m.ingestion_id
    AND e.pickup_date = m.pickup_date
WHERE
    m.previous_day_trip_count
        IS DISTINCT FROM
        e.expected_previous_day_trip_count

    OR m.daily_trip_count_change
        IS DISTINCT FROM
        e.expected_daily_trip_count_change

    OR m.daily_trip_count_change_percentage
        IS DISTINCT FROM
        e.expected_daily_trip_count_change_percentage

    OR m.cumulative_trip_count
        IS DISTINCT FROM
        e.expected_cumulative_trip_count

    OR m.cumulative_net_total_amount
        IS DISTINCT FROM
        e.expected_cumulative_net_total_amount

    OR m.rolling_7_day_average_trip_count
        IS DISTINCT FROM
        e.expected_rolling_7_day_average_trip_count

    OR m.trip_demand_rank
        IS DISTINCT FROM
        e.expected_trip_demand_rank

    OR m.period_trip_share_percentage
        IS DISTINCT FROM
        e.expected_period_trip_share_percentage
ORDER BY
    ingestion_id,
    pickup_date;


-- Validate the final cumulative values and rounded period shares.

WITH final_rows AS (
    SELECT
        ingestion_id,
        pickup_date,
        cumulative_trip_count,
        cumulative_net_total_amount,

        ROW_NUMBER() OVER (
            PARTITION BY ingestion_id
            ORDER BY pickup_date DESC
        ) AS reverse_row_number

    FROM marts.daily_mobility_summary
),

period_totals AS (
    SELECT
        ingestion_id,
        SUM(trip_count) AS expected_final_trip_count,
        SUM(net_total_amount)
            AS expected_final_net_total_amount,
        SUM(period_trip_share_percentage)
            AS rounded_period_trip_share_percentage
    FROM marts.daily_mobility_summary
    GROUP BY ingestion_id
)

SELECT
    f.ingestion_id,
    f.pickup_date AS final_pickup_date,
    f.cumulative_trip_count,
    p.expected_final_trip_count,

    f.cumulative_net_total_amount,
    p.expected_final_net_total_amount,

    p.rounded_period_trip_share_percentage

FROM final_rows AS f
INNER JOIN period_totals AS p
    ON f.ingestion_id = p.ingestion_id
WHERE f.reverse_row_number = 1
ORDER BY f.ingestion_id;


-- Validate the known complete January 2025 ingestion.

SELECT
    ingestion_id,
    COUNT(*) AS represented_days,
    SUM(trip_count) AS represented_trips,
    MAX(cumulative_trip_count)
        FILTER (
            WHERE pickup_date = DATE '2025-01-31'
        ) AS final_cumulative_trip_count,
    MAX(cumulative_net_total_amount)
        FILTER (
            WHERE pickup_date = DATE '2025-01-31'
        ) AS final_cumulative_net_total_amount,
    MIN(trip_demand_rank) AS best_demand_rank,
    MAX(trip_demand_rank) AS lowest_demand_rank
FROM marts.daily_mobility_summary
WHERE ingestion_id = 7
GROUP BY ingestion_id;