# Automated Tests

## Overview

The project uses pytest to automate validation of the Python ingestion pipeline
and selected PostgreSQL analytical invariants.

The test suite is divided into two layers:

- unit tests, which run without PostgreSQL or Docker;
- integration tests, which execute read-only queries against the local
  PostgreSQL database.

This separation keeps the default test suite fast while still allowing the
database model and analytical marts to be validated against the real project
environment.

## Test Configuration

Pytest is configured in the repository-level `pytest.ini` file.

The `integration` marker identifies tests that require PostgreSQL.

By default, integration tests are excluded:

    python -m pytest

Integration tests are executed explicitly with:

    python -m pytest -m integration

This means the normal test suite does not require Docker or PostgreSQL to be
running.

## Current Test Suite

The completed suite contains 42 tests:

- 33 unit tests;
- 9 PostgreSQL integration tests.

### Unit Tests

#### `tests/test_raw_taxi.py`

4 tests cover the raw Yellow Taxi DataFrame transformation logic:

- required source-column validation;
- final raw schema and column order;
- numeric, datetime, and string normalization;
- coercion of invalid values to null values;
- removal of unexpected source columns.

#### `tests/test_parquet_reader.py`

8 tests cover Parquet input handling:

- valid Parquet paths;
- missing files;
- directory paths;
- invalid file extensions;
- Parquet metadata;
- row-group reading;
- invalid row-group indexes;
- iteration across all row groups.

Temporary Parquet files are created with pytest's `tmp_path` fixture, so the
tests do not depend on the production January 2025 dataset.

#### `tests/test_database.py`

5 tests cover database configuration:

- required environment variables;
- missing environment variables;
- empty environment variables;
- SQLAlchemy PostgreSQL URL construction;
- invalid PostgreSQL port values.

The tests use pytest `monkeypatch` and do not expose or modify the real database
password.

#### `tests/test_raw_loader.py`

9 tests cover the raw database loader using mocked SQLAlchemy objects:

- creation of ingestion records;
- insertion of `ingestion_id` before loading;
- successful ingestion completion;
- invalid completion updates;
- invalid failure updates;
- lookup of completed ingestions;
- missing completed ingestions;
- recording skipped ingestions;
- deletion-count handling for partial raw loads.

These tests do not write to the real PostgreSQL database.

#### `tests/test_load_month.py`

4 tests cover monthly-ingestion orchestration:

- idempotent skip behavior when a matching completed ingestion exists;
- successful multi-row-group ingestion;
- row-count reconciliation failure;
- cleanup and failure recording when loading raises an exception.

Dependencies such as the Parquet reader, database engine, transformation
functions, and raw loader are replaced with mocks during these tests.

#### `tests/test_download_data.py`

3 tests cover dataset-download behavior:

- skipping a download when the destination already exists;
- writing streamed chunks to disk;
- deleting a partially downloaded file after a request failure.

Network requests are mocked, so these tests do not access the Internet.

## Integration Tests

Integration tests are stored under `tests/integration/` and use the real local
PostgreSQL database.

All implemented integration tests are read-only. They execute `SELECT`
statements and do not insert, update, delete, create, or replace database
objects.

### `tests/integration/test_database_model.py`

4 tests validate core database and dimensional-model invariants:

- required schemas `raw`, `staging`, `analytics`, and `marts` exist;
- `marts.fact_trip` has one row per `raw_trip_id`;
- staging and fact-table row counts reconcile by ingestion;
- fact-table dimension keys have no orphaned dimension references.

These checks automate important invariants previously validated manually by the
dimensional-model SQL validation scripts.

### `tests/integration/test_analytical_marts.py`

5 tests validate analytical mart behavior:

- `marts.daily_mobility_summary` preserves its expected daily grain;
- `marts.hourly_demand_profile` preserves its expected hourly grain;
- daily mart trip counts reconcile with the independent daily analytics layer;
- hourly mart trip counts reconcile with the independent hourly analytics
  layer;
- both final marts continue using the optimized `marts.fact_trip` source rather
  than reverting to the historical staging-based analytics definitions.

The final check protects the query-optimization work from accidental regression
if the historical base mart SQL files are executed after the optimized
overrides.

## Shared Database Fixture

`tests/conftest.py` provides the session-scoped `db_engine` fixture.

The fixture obtains the SQLAlchemy engine through the project's existing
`src.database.get_engine()` function and disposes of the engine after the test
session.

No separate testing credentials or duplicated database-connection logic are
introduced.

## Validation Results

The final local validation produced:

    python -m pytest -v
    33 passed, 9 deselected

and:

    python -m pytest -m integration -v
    9 passed, 33 deselected

A total of 42 tests are therefore discovered by pytest.

The final integration suite completed successfully against PostgreSQL 17.10
with the current project data and dimensional model.

Code-quality validation also succeeded:

    ruff check src tests
    All checks passed!

and:

    ruff format --check tests
    9 files already formatted

## Recommended Commands

Run the fast default unit suite:

    python -m pytest -v

Run PostgreSQL integration tests:

    python -m pytest -m integration -v

Run all tests, including integration tests, in one command:

    python -m pytest -m "not integration or integration" -v

Check Python code quality:

    ruff check src tests

Check test formatting:

    ruff format --check tests

## Scope and Limitations

The Automated Tests stage intentionally does not introduce:

- continuous integration;
- GitHub Actions;
- test-coverage dependencies or coverage thresholds;
- performance benchmark thresholds;
- destructive database integration tests;
- a separate test database;
- automated Power BI validation.

Continuous integration remains a later roadmap item.

The integration suite currently validates the existing local PostgreSQL model
and therefore requires the database container and project schemas to already be
available.

The automated tests complement the detailed SQL validation scripts already
present in the repository; they do not replace those scripts.
