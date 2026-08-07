from collections.abc import Iterator

import pytest
from sqlalchemy import Engine

from src.database import get_engine


@pytest.fixture(scope="session")
def db_engine() -> Iterator[Engine]:
    engine = get_engine()

    yield engine

    engine.dispose()
