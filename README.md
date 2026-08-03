# Urban Mobility Analytics Pipeline

A data engineering and analytics portfolio project that processes NYC Yellow
Taxi trip data using Python, PostgreSQL, Docker, SQL, and Power BI.

The project is designed to demonstrate reproducible data ingestion, data
quality controls, SQL transformation, analytical modeling, and dashboard
development using a production-oriented repository structure.

## Current Status

The raw ingestion, SQL profiling, staging, analytics, and analytical marts
layers are complete.

The January 2025 Yellow Taxi dataset contains:

- 3,475,226 source records
- 20 source columns
- 4 Parquet row groups
- 0 technically rejected records during raw ingestion
- 3,475,204 records inside the expected January 2025 pickup period
- 22 records with pickup timestamps outside the expected period

The pipeline also includes a 5,000-row development sample for lightweight
testing and exploration.

The current PostgreSQL analytical models include:

- `staging.taxi_trips`
- `analytics.daily_trip_metrics`
- `analytics.hourly_trip_metrics`
- `marts.daily_mobility_summary`
- `marts.hourly_demand_profile`

The analytics and marts layers provide daily and hourly metrics, conditional
aggregations, cumulative totals, period shares, rankings, previous-period
comparisons, and rolling averages.

See [`docs/staging_model.md`](docs/staging_model.md) and
[`docs/analytics_and_marts.md`](docs/analytics_and_marts.md) for the detailed
model definitions and validation results.

## Architecture

```text
NYC TLC Parquet files
        |
        v
Python download and validation
        |
        v
Row-group-based ingestion
        |
        v
PostgreSQL
    raw
        |
        v
    staging
        |
        +-------------------+
        |                   |
        v                   v
    analytics.daily     analytics.hourly
        |                   |
        v                   v
    marts.daily         marts.hourly
        |
        v
Python EDA and Power BI
```

## Technology Stack

- Python
- pandas
- NumPy
- PyArrow
- SQLAlchemy
- psycopg
- PostgreSQL
- Docker and Docker Compose
- Ruff
- pytest
- Power BI

## Repository Structure

```text
urban-mobility-analytics/
├── data/
│   ├── raw/
│   └── sample/
├── docs/
├── notebooks/
├── sql/
│   ├── analysis/
│   ├── analytics/
│   ├── ddl/
│   ├── init/
│   ├── marts/
│   └── staging/
├── src/
│   ├── ingestion/
│   └── transformations/
├── tests/
├── .env.example
├── .gitignore
├── docker-compose.yml
├── requirements.txt
└── requirements-dev.txt
```

## Raw Ingestion Pipeline

The ingestion pipeline:

1. Validates the source Parquet path.
2. Reads file metadata.
3. Checks whether the file was already processed.
4. Creates an ingestion audit record.
5. Processes the file one Parquet row group at a time.
6. Validates and normalizes source columns.
7. Loads records into PostgreSQL.
8. Compares source, read, and loaded row counts.
9. Marks the ingestion as completed, failed, or skipped.
10. Removes partial rows when an ingestion fails.

See [`docs/ingestion_pipeline.md`](docs/ingestion_pipeline.md) for the detailed
workflow.

## Data Quality Approach

The raw layer preserves source values whenever they can be represented
technically.

Records with negative monetary values, zero distance, unusual timestamps, or
other analytical anomalies are not silently deleted during ingestion. These
conditions will be classified and handled in later transformation layers.

See [`docs/data_quality_rules.md`](docs/data_quality_rules.md) for the
preliminary rules.

## Local Setup

### 1. Clone the repository

```powershell
git clone https://github.com/angel-wm/urban-mobility-analytics.git
cd urban-mobility-analytics
```

### 2. Create the environment file

Copy `.env.example` to `.env` and provide the local database credentials.

```powershell
Copy-Item .env.example .env
```

### 3. Create and activate the Python environment

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

### 4. Install dependencies

```powershell
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
```

### 5. Start PostgreSQL

```powershell
docker compose up -d
```

### 6. Create the raw tables

```powershell
Get-Content -Raw sql\ddl\01_create_raw_tables.sql |
    docker compose exec -T db psql `
        -U mobility_user `
        -d mobility_db
```

## Main Commands

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

Run code-quality checks:

```powershell
ruff check src
ruff format --check src
```

## Project Roadmap

- [x] Repository and local environment
- [x] Dockerized PostgreSQL
- [x] Initial data exploration
- [x] Raw ingestion pipeline
- [x] Idempotent file processing
- [x] Ingestion verification
- [x] SQL exploration and profiling
- [x] Staging transformations
- [ ] Dimensional model
- [x] Analytical marts
- [ ] Query optimization
- [ ] Automated tests
- [ ] Power BI dashboard
- [ ] Continuous integration

## Dataset

This project uses NYC Taxi and Limousine Commission Yellow Taxi trip records.

The complete source files are not included in this repository. Only a small
development sample is versioned.

## Author

Angel Miller