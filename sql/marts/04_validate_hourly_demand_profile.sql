-- Validate the grain and represented hour range.

SELECT
    ingestion_id,
    COUNT(*) AS mart_row_count,
    COUNT(DISTINCT pickup_hour) AS distinct_pickup_hours,
    SUM(trip_count) AS represented_trip_count,
    MIN(pickup_hour) AS first_pickup_hour,
    MAX(pickup_hour) AS last_pickup_hour
FROM marts.hourly_demand_profile
GROUP BY ingestion_id
ORDER BY ingestion_id;


-- A result from this query indicates a grain violation.

SELECT
    ingestion_id,
    pickup_hour,
    COUNT(*) AS row_count
FROM marts.hourly_demand_profile
GROUP BY
    ingestion_id,
    pickup_hour
HAVING COUNT(*) <> 1
ORDER BY
    ingestion_id,
    pickup_hour;


-- Reconcile the mart base metrics against hourly analytics.

WITH expected_metrics AS (
    SELECT
        ingestion_id,
        pickup_hour,

        COUNT(DISTINCT pickup_date)
            AS represented_day_count,

        SUM(trip_count)::BIGINT
            AS trip_count,

        SUM(
            operational_issue_trip_count
        )::BIGINT AS operational_issue_trip_count,

        SUM(
            suspicious_condition_trip_count
        )::BIGINT AS suspicious_condition_trip_count,

        SUM(
            any_quality_flag_trip_count
        )::BIGINT AS any_quality_flag_trip_count,

        SUM(
            negative_transaction_trip_count
        )::BIGINT AS negative_transaction_trip_count,

        SUM(
            valid_speed_trip_count
        )::BIGINT AS valid_speed_trip_count,

        SUM(
            positive_total_amount
        )::NUMERIC(18, 2)
            AS positive_total_amount,

        SUM(
            negative_total_amount
        )::NUMERIC(18, 2)
            AS negative_total_amount,

        SUM(
            net_total_amount
        )::NUMERIC(18, 2)
            AS net_total_amount

    FROM analytics.hourly_trip_metrics
    GROUP BY
        ingestion_id,
        pickup_hour
)

SELECT
    COALESCE(
        e.ingestion_id,
        m.ingestion_id
    ) AS ingestion_id,

    COALESCE(
        e.pickup_hour,
        m.pickup_hour
    ) AS pickup_hour,

    m.represented_day_count
        - e.represented_day_count
        AS represented_day_count_difference,

    m.trip_count
        - e.trip_count
        AS trip_count_difference,

    m.operational_issue_trip_count
        - e.operational_issue_trip_count
        AS operational_issue_difference,

    m.suspicious_condition_trip_count
        - e.suspicious_condition_trip_count
        AS suspicious_condition_difference,

    m.any_quality_flag_trip_count
        - e.any_quality_flag_trip_count
        AS any_quality_flag_difference,

    m.negative_transaction_trip_count
        - e.negative_transaction_trip_count
        AS negative_transaction_difference,

    m.valid_speed_trip_count
        - e.valid_speed_trip_count
        AS valid_speed_difference,

    m.positive_total_amount
        - e.positive_total_amount
        AS positive_total_amount_difference,

    m.negative_total_amount
        - e.negative_total_amount
        AS negative_total_amount_difference,

    m.net_total_amount
        - e.net_total_amount
        AS net_total_amount_difference

FROM expected_metrics AS e
FULL OUTER JOIN marts.hourly_demand_profile AS m
    ON e.ingestion_id = m.ingestion_id
    AND e.pickup_hour = m.pickup_hour
WHERE
    m.represented_day_count
        IS DISTINCT FROM e.represented_day_count

    OR m.trip_count
        IS DISTINCT FROM e.trip_count

    OR m.operational_issue_trip_count
        IS DISTINCT FROM e.operational_issue_trip_count

    OR m.suspicious_condition_trip_count
        IS DISTINCT FROM e.suspicious_condition_trip_count

    OR m.any_quality_flag_trip_count
        IS DISTINCT FROM e.any_quality_flag_trip_count

    OR m.negative_transaction_trip_count
        IS DISTINCT FROM e.negative_transaction_trip_count

    OR m.valid_speed_trip_count
        IS DISTINCT FROM e.valid_speed_trip_count

    OR m.positive_total_amount
        IS DISTINCT FROM e.positive_total_amount

    OR m.negative_total_amount
        IS DISTINCT FROM e.negative_total_amount

    OR m.net_total_amount
        IS DISTINCT FROM e.net_total_amount
ORDER BY
    ingestion_id,
    pickup_hour;


-- Recalculate derived and window metrics.

WITH hourly_totals AS (
    SELECT
        ingestion_id,
        pickup_hour,

        COUNT(DISTINCT pickup_date)
            AS represented_day_count,

        SUM(trip_count)::BIGINT
            AS trip_count,

        SUM(
            operational_issue_trip_count
        )::BIGINT AS operational_issue_trip_count,

        SUM(
            suspicious_condition_trip_count
        )::BIGINT AS suspicious_condition_trip_count,

        SUM(
            any_quality_flag_trip_count
        )::BIGINT AS any_quality_flag_trip_count,

        SUM(
            negative_transaction_trip_count
        )::BIGINT AS negative_transaction_trip_count,

        SUM(
            net_total_amount
        )::NUMERIC(18, 2)
            AS net_total_amount

    FROM analytics.hourly_trip_metrics
    GROUP BY
        ingestion_id,
        pickup_hour
),

window_metrics AS (
    SELECT
        ingestion_id,
        pickup_hour,
        represented_day_count,
        trip_count,
        operational_issue_trip_count,
        suspicious_condition_trip_count,
        any_quality_flag_trip_count,
        negative_transaction_trip_count,
        net_total_amount,

        LAG(trip_count) OVER (
            PARTITION BY ingestion_id
            ORDER BY pickup_hour
        ) AS previous_hour_trip_count,

        SUM(trip_count) OVER (
            PARTITION BY ingestion_id
            ORDER BY pickup_hour
            ROWS BETWEEN UNBOUNDED PRECEDING
                AND CURRENT ROW
        )::BIGINT AS cumulative_trip_count,

        ROUND(
            AVG(trip_count) OVER (
                PARTITION BY ingestion_id
                ORDER BY pickup_hour
                ROWS BETWEEN 2 PRECEDING
                    AND CURRENT ROW
            ),
            2
        )::NUMERIC(12, 2)
            AS rolling_3_hour_average_trip_count,

        RANK() OVER (
            PARTITION BY ingestion_id
            ORDER BY trip_count DESC
        ) AS demand_rank,

        SUM(trip_count) OVER (
            PARTITION BY ingestion_id
        ) AS ingestion_trip_count

    FROM hourly_totals
),

expected_metrics AS (
    SELECT
        ingestion_id,
        pickup_hour,

        ROUND(
            trip_count::NUMERIC
            / NULLIF(
                represented_day_count,
                0
            ),
            2
        )::NUMERIC(12, 2)
            AS average_daily_trip_count,

        ROUND(
            (
                operational_issue_trip_count::NUMERIC
                / NULLIF(
                    trip_count,
                    0
                )
            ) * 100,
            4
        )::NUMERIC(8, 4)
            AS operational_issue_percentage,

        ROUND(
            (
                suspicious_condition_trip_count::NUMERIC
                / NULLIF(
                    trip_count,
                    0
                )
            ) * 100,
            4
        )::NUMERIC(8, 4)
            AS suspicious_condition_percentage,

        ROUND(
            (
                any_quality_flag_trip_count::NUMERIC
                / NULLIF(
                    trip_count,
                    0
                )
            ) * 100,
            4
        )::NUMERIC(8, 4)
            AS any_quality_flag_percentage,

        ROUND(
            (
                negative_transaction_trip_count::NUMERIC
                / NULLIF(
                    trip_count,
                    0
                )
            ) * 100,
            4
        )::NUMERIC(8, 4)
            AS negative_transaction_percentage,

        ROUND(
            net_total_amount
            / NULLIF(
                trip_count,
                0
            ),
            2
        )::NUMERIC(12, 2)
            AS average_net_total_amount_per_trip,

        previous_hour_trip_count,

        (
            trip_count
            - previous_hour_trip_count
        ) AS hourly_trip_count_change,

        CASE
            WHEN previous_hour_trip_count IS NULL
                OR previous_hour_trip_count = 0
            THEN NULL
            ELSE ROUND(
                (
                    (
                        trip_count
                        - previous_hour_trip_count
                    )::NUMERIC
                    / previous_hour_trip_count
                ) * 100,
                2
            )::NUMERIC(12, 2)
        END AS hourly_trip_count_change_percentage,

        cumulative_trip_count,
        rolling_3_hour_average_trip_count,
        demand_rank,

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

    FROM window_metrics
)

SELECT
    COALESCE(
        e.ingestion_id,
        m.ingestion_id
    ) AS ingestion_id,

    COALESCE(
        e.pickup_hour,
        m.pickup_hour
    ) AS pickup_hour

FROM expected_metrics AS e
FULL OUTER JOIN marts.hourly_demand_profile AS m
    ON e.ingestion_id = m.ingestion_id
    AND e.pickup_hour = m.pickup_hour
WHERE
    m.average_daily_trip_count
        IS DISTINCT FROM e.average_daily_trip_count

    OR m.operational_issue_percentage
        IS DISTINCT FROM e.operational_issue_percentage

    OR m.suspicious_condition_percentage
        IS DISTINCT FROM e.suspicious_condition_percentage

    OR m.any_quality_flag_percentage
        IS DISTINCT FROM e.any_quality_flag_percentage

    OR m.negative_transaction_percentage
        IS DISTINCT FROM e.negative_transaction_percentage

    OR m.average_net_total_amount_per_trip
        IS DISTINCT FROM
        e.average_net_total_amount_per_trip

    OR m.previous_hour_trip_count
        IS DISTINCT FROM e.previous_hour_trip_count

    OR m.hourly_trip_count_change
        IS DISTINCT FROM e.hourly_trip_count_change

    OR m.hourly_trip_count_change_percentage
        IS DISTINCT FROM
        e.hourly_trip_count_change_percentage

    OR m.cumulative_trip_count
        IS DISTINCT FROM e.cumulative_trip_count

    OR m.rolling_3_hour_average_trip_count
        IS DISTINCT FROM
        e.rolling_3_hour_average_trip_count

    OR m.demand_rank
        IS DISTINCT FROM e.demand_rank

    OR m.period_trip_share_percentage
        IS DISTINCT FROM
        e.period_trip_share_percentage
ORDER BY
    ingestion_id,
    pickup_hour;


-- Validate monetary identities and valid percentages.

SELECT
    ingestion_id,
    pickup_hour
FROM marts.hourly_demand_profile
WHERE positive_total_amount
        + negative_total_amount
        <> net_total_amount

    OR operational_issue_percentage
        NOT BETWEEN 0 AND 100

    OR suspicious_condition_percentage
        NOT BETWEEN 0 AND 100

    OR any_quality_flag_percentage
        NOT BETWEEN 0 AND 100

    OR negative_transaction_percentage
        NOT BETWEEN 0 AND 100

    OR period_trip_share_percentage
        NOT BETWEEN 0 AND 100
ORDER BY
    ingestion_id,
    pickup_hour;


-- Validate final cumulative values and rounded shares.

SELECT
    ingestion_id,
    COUNT(*) AS represented_hours,
    SUM(trip_count) AS represented_trips,

    MAX(cumulative_trip_count) FILTER (
        WHERE pickup_hour = 23
    ) AS final_cumulative_trip_count,

    SUM(net_total_amount)
        AS expected_net_total_amount,

    SUM(period_trip_share_percentage)
        AS rounded_period_trip_share_percentage,

    MIN(demand_rank) AS best_demand_rank,
    MAX(demand_rank) AS lowest_demand_rank

FROM marts.hourly_demand_profile
GROUP BY ingestion_id
ORDER BY ingestion_id;


-- Validate the known complete January 2025 ingestion.

SELECT
    ingestion_id,
    COUNT(*) AS represented_hours,
    SUM(trip_count) AS represented_trips,
    MIN(pickup_hour) AS first_pickup_hour,
    MAX(pickup_hour) AS last_pickup_hour,

    MAX(cumulative_trip_count) FILTER (
        WHERE pickup_hour = 23
    ) AS final_cumulative_trip_count,

    MAX(pickup_hour) FILTER (
        WHERE demand_rank = 1
    ) AS highest_demand_hour,

    MAX(trip_count) FILTER (
        WHERE demand_rank = 1
    ) AS highest_demand_trip_count

FROM marts.hourly_demand_profile
WHERE ingestion_id = 7
GROUP BY ingestion_id;