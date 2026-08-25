# Continuous Integration

## Overview

The project uses GitHub Actions to automatically validate code quality, unit
tests, and the PostgreSQL-backed analytical model.

The workflow is defined in:

    .github/workflows/ci.yml

The CI environment is intentionally independent from the developer's local
`mobility_db` database. Integration validation reconstructs a clean PostgreSQL
database from version-controlled project assets and the 5,000-row development
sample.

## Triggers

The workflow runs on:

- pushes to `main`
- pull requests targeting `main`
- manual execution through `workflow_dispatch`

This allows the same validation pipeline to run automatically during normal
development and manually when an explicit verification is required.

## CI Jobs

The workflow contains two independent jobs.

### Quality and unit tests

The `quality-and-unit` job runs on Ubuntu and uses Python 3.12.10.

It performs:

1. Repository checkout.
2. Python setup.
3. Installation from `requirements-lock.txt`.
4. Ruff lint validation:

    ruff check src tests

5. Ruff formatting validation:

    ruff format --check tests

6. Default pytest execution:

    python -m pytest -v

The default pytest configuration excludes tests marked as `integration`.

The current default suite contains 33 unit tests.

### PostgreSQL integration tests

The `integration` job runs independently on Ubuntu with a PostgreSQL 17
service container.

The database is ephemeral and exists only for the duration of the GitHub
Actions job.

The workflow defines CI-only PostgreSQL credentials and connects through
`localhost:5432`. These credentials do not correspond to the developer's local
database and do not require GitHub repository secrets.

The database reconstruction sequence is:

1. Create PostgreSQL schemas.
2. Create raw tables and indexes.
3. Load the version-controlled 5,000-row development sample.
4. Create the staging layer.
5. Create the analytics layer.
6. Create the base analytical marts.
7. Create and populate the dimensional model.
8. Apply query-optimization indexes.
9. Replace the base marts with their optimized fact-based definitions.
10. Run the PostgreSQL integration test suite.

The SQL execution order is important. In particular,
`sql/optimization/02_optimize_mart_views.sql` must run after the original mart
definitions so that the final views use `marts.fact_trip`.

The integration suite is executed with:

    python -m pytest -m integration -v

The current integration suite contains 9 tests.

## Development Sample

CI does not load the complete NYC Yellow Taxi dataset.

Instead, it uses:

    data/sample/yellow_tripdata_2025-01_sample.parquet

The sample contains 5,000 rows and is committed to the repository.

This keeps CI lightweight while still exercising the real ingestion code,
PostgreSQL schemas, staging transformations, analytical views, dimensional
model, query optimizations, and integration tests.

During validation of the CI design, a clean temporary database named
`mobility_ci` was reconstructed locally from the same repository assets.

The clean local database produced:

- 5,000 raw rows
- 5,000 staging rows
- 5,000 fact rows
- 12 date dimension rows
- 24 hour dimension rows
- 1 ingestion dimension row
- 3 vendor dimension rows
- 6 rate-code dimension rows
- 4 payment-type dimension rows
- 2 store-and-forward dimension rows
- 12 daily mart rows
- 24 hourly mart rows

All 9 PostgreSQL integration tests passed against that clean environment.

## Dependency Reproducibility

GitHub Actions installs Python dependencies from:

    requirements-lock.txt

This provides deterministic package versions for the CI environment instead
of resolving new versions on every workflow execution.

The validated CI environment uses Python 3.12.10.

## Validation Results

The initial GitHub Actions workflow was introduced in commit:

    d48ed57 ci: add automated quality and integration checks

The first execution was triggered automatically by a push to `main`.

Result:

    Status: Success
    Quality and unit tests: passed
    PostgreSQL integration tests: passed
    Total workflow duration: 1m 7s

A second execution was started manually through `workflow_dispatch`.

Result:

    Status: Success
    Quality and unit tests: passed
    PostgreSQL integration tests: passed
    Total workflow duration: 1m 10s

These executions demonstrate that the repository can be validated on a clean
GitHub-hosted runner without relying on the developer's existing PostgreSQL
database.

## Local Equivalent

The main local quality commands remain:

    ruff check src tests
    ruff format --check tests
    python -m pytest -v

PostgreSQL integration tests can be run against a prepared local database with:

    python -m pytest -m integration -v

The GitHub Actions integration job additionally reconstructs its PostgreSQL
environment automatically before executing those tests.

## Scope and Limitations

The workflow validates the Python and PostgreSQL analytical pipeline.

It does not:

- download or process the complete production-scale NYC TLC dataset
- execute Power BI Desktop
- validate visual rendering of the Power BI report
- deploy infrastructure or databases
- publish application artifacts

Power BI source files remain version-controlled in the repository, while CI is
focused on the reproducible data pipeline and automated test suite.
