from collections.abc import Iterator
from pathlib import Path

import pandas as pd
import pyarrow.parquet as pq


def validate_parquet_path(file_path: Path) -> None:
    """Validate that a Parquet source path exists and points to a file."""

    if not file_path.exists():
        raise FileNotFoundError(f"Parquet file not found: {file_path}")

    if not file_path.is_file():
        raise ValueError(f"The Parquet path does not point to a file: {file_path}")

    if file_path.suffix.lower() != ".parquet":
        raise ValueError(
            f"The source file must use the .parquet extension: {file_path}"
        )


def get_parquet_metadata(file_path: Path) -> dict[str, int]:
    """Return the main metadata values from a Parquet file."""

    validate_parquet_path(file_path)

    parquet_file = pq.ParquetFile(file_path)

    return {
        "rows": parquet_file.metadata.num_rows,
        "columns": parquet_file.metadata.num_columns,
        "row_groups": parquet_file.metadata.num_row_groups,
        "file_size_bytes": file_path.stat().st_size,
    }


def read_parquet_row_group(
    file_path: Path,
    row_group_index: int,
    columns: list[str] | None = None,
) -> pd.DataFrame:
    """Read one Parquet row group and return it as a pandas DataFrame."""

    validate_parquet_path(file_path)

    parquet_file = pq.ParquetFile(file_path)
    row_group_count = parquet_file.metadata.num_row_groups

    if row_group_index < 0 or row_group_index >= row_group_count:
        raise IndexError(
            "Row group index is outside the valid range. "
            f"Received {row_group_index}; "
            f"valid range: 0 to {row_group_count - 1}."
        )

    arrow_table = parquet_file.read_row_group(
        row_group_index,
        columns=columns,
    )

    return arrow_table.to_pandas()


def iterate_parquet_row_groups(
    file_path: Path,
    columns: list[str] | None = None,
) -> Iterator[tuple[int, pd.DataFrame]]:
    """Yield every Parquet row group as a pandas DataFrame."""

    validate_parquet_path(file_path)

    parquet_file = pq.ParquetFile(file_path)
    row_group_count = parquet_file.metadata.num_row_groups

    for row_group_index in range(row_group_count):
        arrow_table = parquet_file.read_row_group(
            row_group_index,
            columns=columns,
        )

        dataframe = arrow_table.to_pandas()

        yield row_group_index, dataframe
