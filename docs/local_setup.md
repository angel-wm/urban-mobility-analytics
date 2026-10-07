# Local Setup and Commands

This guide contains the reproducible local procedure and command reference that
previously lived in the repository README. It is separated here so the README
can remain an entry point while the complete operational steps stay available.

The commands below use PowerShell syntax. The database workflow uses the
repository's Docker Compose configuration, `.env.example`, pinned Python
dependencies, version-controlled SQL, and the 5,000-row development sample.

[Return to the repository README](../README.md).

## Full PostgreSQL reconstruction

The following steps reconstruct the development environment and analytical
database from the version-controlled repository contents.

### 1. Clone the repository

```powershell
git clone https://github.com/angel-wm/urban-mobility-analytics.git
cd urban-mobility-analytics
```

### 2. Create the environment file

Copy `.env.example` to `.env` and provide the local PostgreSQL credentials.

```powershell
Copy-Item .env.example .env
```

### 3. Create and activate the Python environment

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

### 4. Install dependencies

For a reproducible development environment, install the pinned dependency set:

```powershell
python -m pip install --upgrade pip
pip install -r requirements-lock.txt
```

### 5. Start PostgreSQL

```powershell
docker compose up -d
```

Verify that the database container is healthy:

```powershell
docker compose ps
```

### 6. Create the database schemas and raw tables

```powershell
Get-Content -Raw .\sql\init\01_create_schemas.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\ddl\01_create_raw_tables.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db
```

### 7. Load the development sample

```powershell
python -m src.ingestion.load_sample
```

The development sample provides a small reproducible dataset for validating the
database model without loading the complete monthly dataset.

### 8. Create the staging layer

```powershell
Get-Content -Raw .\sql\staging\01_create_staging_taxi_trips.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db
```

### 9. Create the analytics layer

```powershell
Get-Content -Raw .\sql\analytics\01_create_daily_trip_metrics.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\analytics\03_create_hourly_trip_metrics.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db
```

### 10. Create the base analytical marts

```powershell
Get-Content -Raw .\sql\marts\01_create_daily_mobility_summary.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\marts\03_create_hourly_demand_profile.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db
```

### 11. Build the dimensional model

```powershell
Get-Content -Raw .\sql\dimensional\01_create_dimensional_tables.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\dimensional\02_load_dimensions.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\dimensional\03_load_fact_trip.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db
```

### 12. Apply query optimizations

```powershell
Get-Content -Raw .\sql\optimization\01_create_query_optimization_indexes.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db

Get-Content -Raw .\sql\optimization\02_optimize_mart_views.sql |
    docker compose exec -T db psql `
        -v ON_ERROR_STOP=1 `
        -U mobility_user `
        -d mobility_db
```

The optimization scripts are applied after the dimensional model because the
final mart definitions use the optimized fact-based query paths.

### 13. Validate the complete database model

```powershell
python -m pytest -m integration -v
```

The integration suite validates database schemas, analytical mart grain and
reconciliation, dimensional grain, row-count reconciliation, and referential
integrity.

## Main commands

Check the PostgreSQL connection:

```powershell
python -m src.check_connection
```

Download the January 2025 dataset:

```powershell
python -m src.ingestion.download_data
```

Check the Parquet reader:

```powershell
python -m src.ingestion.check_parquet_reader
```

Load the development sample:

```powershell
python -m src.ingestion.load_sample
```

Load the complete month:

```powershell
python -m src.ingestion.load_month
```

Verify the completed monthly ingestion:

```powershell
python -m src.ingestion.check_month_ingestion
```

Run the default unit test suite:

```powershell
python -m pytest -v
```

Run PostgreSQL integration tests:

```powershell
python -m pytest -m integration -v
```

Run code-quality checks:

```powershell
ruff check src tests
ruff format --check src tests
```

## Related documentation

- [Automated tests](automated_tests.md) explains the default and integration
  test suites, expected validation scope, and limitations.
- [Continuous integration](continuous_integration.md) explains how GitHub
  Actions reconstructs and validates the project in CI.
- [Ingestion pipeline](ingestion_pipeline.md) documents the raw ingestion
  workflow and operational behavior.
