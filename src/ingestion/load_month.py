from pathlib import Path

from src.database import get_engine
from src.ingestion.parquet_reader import (
    get_parquet_metadata,
    iterate_parquet_row_groups,
)
from src.ingestion.raw_loader import (
    complete_ingestion,
    delete_raw_taxi_trips_for_ingestion,
    fail_ingestion,
    find_completed_ingestion,
    load_raw_taxi_trips,
    record_skipped_ingestion,
    start_ingestion,
)
from src.transformations.raw_taxi import (
    prepare_raw_taxi_dataframe,
)


DATA_PATH = Path("data/raw/yellow_tripdata_2025-01.parquet")

TAXI_TYPE = "yellow"
PERIOD_YEAR = 2025
PERIOD_MONTH = 1
DATABASE_CHUNK_SIZE = 1_000


def main() -> None:
    """Load a complete monthly Yellow Taxi Parquet file."""

    metadata = get_parquet_metadata(DATA_PATH)
    engine = get_engine()

    completed_ingestion_id = find_completed_ingestion(
        engine=engine,
        source_file_name=DATA_PATH.name,
        taxi_type=TAXI_TYPE,
        period_year=PERIOD_YEAR,
        period_month=PERIOD_MONTH,
        file_size_bytes=metadata["file_size_bytes"],
    )

    if completed_ingestion_id is not None:
        skipped_ingestion_id = record_skipped_ingestion(
            engine=engine,
            source_file_name=DATA_PATH.name,
            taxi_type=TAXI_TYPE,
            period_year=PERIOD_YEAR,
            period_month=PERIOD_MONTH,
            file_size_bytes=metadata["file_size_bytes"],
        )

        print("Monthly ingestion skipped")
        print(f"Matching completed ingestion: {completed_ingestion_id}")
        print(f"Skipped ingestion record: {skipped_ingestion_id}")
        return

    rows_read = 0
    rows_loaded = 0
    rows_rejected = 0

    ingestion_id = start_ingestion(
        engine=engine,
        source_file_name=DATA_PATH.name,
        taxi_type=TAXI_TYPE,
        period_year=PERIOD_YEAR,
        period_month=PERIOD_MONTH,
        file_size_bytes=metadata["file_size_bytes"],
    )

    print(f"Ingestion started: {ingestion_id}")
    print(f"Source rows: {metadata['rows']:,}")
    print(f"Row groups: {metadata['row_groups']}")

    try:
        for (
            row_group_index,
            source_dataframe,
        ) in iterate_parquet_row_groups(DATA_PATH):
            rows_in_group = len(source_dataframe)
            rows_read += rows_in_group

            prepared_dataframe = prepare_raw_taxi_dataframe(source_dataframe)

            loaded_in_group = load_raw_taxi_trips(
                engine=engine,
                dataframe=prepared_dataframe,
                ingestion_id=ingestion_id,
                chunk_size=DATABASE_CHUNK_SIZE,
            )

            rows_loaded += loaded_in_group

            print(f"Row group {row_group_index + 1}/{metadata['row_groups']} completed")
            print(f"  Rows in group: {rows_in_group:,}")
            print(f"  Total rows loaded: {rows_loaded:,}")

        if rows_read != metadata["rows"]:
            raise ValueError(
                "The number of rows read does not match "
                "the Parquet metadata. "
                f"Expected {metadata['rows']:,}; "
                f"read {rows_read:,}."
            )

        if rows_loaded != rows_read:
            raise ValueError(
                "The number of rows loaded does not match "
                "the number of rows read. "
                f"Read {rows_read:,}; "
                f"loaded {rows_loaded:,}."
            )

        complete_ingestion(
            engine=engine,
            ingestion_id=ingestion_id,
            rows_read=rows_read,
            rows_loaded=rows_loaded,
            rows_rejected=rows_rejected,
        )

    except Exception as error:
        deleted_rows = delete_raw_taxi_trips_for_ingestion(
            engine=engine,
            ingestion_id=ingestion_id,
        )

        fail_ingestion(
            engine=engine,
            ingestion_id=ingestion_id,
            error_message=str(error),
            rows_read=rows_read,
            rows_loaded=0,
            rows_rejected=rows_rejected,
        )

        print("Monthly ingestion failed")
        print(f"Partial rows deleted: {deleted_rows:,}")
        print(f"Details: {error}")

        raise

    print("Monthly ingestion completed successfully")
    print(f"Rows read: {rows_read:,}")
    print(f"Rows loaded: {rows_loaded:,}")
    print(f"Rows rejected: {rows_rejected:,}")


if __name__ == "__main__":
    main()
