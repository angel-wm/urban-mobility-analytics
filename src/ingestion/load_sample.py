from pathlib import Path

import pandas as pd

from src.database import get_engine
from src.ingestion.raw_loader import (
    complete_ingestion,
    fail_ingestion,
    load_raw_taxi_trips,
    start_ingestion,
)
from src.transformations.raw_taxi import (
    prepare_raw_taxi_dataframe,
)


SAMPLE_PATH = Path("data/sample/yellow_tripdata_2025-01_sample.parquet")

TAXI_TYPE = "yellow"
PERIOD_YEAR = 2025
PERIOD_MONTH = 1


def main() -> None:
    """Load the development sample into the raw PostgreSQL tables."""

    if not SAMPLE_PATH.exists():
        raise FileNotFoundError(f"Development sample not found: {SAMPLE_PATH}")

    engine = get_engine()

    rows_read = 0
    rows_loaded = 0
    rows_rejected = 0

    ingestion_id = start_ingestion(
        engine=engine,
        source_file_name=SAMPLE_PATH.name,
        taxi_type=TAXI_TYPE,
        period_year=PERIOD_YEAR,
        period_month=PERIOD_MONTH,
        file_size_bytes=SAMPLE_PATH.stat().st_size,
    )

    print(f"Ingestion started: {ingestion_id}")

    try:
        source_dataframe = pd.read_parquet(SAMPLE_PATH)

        rows_read = len(source_dataframe)

        prepared_dataframe = prepare_raw_taxi_dataframe(source_dataframe)

        rows_loaded = load_raw_taxi_trips(
            engine=engine,
            dataframe=prepared_dataframe,
            ingestion_id=ingestion_id,
        )

        complete_ingestion(
            engine=engine,
            ingestion_id=ingestion_id,
            rows_read=rows_read,
            rows_loaded=rows_loaded,
            rows_rejected=rows_rejected,
        )

    except Exception as error:
        fail_ingestion(
            engine=engine,
            ingestion_id=ingestion_id,
            error_message=str(error),
            rows_read=rows_read,
            rows_loaded=rows_loaded,
            rows_rejected=rows_rejected,
        )

        print("Sample ingestion failed")
        print(f"Details: {error}")

        raise

    print("Sample ingestion completed successfully")
    print(f"Rows read: {rows_read:,}")
    print(f"Rows loaded: {rows_loaded:,}")
    print(f"Rows rejected: {rows_rejected:,}")


if __name__ == "__main__":
    main()
