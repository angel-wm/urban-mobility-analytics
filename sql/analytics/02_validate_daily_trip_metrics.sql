-- Validate the grain and represented date range.

SELECT
    ingestion_id,
    COUNT(*) AS daily_row_count,
    COUNT(DISTINCT pickup_date) AS distinct_pickup_dates,
    SUM(trip_count) AS represented_trip_count,
    MIN(pickup_date) AS first_pickup_date,
    MAX(pickup_date) AS last_pickup_date
FROM analytics.daily_trip_metrics
GROUP BY ingestion_id
ORDER BY ingestion_id;


-- A result from this query indicates a grain violation.

SELECT
    ingestion_id,
    pickup_date,
    COUNT(*) AS row_count
FROM analytics.daily_trip_metrics
GROUP BY
    ingestion_id,
    pickup_date
HAVING COUNT(*) <> 1
ORDER BY
    ingestion_id,
    pickup_date;


-- Reconcile counts and monetary metrics against staging.

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
        )::NUMERIC(18, 2) AS expected_positive_total_amount,

        ROUND(
            COALESCE(
                SUM(total_amount) FILTER (
                    WHERE total_amount < 0
                ),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2) AS expected_negative_total_amount,

        ROUND(
            COALESCE(
                SUM(total_amount),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2) AS expected_net_total_amount

    FROM staging.taxi_trips
    WHERE ingestion_status = 'completed'
        AND pickup_date IS NOT NULL
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

    FROM analytics.daily_trip_metrics
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


-- A result indicates an inconsistent monetary identity.

SELECT
    ingestion_id,
    pickup_date,
    positive_total_amount,
    negative_total_amount,
    net_total_amount
FROM analytics.daily_trip_metrics
WHERE
    positive_total_amount
    + negative_total_amount
    <> net_total_amount
ORDER BY
    ingestion_id,
    pickup_date;


-- A result indicates that an output date is outside its expected month.

SELECT
    ingestion_id,
    period_year,
    period_month,
    pickup_date
FROM analytics.daily_trip_metrics
WHERE pickup_date
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
    pickup_date;


-- Validate the known complete January 2025 ingestion.

SELECT
    ingestion_id,
    COUNT(*) AS represented_days,
    SUM(trip_count) AS represented_trips,
    MIN(pickup_date) AS first_pickup_date,
    MAX(pickup_date) AS last_pickup_date
FROM analytics.daily_trip_metrics
WHERE ingestion_id = 7
GROUP BY ingestion_id;