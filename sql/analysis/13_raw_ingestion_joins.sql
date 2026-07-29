SELECT
    t.raw_trip_id,
    t.pickup_datetime,
    t.trip_distance,
    t.total_amount,
    l.ingestion_id,
    l.source_file_name,
    l.taxi_type,
    l.period_year,
    l.period_month,
    l.status
FROM raw.taxi_trips AS t
INNER JOIN raw.ingestion_log AS l
    ON l.ingestion_id = t.ingestion_id
WHERE t.ingestion_id = 7
ORDER BY t.raw_trip_id
LIMIT 10;

SELECT
    l.ingestion_id,
    l.source_file_name,
    l.status,
    l.rows_loaded,
    COUNT(t.raw_trip_id) AS database_trip_count
FROM raw.ingestion_log AS l
LEFT JOIN raw.taxi_trips AS t
    ON t.ingestion_id = l.ingestion_id
GROUP BY
    l.ingestion_id,
    l.source_file_name,
    l.status,
    l.rows_loaded
ORDER BY l.ingestion_id;

SELECT
    COUNT(*) AS orphan_trip_rows
FROM raw.taxi_trips AS t
LEFT JOIN raw.ingestion_log AS l
    ON l.ingestion_id = t.ingestion_id
WHERE l.ingestion_id IS NULL;