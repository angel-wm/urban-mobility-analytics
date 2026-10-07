# Urban Mobility Analytics Pipeline

[![CI](https://github.com/angel-wm/urban-mobility-analytics/actions/workflows/ci.yml/badge.svg)](https://github.com/angel-wm/urban-mobility-analytics/actions/workflows/ci.yml)

An end-to-end data engineering and analytics portfolio project built on NYC
Yellow Taxi trip data using Python, PostgreSQL, Docker, SQL, pytest, GitHub
Actions, and Power BI.

The repository demonstrates how raw trip records move through reproducible
ingestion, explicit data-quality classification, analytical and dimensional
models, query optimization, automated validation, continuous integration, and
a Power BI reporting layer. It is most useful to readers evaluating an
end-to-end analytics project or looking for implementation evidence for a
similar data pipeline.

## What this project demonstrates

- Idempotent Parquet ingestion with execution metadata and row-count checks.
- Raw-data preservation followed by explicit staging quality flags instead of
  silently deleting analytical anomalies.
- PostgreSQL analytical views, summary marts, and a trip-level star schema.
- Measured query optimization while retaining independent reconciliation paths.
- Unit and PostgreSQL integration tests executed locally and in GitHub Actions.
- A three-page Power BI report stored in Power BI Project (`.pbip`) format.

## Project snapshot

| Item | Current project state |
| --- | --- |
| Source scope | NYC TLC Yellow Taxi, January 2025 |
| Source records | 3,475,226 |
| Development sample | 5,000 version-controlled rows |
| Fact table | 3,480,226 rows, including the sample and complete monthly ingestion |
| Automated tests | 33 unit tests and 9 PostgreSQL integration tests |
| Power BI | Three analytical report pages |
| Core pipeline status | Ingestion, staging, analytics, marts, dimensional model, optimization, tests, CI, and dashboard complete |

The complete source Parquet file is not version-controlled. The small
development sample is included so the database model and CI path can be
reconstructed without loading the full monthly dataset.

## Quick start

For the fastest local verification path, run the default test suite. These
commands use PowerShell syntax.

```powershell
git clone https://github.com/angel-wm/urban-mobility-analytics.git
cd urban-mobility-analytics

python -m venv .venv
.\.venv\Scripts\Activate.ps1

python -m pip install --upgrade pip
pip install -r requirements-lock.txt

python -m pytest -v
```

The default suite does not require PostgreSQL. To reconstruct the database from
the version-controlled sample, build every SQL layer, and run integration
validation, follow [Local Setup and Commands](docs/local_setup.md).

## Architecture

```text
NYC TLC Yellow Taxi Parquet files
                |
                v
      Python ingestion pipeline
                |
                v
         PostgreSQL raw
                |
                v
       PostgreSQL staging
                |
        +-------+----------------------+
        |                              |
        v                              v
analytics.daily/hourly         dimensional model
validation views              dimensions + fact_trip
        |                              |
        |                              v
        |                     optimized mart views
        |                              |
        +------ reconciliation --------+
                                       |
                                       v
                                  Power BI
```

The staging layer standardizes the raw records and exposes explicit quality
flags. From staging, the project keeps analytical views as independent
validation references while the dimensional model and optimized marts provide
the primary consumption path for Power BI.

For deeper implementation details, see the
[ingestion pipeline](docs/ingestion_pipeline.md),
[staging model](docs/staging_model.md),
[analytics and marts](docs/analytics_and_marts.md), and
[dimensional model](docs/dimensional_model.md).

## Data quality approach

The raw layer preserves source values whenever they can be represented
technically. Negative monetary values, zero distance, unusual timestamps, and
other analytical anomalies are classified through explicit flags rather than
silently removed during ingestion.

Downstream analyses can therefore apply metric-specific eligibility rules while
retaining source traceability. The rules, categorical-code handling, and
remaining limitations are documented in
[Data Quality Rules](docs/data_quality_rules.md).

## Query optimization and validation

The final daily and hourly marts aggregate from the dimensional fact table and
dimensions, while the original staging-based `analytics` views remain
available for reconciliation.

The optimization work includes measured execution plans, before-and-after
timings, index evaluation, architectural decisions, and validation evidence.
See [Query Optimization](docs/query_optimization.md) for the complete
benchmarks and reproduction commands.

Automated validation is documented separately in
[Automated Tests](docs/automated_tests.md) and
[Continuous Integration](docs/continuous_integration.md).

## Power BI dashboard

The Power BI report is version-controlled under `powerbi/` and contains three
analytical views built on the PostgreSQL dimensional model and optimized marts.

### Executive Overview

High-level view of trip volume, revenue, average trip performance, vendor mix,
payment behavior, and daily mobility trends.

![Executive Overview](docs/Images/dashboard_executive_overview.png)

### Demand Patterns

Analysis of taxi demand across hours, day periods, weekdays, and combined
day-hour patterns.

![Demand Patterns](docs/Images/dashboard_demand_patterns.png)

### Revenue & Quality

Revenue composition together with transaction-quality indicators and
operational data-quality conditions.

![Revenue & Quality](docs/Images/dashboard_revenue_quality.png)

The screenshots are visual evidence of the current report. The underlying
semantic model and report definitions remain available in Power BI Project
format under `powerbi/`.

## Documentation map

| If you want to... | Read |
| --- | --- |
| Reconstruct the project or find operational commands | [Local Setup and Commands](docs/local_setup.md) |
| Understand raw ingestion, idempotency, and failure handling | [Raw Ingestion Pipeline](docs/ingestion_pipeline.md) |
| Review quality rules and flag semantics | [Data Quality Rules](docs/data_quality_rules.md) |
| Inspect the completed raw SQL profile | [Raw Data SQL Profile](docs/sql_raw_data_profile.md) |
| Understand staging transformations and validation | [Staging Taxi Trips Model](docs/staging_model.md) |
| Review daily/hourly analytics and consumption marts | [Analytics and Marts Models](docs/analytics_and_marts.md) |
| Understand the star schema and fact/dimension grain | [Dimensional Model](docs/dimensional_model.md) |
| Review performance measurements and optimization decisions | [Query Optimization](docs/query_optimization.md) |
| Inspect pytest coverage and local validation | [Automated Tests](docs/automated_tests.md) |
| Understand the GitHub Actions reconstruction path | [Continuous Integration](docs/continuous_integration.md) |

## Repository structure

```text
urban-mobility-analytics/
├── .github/workflows/          # CI
├── data/
│   ├── raw/
│   └── sample/                 # version-controlled development sample
├── docs/                       # technical documentation and screenshots
├── notebooks/                  # exploratory analysis
├── powerbi/                    # PBIP report and semantic model
├── sql/
│   ├── analysis/
│   ├── analytics/
│   ├── ddl/
│   ├── dimensional/
│   ├── init/
│   ├── marts/
│   ├── optimization/
│   └── staging/
├── src/                        # ingestion and transformation utilities
└── tests/                      # unit and PostgreSQL integration tests
```

## Completed scope

- Repository and local environment.
- Dockerized PostgreSQL.
- Initial data exploration.
- Raw ingestion and idempotent processing.
- SQL exploration and profiling.
- Staging transformations and data-quality flags.
- Dimensional model and analytical marts.
- Query optimization.
- Automated unit and integration tests.
- Power BI dashboard.
- Continuous integration.

## Dataset and limitations

This project uses NYC Taxi and Limousine Commission Yellow Taxi trip records.

The complete monthly source files are not included in the repository. Only the
5,000-row development sample required for lightweight reconstruction and CI
validation is version-controlled.

The documented setup commands use PowerShell syntax. Detailed model,
quality-rule, testing, and optimization limitations remain in their respective
technical documents so the README does not duplicate changing reference data.

## Author

Angel Miller — [@angel-wm](https://github.com/angel-wm)
