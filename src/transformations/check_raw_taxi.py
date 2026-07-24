from pathlib import Path

from src.ingestion.parquet_reader import (
    read_parquet_row_group,
)
from src.transformations.raw_taxi import (
    prepare_raw_taxi_dataframe,
)


DATA_PATH = Path("data/raw/yellow_tripdata_2025-01.parquet")


def main() -> None:
    """Check the raw Yellow Taxi DataFrame preparation."""

    source_dataframe = read_parquet_row_group(
        file_path=DATA_PATH,
        row_group_index=0,
    )

    prepared_dataframe = prepare_raw_taxi_dataframe(source_dataframe)

    print("Raw Taxi DataFrame preparation successful")
    print(f"Source shape: {source_dataframe.shape}")
    print(f"Prepared shape: {prepared_dataframe.shape}")
    print("Prepared columns:")

    for column in prepared_dataframe.columns:
        print(f"  - {column}")

    print()
    print("Prepared data types:")
    print(prepared_dataframe.dtypes)


if __name__ == "__main__":
    main()
