import pytest
from sqlalchemy import Engine, text


pytestmark = pytest.mark.integration


def test_required_schemas_exist(db_engine: Engine) -> None:
    statement = text(
        """
        SELECT schema_name
        FROM information_schema.schemata
        WHERE schema_name IN (
            'raw',
            'staging',
            'analytics',
            'marts'
        );
        """
    )

    with db_engine.connect() as connection:
        schemas = set(connection.execute(statement).scalars().all())

    assert schemas == {
        "raw",
        "staging",
        "analytics",
        "marts",
    }


def test_fact_trip_has_one_row_per_raw_trip(db_engine: Engine) -> None:
    statement = text(
        """
        SELECT
            COUNT(*) AS fact_row_count,
            COUNT(DISTINCT raw_trip_id) AS distinct_raw_trip_count
        FROM marts.fact_trip;
        """
    )

    with db_engine.connect() as connection:
        result = connection.execute(statement).one()

    fact_row_count = result.fact_row_count
    distinct_raw_trip_count = result.distinct_raw_trip_count

    assert fact_row_count > 0
    assert fact_row_count == distinct_raw_trip_count


def test_staging_and_fact_counts_match_by_ingestion(
    db_engine: Engine,
) -> None:
    statement = text(
        """
        WITH staging_counts AS (
            SELECT
                ingestion_id,
                COUNT(*) AS staging_row_count
            FROM staging.taxi_trips
            GROUP BY ingestion_id
        ),
        fact_counts AS (
            SELECT
                ingestion_id,
                COUNT(*) AS fact_row_count
            FROM marts.fact_trip
            GROUP BY ingestion_id
        )
        SELECT COUNT(*)
        FROM staging_counts
        FULL OUTER JOIN fact_counts
            ON fact_counts.ingestion_id = staging_counts.ingestion_id
        WHERE staging_counts.staging_row_count
            IS DISTINCT FROM fact_counts.fact_row_count;
        """
    )

    with db_engine.connect() as connection:
        violation_count = connection.execute(statement).scalar_one()

    assert violation_count == 0


def test_fact_trip_has_no_dimension_orphans(
    db_engine: Engine,
) -> None:
    statement = text(
        """
        SELECT
            COUNT(*) FILTER (
                WHERE di.ingestion_id IS NULL
            )
            + COUNT(*) FILTER (
                WHERE pickup_date.date_key IS NULL
            )
            + COUNT(*) FILTER (
                WHERE dropoff_date.date_key IS NULL
            )
            + COUNT(*) FILTER (
                WHERE pickup_hour.hour_key IS NULL
            )
            + COUNT(*) FILTER (
                WHERE dropoff_hour.hour_key IS NULL
            )
            + COUNT(*) FILTER (
                WHERE vendor.vendor_key IS NULL
            )
            + COUNT(*) FILTER (
                WHERE rate_code.rate_code_key IS NULL
            )
            + COUNT(*) FILTER (
                WHERE payment.payment_type_key IS NULL
            )
            + COUNT(*) FILTER (
                WHERE store_fwd.store_and_fwd_key IS NULL
            ) AS orphan_count
        FROM marts.fact_trip AS ft

        LEFT JOIN marts.dim_ingestion AS di
            ON di.ingestion_id = ft.ingestion_id

        LEFT JOIN marts.dim_date AS pickup_date
            ON pickup_date.date_key = ft.pickup_date_key

        LEFT JOIN marts.dim_date AS dropoff_date
            ON dropoff_date.date_key = ft.dropoff_date_key

        LEFT JOIN marts.dim_hour AS pickup_hour
            ON pickup_hour.hour_key = ft.pickup_hour_key

        LEFT JOIN marts.dim_hour AS dropoff_hour
            ON dropoff_hour.hour_key = ft.dropoff_hour_key

        LEFT JOIN marts.dim_vendor AS vendor
            ON vendor.vendor_key = ft.vendor_key

        LEFT JOIN marts.dim_rate_code AS rate_code
            ON rate_code.rate_code_key = ft.rate_code_key

        LEFT JOIN marts.dim_payment_type AS payment
            ON payment.payment_type_key = ft.payment_type_key

        LEFT JOIN marts.dim_store_and_fwd AS store_fwd
            ON store_fwd.store_and_fwd_key = ft.store_and_fwd_key;
        """
    )

    with db_engine.connect() as connection:
        orphan_count = connection.execute(statement).scalar_one()

    assert orphan_count == 0
