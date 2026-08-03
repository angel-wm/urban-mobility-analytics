-- Validate the grain and represented date-hour range.

SELECT
    ingestion_id,
    COUNT(*) AS hourly_row_count,
    COUNT(
        DISTINCT (
            pickup_date,
            pickup_hour
        )
    ) AS distinct_date_hours,
    COUNT(DISTINCT pickup_date) AS represented_days,
    COUNT(DISTINCT pickup_hour) AS represented_hours,
    SUM(trip_count) AS represented_trip_count,
    MIN(pickup_date) AS first_pickup_date,
    MAX(pickup_date) AS last_pickup_date,
    MIN(pickup_hour) AS first_pickup_hour,
    MAX(pickup_hour) AS last_pickup_hour
FROM analytics.hourly_trip_metrics
GROUP BY ingestion_id
ORDER BY ingestion_id;


-- A result from this query indicates a grain violation.

SELECT
    ingestion_id,
    pickup_date,
    pickup_hour,
    COUNT(*) AS row_count
FROM analytics.hourly_trip_metrics
GROUP BY
    ingestion_id,
    pickup_date,
    pickup_hour
HAVING COUNT(*) <> 1
ORDER BY
    ingestion_id,
    pickup_date,
    pickup_hour;


-- Reconcile additive metrics against staging.

WITH expected_metrics AS (
    SELECT
        ingestion_id,

        COUNT(*) AS expected_trip_count,

        COUNT(*) FILTER (
            WHERE has_operational_issue
        ) AS expected_operational_issue_trip_count,

        COUNT(*) FILTER (
            WHERE has_suspicious_condition
        ) AS expected_suspicious_condition_trip_count,

        COUNT(*) FILTER (
            WHERE has_any_quality_flag
        ) AS expected_any_quality_flag_trip_count,

        COUNT(*) FILTER (
            WHERE is_negative_transaction
        ) AS expected_negative_transaction_trip_count,

        COUNT(*) FILTER (
            WHERE is_valid_for_speed_analysis
        ) AS expected_valid_speed_trip_count,

        ROUND(
            COALESCE(
                SUM(total_amount) FILTER (
                    WHERE total_amount >= 0
                ),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2)
            AS expected_positive_total_amount,

        ROUND(
            COALESCE(
                SUM(total_amount) FILTER (
                    WHERE total_amount < 0
                ),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2)
            AS expected_negative_total_amount,

        ROUND(
            COALESCE(
                SUM(total_amount),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2)
            AS expected_net_total_amount

    FROM staging.taxi_trips
    WHERE ingestion_status = 'completed'
        AND pickup_date IS NOT NULL
        AND pickup_hour IS NOT NULL
        AND NOT is_pickup_outside_expected_period
    GROUP BY ingestion_id
),

actual_metrics AS (
    SELECT
        ingestion_id,

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

    FROM analytics.hourly_trip_metrics
    GROUP BY ingestion_id
)

SELECT
    COALESCE(
        e.ingestion_id,
        a.ingestion_id
    ) AS ingestion_id,

    a.actual_trip_count
        - e.expected_trip_count
        AS trip_count_difference,

    a.actual_operational_issue_trip_count
        - e.expected_operational_issue_trip_count
        AS operational_issue_difference,

    a.actual_suspicious_condition_trip_count
        - e.expected_suspicious_condition_trip_count
        AS suspicious_condition_difference,

    a.actual_any_quality_flag_trip_count
        - e.expected_any_quality_flag_trip_count
        AS any_quality_flag_difference,

    a.actual_negative_transaction_trip_count
        - e.expected_negative_transaction_trip_count
        AS negative_transaction_difference,

    a.actual_valid_speed_trip_count
        - e.expected_valid_speed_trip_count
        AS valid_speed_difference,

    a.actual_positive_total_amount
        - e.expected_positive_total_amount
        AS positive_total_amount_difference,

    a.actual_negative_total_amount
        - e.expected_negative_total_amount
        AS negative_total_amount_difference,

    a.actual_net_total_amount
        - e.expected_net_total_amount
        AS net_total_amount_difference

FROM expected_metrics AS e
FULL OUTER JOIN actual_metrics AS a
    ON e.ingestion_id = a.ingestion_id
ORDER BY ingestion_id;


-- Reconcile hourly metrics rolled up to the daily analytics grain.

WITH hourly_daily_metrics AS (
    SELECT
        ingestion_id,
        pickup_date,

        SUM(trip_count) AS trip_count,

        SUM(
            operational_issue_trip_count
        ) AS operational_issue_trip_count,

        SUM(
            suspicious_condition_trip_count
        ) AS suspicious_condition_trip_count,

        SUM(
            any_quality_flag_trip_count
        ) AS any_quality_flag_trip_count,

        SUM(
            negative_transaction_trip_count
        ) AS negative_transaction_trip_count,

        SUM(
            valid_speed_trip_count
        ) AS valid_speed_trip_count,

        SUM(
            positive_total_amount
        ) AS positive_total_amount,

        SUM(
            negative_total_amount
        ) AS negative_total_amount,

        SUM(
            net_total_amount
        ) AS net_total_amount

    FROM analytics.hourly_trip_metrics
    GROUP BY
        ingestion_id,
        pickup_date
)

SELECT
    COALESCE(
        d.ingestion_id,
        h.ingestion_id
    ) AS ingestion_id,

    COALESCE(
        d.pickup_date,
        h.pickup_date
    ) AS pickup_date,

    h.trip_count
        - d.trip_count
        AS trip_count_difference,

    h.operational_issue_trip_count
        - d.operational_issue_trip_count
        AS operational_issue_difference,

    h.suspicious_condition_trip_count
        - d.suspicious_condition_trip_count
        AS suspicious_condition_difference,

    h.any_quality_flag_trip_count
        - d.any_quality_flag_trip_count
        AS any_quality_flag_difference,

    h.negative_transaction_trip_count
        - d.negative_transaction_trip_count
        AS negative_transaction_difference,

    h.valid_speed_trip_count
        - d.valid_speed_trip_count
        AS valid_speed_difference,

    h.positive_total_amount
        - d.positive_total_amount
        AS positive_total_amount_difference,

    h.negative_total_amount
        - d.negative_total_amount
        AS negative_total_amount_difference,

    h.net_total_amount
        - d.net_total_amount
        AS net_total_amount_difference

FROM analytics.daily_trip_metrics AS d
FULL OUTER JOIN hourly_daily_metrics AS h
    ON d.ingestion_id = h.ingestion_id
    AND d.pickup_date = h.pickup_date
WHERE
    h.trip_count
        IS DISTINCT FROM d.trip_count

    OR h.operational_issue_trip_count
        IS DISTINCT FROM d.operational_issue_trip_count

    OR h.suspicious_condition_trip_count
        IS DISTINCT FROM d.suspicious_condition_trip_count

    OR h.any_quality_flag_trip_count
        IS DISTINCT FROM d.any_quality_flag_trip_count

    OR h.negative_transaction_trip_count
        IS DISTINCT FROM d.negative_transaction_trip_count

    OR h.valid_speed_trip_count
        IS DISTINCT FROM d.valid_speed_trip_count

    OR h.positive_total_amount
        IS DISTINCT FROM d.positive_total_amount

    OR h.negative_total_amount
        IS DISTINCT FROM d.negative_total_amount

    OR h.net_total_amount
        IS DISTINCT FROM d.net_total_amount
ORDER BY
    ingestion_id,
    pickup_date;


-- A result indicates an invalid hour or an unexpected date.

SELECT
    ingestion_id,
    period_year,
    period_month,
    pickup_date,
    pickup_hour
FROM analytics.hourly_trip_metrics
WHERE pickup_hour NOT BETWEEN 0 AND 23
    OR pickup_date
        < MAKE_DATE(
            period_year::INTEGER,
            period_month::INTEGER,
            1
        )
    OR pickup_date
        >= (
            MAKE_DATE(
                period_year::INTEGER,
                period_month::INTEGER,
                1
            )
            + INTERVAL '1 month'
        )::DATE
ORDER BY
    ingestion_id,
    pickup_date,
    pickup_hour;


-- Validate the known complete January 2025 ingestion.

SELECT
    ingestion_id,
    COUNT(*) AS represented_date_hours,
    COUNT(DISTINCT pickup_date) AS represented_days,
    COUNT(DISTINCT pickup_hour) AS represented_hours,
    SUM(trip_count) AS represented_trips,
    MIN(pickup_hour) AS first_pickup_hour,
    MAX(pickup_hour) AS last_pickup_hour
FROM analytics.hourly_trip_metrics
WHERE ingestion_id = 7
GROUP BY ingestion_id;