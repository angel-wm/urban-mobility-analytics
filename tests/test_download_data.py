from unittest.mock import MagicMock

import pytest
from requests.exceptions import RequestException

from src.ingestion import download_data


def test_download_file_skips_existing_file(
    tmp_path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    destination = tmp_path / "existing.parquet"
    destination.write_bytes(b"existing data")

    get_mock = MagicMock()
    monkeypatch.setattr(download_data.requests, "get", get_mock)

    download_data.download_file(
        url="https://example.com/file.parquet",
        destination=destination,
    )

    assert destination.read_bytes() == b"existing data"
    get_mock.assert_not_called()

    output = capsys.readouterr().out
    assert "File already exists" in output


def test_download_file_writes_received_chunks(
    tmp_path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    destination = tmp_path / "nested" / "sample.parquet"

    response = MagicMock()
    response.__enter__.return_value = response
    response.iter_content.return_value = [
        b"first",
        b"",
        b"second",
    ]

    get_mock = MagicMock(return_value=response)
    monkeypatch.setattr(download_data.requests, "get", get_mock)

    download_data.download_file(
        url="https://example.com/file.parquet",
        destination=destination,
    )

    assert destination.read_bytes() == b"firstsecond"

    get_mock.assert_called_once_with(
        "https://example.com/file.parquet",
        stream=True,
        timeout=60,
    )

    response.raise_for_status.assert_called_once()
    response.iter_content.assert_called_once_with(
        chunk_size=download_data.CHUNK_SIZE_BYTES
    )


def test_download_file_removes_partial_file_after_request_error(
    tmp_path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    destination = tmp_path / "sample.parquet"

    def broken_chunks():
        yield b"partial data"
        raise RequestException("network failure")

    response = MagicMock()
    response.__enter__.return_value = response
    response.iter_content.return_value = broken_chunks()

    monkeypatch.setattr(
        download_data.requests,
        "get",
        MagicMock(return_value=response),
    )

    with pytest.raises(SystemExit) as error:
        download_data.download_file(
            url="https://example.com/file.parquet",
            destination=destination,
        )

    assert error.value.code == 1
    assert not destination.exists()
