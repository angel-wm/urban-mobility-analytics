from pathlib import Path

from sqlalchemy import text

from src.database import get_engine
from src.ingestion.parquet_reader import get_parquet_metadata
from src.ingestion.raw_loader import find_completed_ingestion


DATA_PATH = Path("data/raw/yellow_tripdata_2025-01.parquet")

TAXI_TYPE = "yellow"
PERIOD_YEAR = 2025
PERIOD_MONTH = 1


def main() -> None:
    """Verify the completed monthly ingestion."""

    metadata = get_parquet_metadata(DATA_PATH)
    engine = get_engine()

    ingestion_id = find_completed_ingestion(
        engine=engine,
        source_file_name=DATA_PATH.name,
        taxi_type=TAXI_TYPE,
        period_year=PERIOD_YEAR,
        period_month=PERIOD_MONTH,
        file_size_bytes=metadata["file_size_bytes"],
    )

    if ingestion_id is None:
        raise ValueError("No matching completed monthly ingestion was found.")

    ingestion_statement = text(
        """
        SELECT
            ingestion_id,
            source_file_name,
            file_size_bytes,
            status,
            rows_read,
            rows_loaded,
            rows_rejected
        FROM raw.ingestion_log
        WHERE ingestion_id = :ingestion_id;
        """
    )

    trip_count_statement = text(
        """
        SELECT COUNT(*)
        FROM raw.taxi_trips
        WHERE ingestion_id = :ingestion_id;
        """
    )

    with engine.connect() as connection:
        ingestion_summary = (
            connection.execute(
                ingestion_statement,
                {"ingestion_id": ingestion_id},
            )
            .mappings()
            .one()
        )

        database_trip_count = connection.execute(
            trip_count_statement,
            {"ingestion_id": ingestion_id},
        ).scalar_one()

    checks = {
        "ingestion status is completed": (ingestion_summary["status"] == "completed"),
        "source file name matches": (
            ingestion_summary["source_file_name"] == DATA_PATH.name
        ),
        "source file size matches": (
            ingestion_summary["file_size_bytes"] == metadata["file_size_bytes"]
        ),
        "Parquet rows match rows_read": (
            metadata["rows"] == ingestion_summary["rows_read"]
        ),
        "rows_read match rows_loaded": (
            ingestion_summary["rows_read"] == ingestion_summary["rows_loaded"]
        ),
        "rows_loaded match database count": (
            ingestion_summary["rows_loaded"] == database_trip_count
        ),
        "rows_rejected is zero": (ingestion_summary["rows_rejected"] == 0),
    }

    print("Monthly ingestion verification")
    print(f"Ingestion ID: {ingestion_id}")
    print(f"Parquet rows: {metadata['rows']:,}")
    print(f"Database rows: {database_trip_count:,}")
    print()

    for check_name, passed in checks.items():
        result = "PASS" if passed else "FAIL"
        print(f"[{result}] {check_name}")

    if not all(checks.values()):
        raise SystemExit(1)

    print()
    print("All monthly ingestion checks passed.")


if __name__ == "__main__":
    main()
