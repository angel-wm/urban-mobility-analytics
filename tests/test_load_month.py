from unittest.mock import MagicMock

import pandas as pd
import pytest

from src.ingestion import load_month


def test_main_skips_already_completed_ingestion(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    engine = MagicMock()

    monkeypatch.setattr(
        load_month,
        "get_parquet_metadata",
        MagicMock(
            return_value={
                "rows": 100,
                "columns": 20,
                "row_groups": 1,
                "file_size_bytes": 12345,
            }
        ),
    )
    monkeypatch.setattr(
        load_month,
        "get_engine",
        MagicMock(return_value=engine),
    )

    find_completed = MagicMock(return_value=7)
    record_skipped = MagicMock(return_value=8)
    start_ingestion = MagicMock()

    monkeypatch.setattr(
        load_month,
        "find_completed_ingestion",
        find_completed,
    )
    monkeypatch.setattr(
        load_month,
        "record_skipped_ingestion",
        record_skipped,
    )
    monkeypatch.setattr(
        load_month,
        "start_ingestion",
        start_ingestion,
    )

    load_month.main()

    output = capsys.readouterr().out

    assert "Monthly ingestion skipped" in output
    assert "Matching completed ingestion: 7" in output
    assert "Skipped ingestion record: 8" in output

    record_skipped.assert_called_once()
    start_ingestion.assert_not_called()


def test_main_completes_successful_ingestion(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    engine = MagicMock()

    first_group = pd.DataFrame({"value": [1, 2]})
    second_group = pd.DataFrame({"value": [3]})

    monkeypatch.setattr(
        load_month,
        "get_parquet_metadata",
        MagicMock(
            return_value={
                "rows": 3,
                "columns": 1,
                "row_groups": 2,
                "file_size_bytes": 12345,
            }
        ),
    )
    monkeypatch.setattr(
        load_month,
        "get_engine",
        MagicMock(return_value=engine),
    )
    monkeypatch.setattr(
        load_month,
        "find_completed_ingestion",
        MagicMock(return_value=None),
    )
    monkeypatch.setattr(
        load_month,
        "start_ingestion",
        MagicMock(return_value=9),
    )
    monkeypatch.setattr(
        load_month,
        "iterate_parquet_row_groups",
        MagicMock(
            return_value=[
                (0, first_group),
                (1, second_group),
            ]
        ),
    )
    monkeypatch.setattr(
        load_month,
        "prepare_raw_taxi_dataframe",
        MagicMock(side_effect=lambda dataframe: dataframe),
    )

    load_raw = MagicMock(side_effect=[2, 1])
    complete = MagicMock()
    delete_partial = MagicMock()
    fail = MagicMock()

    monkeypatch.setattr(load_month, "load_raw_taxi_trips", load_raw)
    monkeypatch.setattr(load_month, "complete_ingestion", complete)
    monkeypatch.setattr(
        load_month,
        "delete_raw_taxi_trips_for_ingestion",
        delete_partial,
    )
    monkeypatch.setattr(load_month, "fail_ingestion", fail)

    load_month.main()

    output = capsys.readouterr().out

    assert "Monthly ingestion completed successfully" in output
    assert "Rows read: 3" in output
    assert "Rows loaded: 3" in output
    assert "Rows rejected: 0" in output

    assert load_raw.call_count == 2

    complete.assert_called_once_with(
        engine=engine,
        ingestion_id=9,
        rows_read=3,
        rows_loaded=3,
        rows_rejected=0,
    )

    delete_partial.assert_not_called()
    fail.assert_not_called()


def test_main_fails_when_loaded_count_does_not_match_read_count(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    engine = MagicMock()
    dataframe = pd.DataFrame({"value": [1, 2, 3]})

    monkeypatch.setattr(
        load_month,
        "get_parquet_metadata",
        MagicMock(
            return_value={
                "rows": 3,
                "columns": 1,
                "row_groups": 1,
                "file_size_bytes": 12345,
            }
        ),
    )
    monkeypatch.setattr(
        load_month,
        "get_engine",
        MagicMock(return_value=engine),
    )
    monkeypatch.setattr(
        load_month,
        "find_completed_ingestion",
        MagicMock(return_value=None),
    )
    monkeypatch.setattr(
        load_month,
        "start_ingestion",
        MagicMock(return_value=10),
    )
    monkeypatch.setattr(
        load_month,
        "iterate_parquet_row_groups",
        MagicMock(return_value=[(0, dataframe)]),
    )
    monkeypatch.setattr(
        load_month,
        "prepare_raw_taxi_dataframe",
        MagicMock(return_value=dataframe),
    )
    monkeypatch.setattr(
        load_month,
        "load_raw_taxi_trips",
        MagicMock(return_value=2),
    )

    delete_partial = MagicMock(return_value=2)
    fail = MagicMock()
    complete = MagicMock()

    monkeypatch.setattr(
        load_month,
        "delete_raw_taxi_trips_for_ingestion",
        delete_partial,
    )
    monkeypatch.setattr(load_month, "fail_ingestion", fail)
    monkeypatch.setattr(load_month, "complete_ingestion", complete)

    with pytest.raises(
        ValueError,
        match="number of rows loaded does not match",
    ):
        load_month.main()

    delete_partial.assert_called_once_with(
        engine=engine,
        ingestion_id=10,
    )

    fail.assert_called_once()

    assert fail.call_args.kwargs["ingestion_id"] == 10
    assert fail.call_args.kwargs["rows_read"] == 3
    assert fail.call_args.kwargs["rows_loaded"] == 0

    complete.assert_not_called()


def test_main_cleans_partial_rows_when_loading_raises(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    engine = MagicMock()
    dataframe = pd.DataFrame({"value": [1, 2]})

    monkeypatch.setattr(
        load_month,
        "get_parquet_metadata",
        MagicMock(
            return_value={
                "rows": 2,
                "columns": 1,
                "row_groups": 1,
                "file_size_bytes": 12345,
            }
        ),
    )
    monkeypatch.setattr(
        load_month,
        "get_engine",
        MagicMock(return_value=engine),
    )
    monkeypatch.setattr(
        load_month,
        "find_completed_ingestion",
        MagicMock(return_value=None),
    )
    monkeypatch.setattr(
        load_month,
        "start_ingestion",
        MagicMock(return_value=11),
    )
    monkeypatch.setattr(
        load_month,
        "iterate_parquet_row_groups",
        MagicMock(return_value=[(0, dataframe)]),
    )
    monkeypatch.setattr(
        load_month,
        "prepare_raw_taxi_dataframe",
        MagicMock(return_value=dataframe),
    )
    monkeypatch.setattr(
        load_month,
        "load_raw_taxi_trips",
        MagicMock(side_effect=RuntimeError("database failure")),
    )

    delete_partial = MagicMock(return_value=2)
    fail = MagicMock()
    complete = MagicMock()

    monkeypatch.setattr(
        load_month,
        "delete_raw_taxi_trips_for_ingestion",
        delete_partial,
    )
    monkeypatch.setattr(load_month, "fail_ingestion", fail)
    monkeypatch.setattr(load_month, "complete_ingestion", complete)

    with pytest.raises(RuntimeError, match="database failure"):
        load_month.main()

    delete_partial.assert_called_once_with(
        engine=engine,
        ingestion_id=11,
    )

    fail.assert_called_once()

    assert fail.call_args.kwargs["error_message"] == "database failure"
    assert fail.call_args.kwargs["rows_read"] == 2
    assert fail.call_args.kwargs["rows_loaded"] == 0

    complete.assert_not_called()
