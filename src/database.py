import os

from dotenv import load_dotenv
from sqlalchemy import URL, Engine, create_engine

load_dotenv()


def get_required_environment_variable(name: str) -> str:
    """Retrieves a required environment variable."""

    value = os.getenv(name)

    if not value:
        raise ValueError(f"The environment variable {name!r} is not set")
    return value


def build_database_url() -> URL:
    """Safely construct the URL for connecting to PostgreSQL."""

    port = get_required_environment_variable("POSTGRES_PORT")

    try:
        port_number = int(port)
    except ValueError as error:
        raise ValueError("POSTGRES_PORT must contain an integer") from error

    return URL.create(
        drivername="postgresql+psycopg",
        username=get_required_environment_variable("POSTGRES_USER"),
        password=get_required_environment_variable("POSTGRES_PASSWORD"),
        host=get_required_environment_variable("POSTGRES_HOST"),
        port=port_number,
        database=get_required_environment_variable("POSTGRES_DB"),
    )


def get_engine() -> Engine:
    """Creates the connection engine used by the application."""

    return create_engine(
        build_database_url(),
        pool_pre_ping=True,
    )
