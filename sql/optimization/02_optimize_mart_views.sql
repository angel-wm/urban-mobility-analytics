BEGIN;


-- Optimize the daily consumption mart by aggregating the physical fact table.
--
-- The analytics.daily_trip_metrics view remains unchanged and continues to
-- provide the original staging-based analytical model and validation baseline.

CREATE OR REPLACE VIEW marts.daily_mobility_summary AS
WITH daily_metrics AS (
    SELECT
        ft.ingestion_id,
        di.source_file_name,
        di.taxi_type,
        di.period_year,
        di.period_month,
        dd.full_date AS pickup_date,

        COUNT(*) AS trip_count,

        COUNT(*) FILTER (
            WHERE ft.has_operational_issue
        ) AS operational_issue_trip_count,

        COUNT(*) FILTER (
            WHERE ft.has_suspicious_condition
        ) AS suspicious_condition_trip_count,

        COUNT(*) FILTER (
            WHERE ft.has_any_quality_flag
        ) AS any_quality_flag_trip_count,

        COUNT(*) FILTER (
            WHERE ft.is_negative_transaction
        ) AS negative_transaction_trip_count,

        COUNT(*) FILTER (
            WHERE ft.is_valid_for_speed_analysis
        ) AS valid_speed_trip_count,

        ROUND(
            (
                SUM(ft.trip_distance) FILTER (
                    WHERE NOT ft.is_negative_distance
                )
            )::NUMERIC,
            2
        )::NUMERIC(18, 2) AS total_trip_distance,

        ROUND(
            (
                AVG(ft.trip_distance) FILTER (
                    WHERE NOT ft.is_negative_distance
                )
            )::NUMERIC,
            2
        )::NUMERIC(12, 2) AS average_trip_distance,

        ROUND(
            (
                AVG(ft.trip_duration_minutes) FILTER (
                    WHERE NOT ft.has_operational_issue
                        AND ft.trip_duration_minutes
                            <= 24 * 60
                )
            )::NUMERIC,
            2
        )::NUMERIC(12, 2)
            AS average_trip_duration_minutes,

        ROUND(
            (
                AVG(ft.average_speed_mph) FILTER (
                    WHERE ft.is_valid_for_speed_analysis
                )
            )::NUMERIC,
            2
        )::NUMERIC(12, 2) AS average_speed_mph,

        ROUND(
            COALESCE(
                SUM(ft.total_amount) FILTER (
                    WHERE ft.total_amount >= 0
                ),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2) AS positive_total_amount,

        ROUND(
            COALESCE(
                SUM(ft.total_amount) FILTER (
                    WHERE ft.total_amount < 0
                ),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2) AS negative_total_amount,

        ROUND(
            COALESCE(
                SUM(ft.total_amount),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2) AS net_total_amount,

        ROUND(
            AVG(ft.total_amount),
            2
        )::NUMERIC(12, 2) AS average_total_amount

    FROM marts.fact_trip AS ft
    INNER JOIN marts.dim_ingestion AS di
        ON ft.ingestion_id = di.ingestion_id
    INNER JOIN marts.dim_date AS dd
        ON ft.pickup_date_key = dd.date_key
    WHERE di.ingestion_status = 'completed'
        AND NOT ft.is_pickup_outside_expected_period
    GROUP BY
        ft.ingestion_id,
        di.source_file_name,
        di.taxi_type,
        di.period_year,
        di.period_month,
        dd.full_date
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


-- Optimize the hourly consumption mart by aggregating the physical fact table.
--
-- The analytics.hourly_trip_metrics view remains unchanged and continues to
-- provide the original staging-based analytical model and validation baseline.

CREATE OR REPLACE VIEW marts.hourly_demand_profile AS
WITH hourly_metrics AS (
    SELECT
        ft.ingestion_id,
        di.source_file_name,
        di.taxi_type,
        di.period_year,
        di.period_month,
        dd.full_date AS pickup_date,
        dh.hour_key AS pickup_hour,

        COUNT(*) AS trip_count,

        COUNT(*) FILTER (
            WHERE ft.has_operational_issue
        ) AS operational_issue_trip_count,

        COUNT(*) FILTER (
            WHERE ft.has_suspicious_condition
        ) AS suspicious_condition_trip_count,

        COUNT(*) FILTER (
            WHERE ft.has_any_quality_flag
        ) AS any_quality_flag_trip_count,

        COUNT(*) FILTER (
            WHERE ft.is_negative_transaction
        ) AS negative_transaction_trip_count,

        COUNT(*) FILTER (
            WHERE ft.is_valid_for_speed_analysis
        ) AS valid_speed_trip_count,

        ROUND(
            (
                SUM(ft.trip_distance) FILTER (
                    WHERE NOT ft.is_negative_distance
                )
            )::NUMERIC,
            2
        )::NUMERIC(18, 2) AS total_trip_distance,

        ROUND(
            (
                AVG(ft.trip_distance) FILTER (
                    WHERE NOT ft.is_negative_distance
                )
            )::NUMERIC,
            2
        )::NUMERIC(12, 2) AS average_trip_distance,

        ROUND(
            (
                AVG(ft.trip_duration_minutes) FILTER (
                    WHERE NOT ft.has_operational_issue
                        AND ft.trip_duration_minutes
                            <= 24 * 60
                )
            )::NUMERIC,
            2
        )::NUMERIC(12, 2)
            AS average_trip_duration_minutes,

        ROUND(
            (
                AVG(ft.average_speed_mph) FILTER (
                    WHERE ft.is_valid_for_speed_analysis
                )
            )::NUMERIC,
            2
        )::NUMERIC(12, 2) AS average_speed_mph,

        ROUND(
            COALESCE(
                SUM(ft.total_amount) FILTER (
                    WHERE ft.total_amount >= 0
                ),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2) AS positive_total_amount,

        ROUND(
            COALESCE(
                SUM(ft.total_amount) FILTER (
                    WHERE ft.total_amount < 0
                ),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2) AS negative_total_amount,

        ROUND(
            COALESCE(
                SUM(ft.total_amount),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2) AS net_total_amount,

        ROUND(
            AVG(ft.total_amount),
            2
        )::NUMERIC(12, 2) AS average_total_amount

    FROM marts.fact_trip AS ft
    INNER JOIN marts.dim_ingestion AS di
        ON ft.ingestion_id = di.ingestion_id
    INNER JOIN marts.dim_date AS dd
        ON ft.pickup_date_key = dd.date_key
    INNER JOIN marts.dim_hour AS dh
        ON ft.pickup_hour_key = dh.hour_key
    WHERE di.ingestion_status = 'completed'
        AND NOT ft.is_pickup_outside_expected_period
    GROUP BY
        ft.ingestion_id,
        di.source_file_name,
        di.taxi_type,
        di.period_year,
        di.period_month,
        dd.full_date,
        dh.hour_key
),

hourly_totals AS (
    SELECT
        ingestion_id,
        source_file_name,
        taxi_type,
        period_year,
        period_month,
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

    FROM hourly_metrics
    GROUP BY
        ingestion_id,
        source_file_name,
        taxi_type,
        period_year,
        period_month,
        pickup_hour
),

window_metrics AS (
    SELECT
        ingestion_id,
        source_file_name,
        taxi_type,
        period_year,
        period_month,
        pickup_hour,
        represented_day_count,
        trip_count,
        operational_issue_trip_count,
        suspicious_condition_trip_count,
        any_quality_flag_trip_count,
        negative_transaction_trip_count,
        valid_speed_trip_count,
        positive_total_amount,
        negative_total_amount,
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
        ) AS cumulative_trip_count,

        AVG(trip_count) OVER (
            PARTITION BY ingestion_id
            ORDER BY pickup_hour
            ROWS BETWEEN 2 PRECEDING
                AND CURRENT ROW
        ) AS rolling_3_hour_average_trip_count,

        RANK() OVER (
            PARTITION BY ingestion_id
            ORDER BY trip_count DESC
        ) AS demand_rank,

        SUM(trip_count) OVER (
            PARTITION BY ingestion_id
        ) AS ingestion_trip_count

    FROM hourly_totals
)

SELECT
    ingestion_id,
    source_file_name,
    taxi_type,
    period_year,
    period_month,
    pickup_hour,
    represented_day_count,
    trip_count,

    ROUND(
        trip_count::NUMERIC
        / NULLIF(
            represented_day_count,
            0
        ),
        2
    )::NUMERIC(12, 2)
        AS average_daily_trip_count,

    operational_issue_trip_count,
    suspicious_condition_trip_count,
    any_quality_flag_trip_count,
    negative_transaction_trip_count,
    valid_speed_trip_count,

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

    positive_total_amount,
    negative_total_amount,
    net_total_amount,

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

    cumulative_trip_count::BIGINT
        AS cumulative_trip_count,

    ROUND(
        rolling_3_hour_average_trip_count,
        2
    )::NUMERIC(12, 2)
        AS rolling_3_hour_average_trip_count,

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

FROM window_metrics;


COMMIT;
