# Raw Ingestion Pipeline

## Purpose

The raw ingestion pipeline loads NYC Yellow Taxi Parquet files into PostgreSQL
while preserving source values, recording execution metadata, preventing
accidental duplicate loads, and cleaning up partial failed ingestions.

## Pipeline Flow

```text
NYC TLC Parquet file
        |
        v
Validate the path and read Parquet metadata
        |
        v
Search for a matching completed ingestion
        |
        +---- Match found ----> Record a skipped execution
        |
        v
Create a started ingestion record
        |
        v
Read one Parquet row group
        |
        v
Validate, rename, and convert source columns
        |
        v
Append rows to raw.taxi_trips
        |
        v
Repeat for every row group
        |
        v
Compare source, read, and loaded row counts
        |
        v
Mark the ingestion as completed
```

## Main Components

- `src/ingestion/parquet_reader.py`: validates Parquet paths, reads metadata,
  reads individual row groups, and iterates through complete Parquet files.
- `src/transformations/raw_taxi.py`: validates source columns, normalizes column
  names, converts data types, and orders columns for the raw database table.
- `src/ingestion/raw_loader.py`: creates and updates ingestion records, loads
  trip rows, detects completed source files, records skipped executions, and
  removes partial rows from failed ingestions.
- `src/ingestion/load_sample.py`: loads the small development sample into the
  raw PostgreSQL tables.
- `src/ingestion/load_month.py`: loads the complete monthly dataset by processing
  one Parquet row group at a time.
- `src/ingestion/check_month_ingestion.py`: compares Parquet metadata,
  ingestion-log values, and actual database row counts.

## Database Tables

### `raw.ingestion_log`

Stores one row per pipeline execution.

The table records:

- Source file name
- Taxi type
- Processing year and month
- File size in bytes
- Execution status
- Rows read
- Rows loaded
- Rows rejected
- Start and completion timestamps
- Error information

The supported execution statuses are:

```text
started
completed
failed
skipped
```

### `raw.taxi_trips`

Stores source Yellow Taxi trip records.

Each row contains an `ingestion_id` that identifies the pipeline execution that
loaded it.

PostgreSQL generates the following technical columns:

- `raw_trip_id`: unique surrogate key for each stored trip row.
- `loaded_at`: timestamp indicating when the row was inserted.

The source file does not provide a direct unique trip identifier. Therefore,
`raw_trip_id` identifies the stored database row, not necessarily a unique
real-world taxi trip.

## Source Column Preparation

Before inserting data into PostgreSQL, the pipeline:

1. Validates that all required source columns exist.
2. Renames source columns to the database naming convention.
3. Converts integer, datetime, floating-point, and text columns.
4. Orders the columns according to the `raw.taxi_trips` table.
5. Removes derived notebook columns that do not belong to the raw source layer.

Example column mappings include:

```text
VendorID               -> vendor_id
tpep_pickup_datetime    -> pickup_datetime
tpep_dropoff_datetime   -> dropoff_datetime
PULocationID            -> pickup_location_id
DOLocationID            -> dropoff_location_id
Airport_fee             -> airport_fee
```

The raw table does not store the notebook-derived columns:

```text
trip_duration_minutes
average_speed_mph
```

Those values will be calculated in later transformation layers.

## Row Group Processing

The complete monthly Parquet file is not loaded into memory all at once.

Instead, the pipeline processes one Parquet row group at a time:

```text
Read row group
      |
      v
Convert to pandas DataFrame
      |
      v
Prepare names and types
      |
      v
Insert into PostgreSQL
      |
      v
Release the block and continue
```

For the January 2025 Yellow Taxi file, the pipeline processed four row groups:

```text
Row group 1: 1,048,576 rows
Row group 2: 1,048,576 rows
Row group 3: 1,048,576 rows
Row group 4:   329,498 rows
```

Total:

```text
3,475,226 rows
```

This approach reduces memory usage and makes the ingestion process suitable for
larger source files.

## Idempotency

The ingestion pipeline prevents accidental duplicate loading.

A source file is considered previously completed when the following values
match an existing completed ingestion:

- Source file name
- Taxi type
- Period year
- Period month
- File size in bytes

When a completed match exists:

1. The source rows are not inserted again.
2. A new ingestion-log row is created with the status `skipped`.
3. The previously completed ingestion ID is displayed.

Example:

```text
Monthly ingestion skipped
Matching completed ingestion: 7
Skipped ingestion record: 8
```

The skipped execution contains zero loaded rows.

This is the initial idempotency strategy. File size is not a cryptographic
identifier, so a future version may include a file checksum such as SHA-256.

## Failure Handling

Every row group is inserted using a database transaction.

If an error occurs while inserting a row group:

- The current transaction is rolled back.
- Rows previously loaded for the same ingestion are deleted.
- The ingestion is marked as `failed`.
- The error message is saved in `raw.ingestion_log`.
- The original exception is raised again.

The cleanup operation uses the ingestion identifier:

```sql
DELETE FROM raw.taxi_trips
WHERE ingestion_id = :ingestion_id;
```

This prevents a failed ingestion from leaving partial trip data in the raw
table.

An abrupt system shutdown may still leave an ingestion with the status
`started`. Automatic recovery for abandoned executions may be added later.

## Row Count Validation

Before marking a monthly ingestion as completed, the pipeline verifies:

```text
Rows reported by Parquet metadata
        =
Rows read by Python
        =
Rows loaded into PostgreSQL
```

For the January 2025 dataset:

```text
Parquet rows:   3,475,226
Rows read:      3,475,226
Rows loaded:    3,475,226
Rows rejected:          0
```

The verification script also compares the ingestion log with the real number
of rows stored in `raw.taxi_trips`.

The following checks must pass:

```text
Ingestion status is completed
Source file name matches
Source file size matches
Parquet rows match rows_read
rows_read matches rows_loaded
rows_loaded matches the database count
rows_rejected is zero
```

## Raw-Layer Principle

The raw layer preserves source values whenever they can be stored technically.

The ingestion pipeline does not remove records only because they contain:

- Negative monetary values
- Zero trip distance
- Unusually high calculated speed
- Pickup timestamps outside the expected period
- Suspicious categorical codes

These records may still represent refunds, reversals, corrections,
administrative transactions, or other legitimate source activity.

Data-quality flags and analytical exclusions will be implemented in the
`staging` and `analytics` layers.

## Current Loaded Data

The raw database currently contains:

```text
Development sample:      5,000 rows
January monthly file: 3,475,226 rows
Total raw trip rows:  3,480,226 rows
```

Skipped executions contain no trip rows.

## Commands

### Start PostgreSQL

```powershell
docker compose up -d
```

### Check the database connection

```powershell
python -m src.check_connection
```

### Download the monthly source file

```powershell
python -m src.ingestion.download_data
```

### Check the reusable Parquet reader

```powershell
python -m src.ingestion.check_parquet_reader
```

### Check source column preparation

```powershell
python -m src.transformations.check_raw_taxi
```

### Load the development sample

```powershell
python -m src.ingestion.load_sample
```

### Load the complete monthly file

```powershell
python -m src.ingestion.load_month
```

### Verify the completed monthly ingestion

```powershell
python -m src.ingestion.check_month_ingestion
```

### Review ingestion executions

```powershell
docker compose exec db psql -U mobility_user -d mobility_db -c "SELECT ingestion_id, source_file_name, status, rows_read, rows_loaded, rows_rejected FROM raw.ingestion_log ORDER BY ingestion_id;"
```

### Review trip counts by ingestion

```powershell
docker compose exec db psql -U mobility_user -d mobility_db -c "SELECT l.ingestion_id, l.source_file_name, l.status, COUNT(t.raw_trip_id) AS trip_count FROM raw.ingestion_log AS l LEFT JOIN raw.taxi_trips AS t ON t.ingestion_id = l.ingestion_id GROUP BY l.ingestion_id, l.source_file_name, l.status ORDER BY l.ingestion_id;"
```

### Check for orphan trip records

```powershell
docker compose exec db psql -U mobility_user -d mobility_db -c "SELECT COUNT(*) AS orphan_trips FROM raw.taxi_trips AS t LEFT JOIN raw.ingestion_log AS l ON l.ingestion_id = t.ingestion_id WHERE l.ingestion_id IS NULL;"
```

The expected orphan count is:

```text
0
```

### Check code quality

```powershell
ruff check src
ruff format --check src
```

## Current Limitations

- Idempotency uses file metadata rather than a cryptographic checksum.
- The pipeline currently targets one fixed Yellow Taxi month.
- The taxi type, year, month, and file path are constants in the scripts.
- Failed rows are not yet written to a dedicated rejection table.
- Analytical quality rules have not yet been implemented in SQL.
- Automatic recovery for abandoned `started` ingestions is not yet available.
- Database insertion currently uses pandas `to_sql`, which may later be
  replaced or optimized for larger production workloads.

## Next Phase

The next phase will use SQL to analyze and transform the raw data.

It will include:

- Filtering
- Aggregations
- Grouping
- Null analysis
- Date and time calculations
- Joins with the ingestion log
- Data-quality queries
- Preparation for the `staging` layer