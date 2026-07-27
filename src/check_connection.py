from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from src.database import get_engine


def main() -> None:
    """Check the database connection and display the project schemas."""

    try:
        engine = get_engine()

        with engine.connect() as connection:
            database_info = connection.execute(
                text(
                    """
                    SELECT
                        current_database(),
                        current_user,
                        version();
                    """
                )
            ).one()

            database_name, database_user, postgres_version = database_info

            schemas = (
                connection.execute(
                    text(
                        """
                    SELECT schema_name
                    FROM information_schema.schemata
                    WHERE schema_name IN (
                        'raw',
                        'staging',
                        'analytics',
                        'marts'
                    )
                    ORDER BY schema_name;
                    """
                    )
                )
                .scalars()
                .all()
            )

        print("Connection successful")
        print(f"Database: {database_name}")
        print(f"User: {database_user}")
        print(f"Version: {postgres_version.split(',')[0]}")
        print("Schemas found:")

        for schema in schemas:
            print(f" - {schema}")

    except (SQLAlchemyError, ValueError) as error:
        print("The PostgreSQL check could not be completed.")
        print(f"Details: {error}")
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
