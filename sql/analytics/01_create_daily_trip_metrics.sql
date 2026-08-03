BEGIN;


CREATE OR REPLACE VIEW analytics.daily_trip_metrics AS
WITH eligible_trips AS (
    SELECT
        ingestion_id,
        source_file_name,
        taxi_type,
        period_year,
        period_month,
        pickup_date,
        trip_distance,
        trip_duration_minutes,
        average_speed_mph,
        total_amount,
        has_operational_issue,
        has_suspicious_condition,
        has_any_quality_flag,
        is_negative_distance,
        is_negative_transaction,
        is_valid_for_speed_analysis
    FROM staging.taxi_trips
    WHERE ingestion_status = 'completed'
        AND pickup_date IS NOT NULL
        AND NOT is_pickup_outside_expected_period
),

daily_aggregates AS (
    SELECT
        ingestion_id,
        source_file_name,
        taxi_type,
        period_year,
        period_month,
        pickup_date,

        COUNT(*) AS trip_count,

        COUNT(*) FILTER (
            WHERE has_operational_issue
        ) AS operational_issue_trip_count,

        COUNT(*) FILTER (
            WHERE has_suspicious_condition
        ) AS suspicious_condition_trip_count,

        COUNT(*) FILTER (
            WHERE has_any_quality_flag
        ) AS any_quality_flag_trip_count,

        COUNT(*) FILTER (
            WHERE is_negative_transaction
        ) AS negative_transaction_trip_count,

        COUNT(*) FILTER (
            WHERE is_valid_for_speed_analysis
        ) AS valid_speed_trip_count,

        ROUND(
            (
                SUM(trip_distance) FILTER (
                    WHERE NOT is_negative_distance
                )
            )::NUMERIC,
            2
        )::NUMERIC(18, 2) AS total_trip_distance,

        ROUND(
            (
                AVG(trip_distance) FILTER (
                    WHERE NOT is_negative_distance
                )
            )::NUMERIC,
            2
        )::NUMERIC(12, 2) AS average_trip_distance,

        ROUND(
            (
                AVG(trip_duration_minutes) FILTER (
                    WHERE NOT has_operational_issue
                        AND trip_duration_minutes
                            <= 24 * 60
                )
            )::NUMERIC,
            2
        )::NUMERIC(12, 2) AS average_trip_duration_minutes,

        ROUND(
            (
                AVG(average_speed_mph) FILTER (
                    WHERE is_valid_for_speed_analysis
                )
            )::NUMERIC,
            2
        )::NUMERIC(12, 2) AS average_speed_mph,

        ROUND(
            COALESCE(
                SUM(total_amount) FILTER (
                    WHERE total_amount >= 0
                ),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2) AS positive_total_amount,

        ROUND(
            COALESCE(
                SUM(total_amount) FILTER (
                    WHERE total_amount < 0
                ),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2) AS negative_total_amount,

        ROUND(
            COALESCE(
                SUM(total_amount),
                0::NUMERIC
            ),
            2
        )::NUMERIC(18, 2) AS net_total_amount,

        ROUND(
            AVG(total_amount),
            2
        )::NUMERIC(12, 2) AS average_total_amount

    FROM eligible_trips
    GROUP BY
        ingestion_id,
        source_file_name,
        taxi_type,
        period_year,
        period_month,
        pickup_date
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
    average_total_amount
FROM daily_aggregates;


COMMIT;