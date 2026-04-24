FROM python:3.12-slim

# Install curl for HEALTHCHECK
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first (layer cache)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy entire backend directory
# The sys.path hack in app/services/resolver_service.py needs
# root-level routes/ and services/ directories accessible at /app/
COPY . /app/

# Create non-root user and data directory for SQLite
RUN groupadd -r sideb && \
    useradd -r -g sideb -d /app -s /sbin/nologin sideb && \
    mkdir -p /app/data && \
    chown -R sideb:sideb /app/data

USER sideb

EXPOSE 8788

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8788/health || exit 1

ENTRYPOINT ["./entrypoint.sh"]