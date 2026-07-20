from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from src.database import get_engine


def main() -> None:
    """Verifica la conexión y muestra los esquemas del proyecto."""

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

            schemas = connection.execute(
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
            ).scalars().all()

        print("Conexión exitosa")
        print(f"Base de datos: {database_name}")
        print(f"Usuario: {database_user}")
        print(f"Versión: {postgres_version.split(',')[0]}")
        print("Esquemas encontrados:")

        for schema in schemas:
            print(f"  - {schema}")

    except (SQLAlchemyError, ValueError) as error:
        print("No se pudo completar la comprobación de PostgreSQL.")
        print(f"Detalle: {error}")
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()