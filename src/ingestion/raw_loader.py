import pandas as pd
from sqlalchemy import Engine, text


def start_ingestion(
    engine: Engine,
    source_file_name: str,
    taxi_type: str,
    period_year: int,
    period_month: int,
    file_size_bytes: int,
) -> int:
    """Create an ingestion log entry and return its generated ID."""

    statement = text(
        """
        INSERT INTO raw.ingestion_log (
            source_file_name,
            taxi_type,
            period_year,
            period_month,
            file_size_bytes,
            status
        )
        VALUES (
            :source_file_name,
            :taxi_type,
            :period_year,
            :period_month,
            :file_size_bytes,
            'started'
        )
        RETURNING ingestion_id;
        """
    )

    parameters = {
        "source_file_name": source_file_name,
        "taxi_type": taxi_type,
        "period_year": period_year,
        "period_month": period_month,
        "file_size_bytes": file_size_bytes,
    }

    with engine.begin() as connection:
        ingestion_id = connection.execute(
            statement,
            parameters,
        ).scalar_one()

    return int(ingestion_id)


def load_raw_taxi_trips(
    engine: Engine,
    dataframe: pd.DataFrame,
    ingestion_id: int,
    chunk_size: int = 1_000,
) -> int:
    """Append a prepared Yellow Taxi DataFrame to the raw table."""

    dataframe_to_load = dataframe.copy()

    dataframe_to_load.insert(
        loc=0,
        column="ingestion_id",
        value=ingestion_id,
    )

    with engine.begin() as connection:
        dataframe_to_load.to_sql(
            name="taxi_trips",
            schema="raw",
            con=connection,
            if_exists="append",
            index=False,
            chunksize=chunk_size,
            method="multi",
        )

    return len(dataframe_to_load)


def complete_ingestion(
    engine: Engine,
    ingestion_id: int,
    rows_read: int,
    rows_loaded: int,
    rows_rejected: int = 0,
) -> None:
    """Mark an ingestion execution as completed."""

    statement = text(
        """
        UPDATE raw.ingestion_log
        SET
            status = 'completed',
            rows_read = :rows_read,
            rows_loaded = :rows_loaded,
            rows_rejected = :rows_rejected,
            completed_at = CURRENT_TIMESTAMP,
            error_message = NULL
        WHERE ingestion_id = :ingestion_id;
        """
    )

    parameters = {
        "ingestion_id": ingestion_id,
        "rows_read": rows_read,
        "rows_loaded": rows_loaded,
        "rows_rejected": rows_rejected,
    }

    with engine.begin() as connection:
        result = connection.execute(
            statement,
            parameters,
        )

    if result.rowcount != 1:
        raise ValueError(
            "The completed ingestion record could not be updated. "
            f"Ingestion ID: {ingestion_id}."
        )


def fail_ingestion(
    engine: Engine,
    ingestion_id: int,
    error_message: str,
    rows_read: int = 0,
    rows_loaded: int = 0,
    rows_rejected: int = 0,
) -> None:
    """Mark an ingestion execution as failed."""

    statement = text(
        """
        UPDATE raw.ingestion_log
        SET
            status = 'failed',
            rows_read = :rows_read,
            rows_loaded = :rows_loaded,
            rows_rejected = :rows_rejected,
            completed_at = CURRENT_TIMESTAMP,
            error_message = :error_message
        WHERE ingestion_id = :ingestion_id;
        """
    )

    parameters = {
        "ingestion_id": ingestion_id,
        "rows_read": rows_read,
        "rows_loaded": rows_loaded,
        "rows_rejected": rows_rejected,
        "error_message": error_message,
    }

    with engine.begin() as connection:
        result = connection.execute(
            statement,
            parameters,
        )

    if result.rowcount != 1:
        raise ValueError(
            "The failed ingestion record could not be updated. "
            f"Ingestion ID: {ingestion_id}."
        )

def find_completed_ingestion(
    engine: Engine,
    source_file_name: str,
    taxi_type: str,
    period_year: int,
    period_month: int,
    file_size_bytes: int,
) -> int | None:
    """Return a matching completed ingestion ID, if one exists."""

    statement = text(
        """
        SELECT ingestion_id
        FROM raw.ingestion_log
        WHERE
            source_file_name = :source_file_name
            AND taxi_type = :taxi_type
            AND period_year = :period_year
            AND period_month = :period_month
            AND file_size_bytes = :file_size_bytes
            AND status = 'completed'
        ORDER BY ingestion_id DESC
        LIMIT 1;
        """
    )

    parameters = {
        "source_file_name": source_file_name,
        "taxi_type": taxi_type,
        "period_year": period_year,
        "period_month": period_month,
        "file_size_bytes": file_size_bytes,
    }

    with engine.connect() as connection:
        ingestion_id = connection.execute(
            statement,
            parameters,
        ).scalar_one_or_none()

    if ingestion_id is None:
        return None

    return int(ingestion_id)

def record_skipped_ingestion(
    engine: Engine,
    source_file_name: str,
    taxi_type: str,
    period_year: int,
    period_month: int,
    file_size_bytes: int,
) -> int:
    """Record that a previously completed source file was skipped."""

    statement = text(
        """
        INSERT INTO raw.ingestion_log (
            source_file_name,
            taxi_type,
            period_year,
            period_month,
            file_size_bytes,
            status,
            completed_at
        )
        VALUES (
            :source_file_name,
            :taxi_type,
            :period_year,
            :period_month,
            :file_size_bytes,
            'skipped',
            CURRENT_TIMESTAMP
        )
        RETURNING ingestion_id;
        """
    )

    parameters = {
        "source_file_name": source_file_name,
        "taxi_type": taxi_type,
        "period_year": period_year,
        "period_month": period_month,
        "file_size_bytes": file_size_bytes,
    }

    with engine.begin() as connection:
        ingestion_id = connection.execute(
            statement,
            parameters,
        ).scalar_one()

    return int(ingestion_id)

def delete_raw_taxi_trips_for_ingestion(
    engine: Engine,
    ingestion_id: int,
) -> int:
    """Delete partially loaded trips associated with an ingestion."""

    statement = text(
        """
        DELETE FROM raw.taxi_trips
        WHERE ingestion_id = :ingestion_id;
        """
    )

    with engine.begin() as connection:
        result = connection.execute(
            statement,
            {"ingestion_id": ingestion_id},
        )

    return result.rowcount