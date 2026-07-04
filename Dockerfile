# ---- Build stage ----------------------------------------------------------
FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ---- Runtime stage ----------------------------------------------------------
FROM python:3.12-slim

# Security: run as a dedicated non-root user
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app
COPY --from=builder /root/.local /home/appuser/.local
COPY ./app ./app

ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ENVIRONMENT=production

# Drop privileges before the app ever runs
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# No shell form, no reload, no debug, no server fingerprint header —
# production-grade Uvicorn invocation
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2", "--no-server-header", "--no-date-header"]
