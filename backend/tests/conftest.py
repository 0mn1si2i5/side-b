"""Pytest fixtures for Side B backend integration tests.

Uses in-memory SQLite with fresh tables per test to guarantee isolation.
Resets slowapi rate limiter storage between tests so rapid requests succeed.
"""

import os
import time

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("JWT_SECRET", "test-jwt-secret-for-integration-tests")
os.environ.setdefault("CORS_ORIGINS", "http://localhost:3000,http://localhost:5173")

from app.database import Base, get_db
from app.main import app, limiter


@pytest.fixture(scope="session")
def engine():
    eng = create_engine(
        "sqlite:///file::memory:?cache=shared&uri=true",
        connect_args={"check_same_thread": False},
    )
    return eng


@pytest.fixture(autouse=True)
def _setup_tables(engine):
    Base.metadata.create_all(bind=engine)
    limiter.reset()
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture()
def db_session(engine):
    connection = engine.connect()
    transaction = connection.begin()
    TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=connection)
    session = TestSessionLocal()
    yield session
    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture()
def client(db_session):
    def _override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = _override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


_ts_counter = 0


def _unique_suffix() -> str:
    global _ts_counter
    _ts_counter += 1
    return f"{int(time.time() * 1000)}{_ts_counter}"


def register_user(client: TestClient, *, username: str | None = None, password: str = "TestPass123!", display_name: str | None = None, avatar_name: str = "avatar_1") -> dict:
    suffix = _unique_suffix()
    body = {
        "username": username or f"u{suffix}",
        "password": password,
        "displayName": display_name or f"User {suffix}",
        "avatarName": avatar_name,
    }
    resp = client.post("/api/auth/register", json=body)
    assert resp.status_code == 200, f"Register failed: {resp.text}"
    return resp.json()


def auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}