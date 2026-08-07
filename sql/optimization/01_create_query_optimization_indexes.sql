-- Create an index for selective fact-table queries by ingestion.
--
-- CONCURRENTLY avoids blocking normal reads and writes while PostgreSQL
-- builds the index. This command cannot run inside an explicit transaction.

CREATE INDEX CONCURRENTLY IF NOT EXISTS
    idx_fact_trip_ingestion_id
ON marts.fact_trip (ingestion_id);
