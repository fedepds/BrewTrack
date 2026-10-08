import os

os.environ.setdefault("DATABASE_URL", "postgresql+psycopg://postgres:test@localhost:55432/brewtrack_test")
os.environ.setdefault("JWT_SECRET", "test-secret-test-secret-test-secret")

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    return TestClient(app)
