from pathlib import Path

from src.ingestion.parquet_reader import (
    get_parquet_metadata,
    read_parquet_row_group,
)


DATA_PATH = Path("data/raw/yellow_tripdata_2025-01.parquet")


def main() -> None:
    """Check the reusable Parquet reader."""

    metadata = get_parquet_metadata(DATA_PATH)

    first_row_group = read_parquet_row_group(
        file_path=DATA_PATH,
        row_group_index=0,
    )

    print("Parquet reader check successful")
    print(f"Rows in complete file: {metadata['rows']:,}")
    print(f"Columns in source file: {metadata['columns']}")
    print(f"Row groups: {metadata['row_groups']}")
    print(f"File size: {metadata['file_size_bytes'] / 1024**2:.2f} MB")
    print(f"Rows in first row group: {len(first_row_group):,}")
    print(f"Columns loaded: {len(first_row_group.columns)}")


if __name__ == "__main__":
    main()