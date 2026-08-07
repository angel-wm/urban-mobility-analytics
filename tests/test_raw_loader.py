from unittest.mock import MagicMock

import pandas as pd
import pytest

from src.ingestion.raw_loader import (
    complete_ingestion,
    delete_raw_taxi_trips_for_ingestion,
    fail_ingestion,
    find_completed_ingestion,
    load_raw_taxi_trips,
    record_skipped_ingestion,
    start_ingestion,
)


def make_mock_engine() -> tuple[MagicMock, MagicMock]:
    engine = MagicMock()
    connection = MagicMock()

    engine.begin.return_value.__enter__.return_value = connection
    engine.connect.return_value.__enter__.return_value = connection

    return engine, connection


def test_start_ingestion_returns_generated_id() -> None:
    engine, connection = make_mock_engine()
    connection.execute.return_value.scalar_one.return_value = 42

    ingestion_id = start_ingestion(
        engine=engine,
        source_file_name="yellow.parquet",
        taxi_type="yellow",
        period_year=2025,
        period_month=1,
        file_size_bytes=12345,
    )

    assert ingestion_id == 42

    statement, parameters = connection.execute.call_args.args

    assert "INSERT INTO raw.ingestion_log" in str(statement)
    assert parameters == {
        "source_file_name": "yellow.parquet",
        "taxi_type": "yellow",
        "period_year": 2025,
        "period_month": 1,
        "file_size_bytes": 12345,
    }


def test_load_raw_taxi_trips_adds_ingestion_id(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    engine, connection = make_mock_engine()

    dataframe = pd.DataFrame(
        {
            "vendor_id": [1, 2],
            "trip_distance": [2.5, 4.0],
        }
    )

    captured: dict[str, object] = {}

    def fake_to_sql(
        self: pd.DataFrame,
        **kwargs: object,
    ) -> None:
        captured["dataframe"] = self.copy()
        captured["kwargs"] = kwargs

    monkeypatch.setattr(pd.DataFrame, "to_sql", fake_to_sql)

    loaded_rows = load_raw_taxi_trips(
        engine=engine,
        dataframe=dataframe,
        ingestion_id=7,
        chunk_size=500,
    )

    loaded_dataframe = captured["dataframe"]
    kwargs = captured["kwargs"]

    assert isinstance(loaded_dataframe, pd.DataFrame)
    assert loaded_rows == 2
    assert loaded_dataframe.columns[0] == "ingestion_id"
    assert loaded_dataframe["ingestion_id"].tolist() == [7, 7]

    assert kwargs["name"] == "taxi_trips"
    assert kwargs["schema"] == "raw"
    assert kwargs["con"] is connection
    assert kwargs["if_exists"] == "append"
    assert kwargs["index"] is False
    assert kwargs["chunksize"] == 500
    assert kwargs["method"] == "multi"


def test_complete_ingestion_updates_one_record() -> None:
    engine, connection = make_mock_engine()
    connection.execute.return_value.rowcount = 1

    complete_ingestion(
        engine=engine,
        ingestion_id=7,
        rows_read=100,
        rows_loaded=100,
    )

    statement, parameters = connection.execute.call_args.args

    assert "UPDATE raw.ingestion_log" in str(statement)
    assert parameters["ingestion_id"] == 7
    assert parameters["rows_read"] == 100
    assert parameters["rows_loaded"] == 100
    assert parameters["rows_rejected"] == 0


def test_complete_ingestion_rejects_missing_record() -> None:
    engine, connection = make_mock_engine()
    connection.execute.return_value.rowcount = 0

    with pytest.raises(
        ValueError,
        match="completed ingestion record could not be updated",
    ):
        complete_ingestion(
            engine=engine,
            ingestion_id=999,
            rows_read=100,
            rows_loaded=100,
        )


def test_fail_ingestion_rejects_missing_record() -> None:
    engine, connection = make_mock_engine()
    connection.execute.return_value.rowcount = 0

    with pytest.raises(
        ValueError,
        match="failed ingestion record could not be updated",
    ):
        fail_ingestion(
            engine=engine,
            ingestion_id=999,
            error_message="test failure",
        )


def test_find_completed_ingestion_returns_matching_id() -> None:
    engine, connection = make_mock_engine()
    connection.execute.return_value.scalar_one_or_none.return_value = 7

    ingestion_id = find_completed_ingestion(
        engine=engine,
        source_file_name="yellow.parquet",
        taxi_type="yellow",
        period_year=2025,
        period_month=1,
        file_size_bytes=12345,
    )

    assert ingestion_id == 7


def test_find_completed_ingestion_returns_none_when_missing() -> None:
    engine, connection = make_mock_engine()
    connection.execute.return_value.scalar_one_or_none.return_value = None

    ingestion_id = find_completed_ingestion(
        engine=engine,
        source_file_name="yellow.parquet",
        taxi_type="yellow",
        period_year=2025,
        period_month=1,
        file_size_bytes=12345,
    )

    assert ingestion_id is None


def test_record_skipped_ingestion_returns_generated_id() -> None:
    engine, connection = make_mock_engine()
    connection.execute.return_value.scalar_one.return_value = 8

    ingestion_id = record_skipped_ingestion(
        engine=engine,
        source_file_name="yellow.parquet",
        taxi_type="yellow",
        period_year=2025,
        period_month=1,
        file_size_bytes=12345,
    )

    assert ingestion_id == 8


def test_delete_raw_taxi_trips_returns_deleted_count() -> None:
    engine, connection = make_mock_engine()
    connection.execute.return_value.rowcount = 25

    deleted_rows = delete_raw_taxi_trips_for_ingestion(
        engine=engine,
        ingestion_id=7,
    )

    assert deleted_rows == 25

    statement, parameters = connection.execute.call_args.args

    assert "DELETE FROM raw.taxi_trips" in str(statement)
    assert parameters == {"ingestion_id": 7}
