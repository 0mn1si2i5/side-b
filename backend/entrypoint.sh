#!/bin/bash
set -e

echo "Running database migrations..."
if ! alembic upgrade head; then
    echo "ERROR: Database migration failed" >&2
    exit 1
fi

echo "Starting Side B API server..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8788 --workers ${UVICORN_WORKERS:-2}