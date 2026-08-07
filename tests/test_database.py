import pytest

from src.database import (
    build_database_url,
    get_required_environment_variable,
)


def set_database_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("POSTGRES_USER", "test_user")
    monkeypatch.setenv("POSTGRES_PASSWORD", "test_password")
    monkeypatch.setenv("POSTGRES_HOST", "localhost")
    monkeypatch.setenv("POSTGRES_PORT", "5433")
    monkeypatch.setenv("POSTGRES_DB", "test_database")


def test_get_required_environment_variable_returns_value(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("TEST_VARIABLE", "expected_value")

    value = get_required_environment_variable("TEST_VARIABLE")

    assert value == "expected_value"


def test_get_required_environment_variable_rejects_missing_value(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("TEST_VARIABLE", raising=False)

    with pytest.raises(ValueError, match="TEST_VARIABLE"):
        get_required_environment_variable("TEST_VARIABLE")


def test_get_required_environment_variable_rejects_empty_value(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("TEST_VARIABLE", "")

    with pytest.raises(ValueError, match="TEST_VARIABLE"):
        get_required_environment_variable("TEST_VARIABLE")


def test_build_database_url_uses_environment_variables(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    set_database_environment(monkeypatch)

    database_url = build_database_url()

    assert database_url.drivername == "postgresql+psycopg"
    assert database_url.username == "test_user"
    assert database_url.password == "test_password"
    assert database_url.host == "localhost"
    assert database_url.port == 5433
    assert database_url.database == "test_database"


def test_build_database_url_rejects_non_integer_port(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    set_database_environment(monkeypatch)
    monkeypatch.setenv("POSTGRES_PORT", "invalid")

    with pytest.raises(
        ValueError,
        match="POSTGRES_PORT must contain an integer",
    ):
        build_database_url()
