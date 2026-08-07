import pytest
from sqlalchemy import Engine, text


pytestmark = pytest.mark.integration


def test_daily_mobility_summary_has_expected_grain(
    db_engine: Engine,
) -> None:
    statement = text(
        """
        SELECT COUNT(*)
        FROM (
            SELECT
                ingestion_id,
                pickup_date
            FROM marts.daily_mobility_summary
            GROUP BY
                ingestion_id,
                pickup_date
            HAVING COUNT(*) <> 1
        ) AS violations;
        """
    )

    with db_engine.connect() as connection:
        violation_count = connection.execute(statement).scalar_one()

    assert violation_count == 0


def test_hourly_demand_profile_has_expected_grain(
    db_engine: Engine,
) -> None:
    statement = text(
        """
        SELECT COUNT(*)
        FROM (
            SELECT
                ingestion_id,
                pickup_hour
            FROM marts.hourly_demand_profile
            GROUP BY
                ingestion_id,
                pickup_hour
            HAVING COUNT(*) <> 1
        ) AS violations;
        """
    )

    with db_engine.connect() as connection:
        violation_count = connection.execute(statement).scalar_one()

    assert violation_count == 0


def test_daily_mart_reconciles_trip_counts_with_analytics(
    db_engine: Engine,
) -> None:
    statement = text(
        """
        WITH analytics_totals AS (
            SELECT
                ingestion_id,
                SUM(trip_count) AS trip_count
            FROM analytics.daily_trip_metrics
            GROUP BY ingestion_id
        ),
        mart_totals AS (
            SELECT
                ingestion_id,
                SUM(trip_count) AS trip_count
            FROM marts.daily_mobility_summary
            GROUP BY ingestion_id
        )
        SELECT COUNT(*)
        FROM analytics_totals AS a
        FULL OUTER JOIN mart_totals AS m
            ON m.ingestion_id = a.ingestion_id
        WHERE a.trip_count
            IS DISTINCT FROM m.trip_count;
        """
    )

    with db_engine.connect() as connection:
        violation_count = connection.execute(statement).scalar_one()

    assert violation_count == 0


def test_hourly_mart_reconciles_trip_counts_with_analytics(
    db_engine: Engine,
) -> None:
    statement = text(
        """
        WITH analytics_totals AS (
            SELECT
                ingestion_id,
                SUM(trip_count) AS trip_count
            FROM analytics.hourly_trip_metrics
            GROUP BY ingestion_id
        ),
        mart_totals AS (
            SELECT
                ingestion_id,
                SUM(trip_count) AS trip_count
            FROM marts.hourly_demand_profile
            GROUP BY ingestion_id
        )
        SELECT COUNT(*)
        FROM analytics_totals AS a
        FULL OUTER JOIN mart_totals AS m
            ON m.ingestion_id = a.ingestion_id
        WHERE a.trip_count
            IS DISTINCT FROM m.trip_count;
        """
    )

    with db_engine.connect() as connection:
        violation_count = connection.execute(statement).scalar_one()

    assert violation_count == 0


def test_analytical_marts_use_optimized_fact_source(
    db_engine: Engine,
) -> None:
    statement = text(
        """
        SELECT
            schemaname,
            viewname,
            definition
        FROM pg_views
        WHERE schemaname = 'marts'
            AND viewname IN (
                'daily_mobility_summary',
                'hourly_demand_profile'
            )
        ORDER BY viewname;
        """
    )

    with db_engine.connect() as connection:
        views = connection.execute(statement).mappings().all()

    assert len(views) == 2

    for view in views:
        definition = view["definition"]

        assert "fact_trip" in definition
        assert "daily_trip_metrics" not in definition
        assert "hourly_trip_metrics" not in definition
