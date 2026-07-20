import os

from dotenv import load_dotenv
from sqlalchemy import URL, Engine, create_engine

load_dotenv()

def get_required_environment_variable(name: str) -> str:
    #Obtiene una variable de entorno obligatoria.

    value = os.getenv(name)

    if not value:
        raise ValueError(
            f"La variable de entorno {name!r} no está configurada"
        )
    return value

def build_database_url() -> URL:
    #Construye de forma segura la URL de conexión a PostgreSQL.

    port = get_required_environment_variable("POSTGRES_PORT")

    try:
        port_number = int(port)
    except ValueError as error:
        raise ValueError(
            "POSTGRES_PORT debe contener un nmúmero entero"
        )from error
    
    return URL.create(
        drivername="postgresql+psycopg",
        username=get_required_environment_variable("POSTGRES_USER"),
        password=get_required_environment_variable("POSTGRES_PASSWORD"),
        host=get_required_environment_variable("POSTGRES_HOST"),
        port=port_number,
        database=get_required_environment_variable("POSTGRES_DB"),
    )

def get_engine() -> Engine:
    #Crea el motor de conexión utilizado por la aplicación
    
    return create_engine(
        build_database_url(),
        pool_pre_ping=True,
    )