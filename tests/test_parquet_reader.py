from pathlib import Path

import pandas as pd
import pytest

from src.ingestion.parquet_reader import (
    get_parquet_metadata,
    iterate_parquet_row_groups,
    read_parquet_row_group,
    validate_parquet_path,
)


def make_parquet_file(tmp_path: Path) -> Path:
    file_path = tmp_path / "sample.parquet"

    dataframe = pd.DataFrame(
        {
            "trip_id": [1, 2, 3],
            "distance": [1.5, 2.5, 3.5],
        }
    )

    dataframe.to_parquet(
        file_path,
        engine="pyarrow",
        index=False,
        row_group_size=2,
    )

    return file_path


def test_validate_parquet_path_accepts_valid_file(tmp_path: Path) -> None:
    file_path = make_parquet_file(tmp_path)

    validate_parquet_path(file_path)


def test_validate_parquet_path_rejects_missing_file(tmp_path: Path) -> None:
    file_path = tmp_path / "missing.parquet"

    with pytest.raises(FileNotFoundError):
        validate_parquet_path(file_path)


def test_validate_parquet_path_rejects_directory(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="does not point to a file"):
        validate_parquet_path(tmp_path)


def test_validate_parquet_path_rejects_wrong_extension(tmp_path: Path) -> None:
    file_path = tmp_path / "sample.csv"
    file_path.write_text("value\n1\n", encoding="utf-8")

    with pytest.raises(ValueError, match=".parquet"):
        validate_parquet_path(file_path)


def test_get_parquet_metadata_returns_expected_values(
    tmp_path: Path,
) -> None:
    file_path = make_parquet_file(tmp_path)

    metadata = get_parquet_metadata(file_path)

    assert metadata["rows"] == 3
    assert metadata["columns"] == 2
    assert metadata["row_groups"] == 2
    assert metadata["file_size_bytes"] > 0


def test_read_parquet_row_group_returns_requested_group(
    tmp_path: Path,
) -> None:
    file_path = make_parquet_file(tmp_path)

    dataframe = read_parquet_row_group(file_path, 0)

    assert len(dataframe) == 2
    assert dataframe["trip_id"].tolist() == [1, 2]


def test_read_parquet_row_group_rejects_invalid_index(
    tmp_path: Path,
) -> None:
    file_path = make_parquet_file(tmp_path)

    with pytest.raises(IndexError, match="outside the valid range"):
        read_parquet_row_group(file_path, 2)


def test_iterate_parquet_row_groups_reads_all_rows(
    tmp_path: Path,
) -> None:
    file_path = make_parquet_file(tmp_path)

    row_groups = list(iterate_parquet_row_groups(file_path))

    assert len(row_groups) == 2
    assert row_groups[0][0] == 0
    assert row_groups[1][0] == 1

    combined = pd.concat(
        [dataframe for _, dataframe in row_groups],
        ignore_index=True,
    )

    assert combined["trip_id"].tolist() == [1, 2, 3]
