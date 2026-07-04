"""
Secure ML inference service — Milestone 3 (Secure Deployment).
Owner: Ali Yasser — Security & DevSecOps Engineer

Security controls implemented in this file:
  1. Explicit CORS allow-list (never "*")
  2. Security response headers (HSTS, X-Content-Type-Options, X-Frame-Options, CSP)
  3. Global rate limiting (SlowAPI) to blunt brute-force / abuse (OWASP API4)
  4. Structured, PII-free audit logging
  5. No debug/reload in production, no stack traces leaked to clients
"""
import logging
import time

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.api.auth import router as auth_router
from app.api.inference import router as inference_router
from app.core.config import get_settings
from app.core.limiter import limiter

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("fraud_api")

settings = get_settings()

app = FastAPI(
    title=settings.APP_NAME,
    docs_url=None if settings.ENVIRONMENT == "production" else "/docs",
    redoc_url=None if settings.ENVIRONMENT == "production" else "/redoc",
)

# --- Rate limiting ---------------------------------------------------------
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# --- CORS: explicit allow-list only ----------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS or ["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)


# --- Security headers middleware -------------------------------------------
@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration_ms = (time.time() - start) * 1000

    response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains; preload"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Content-Security-Policy"] = "default-src 'none'"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
    # NOTE: the "Server: uvicorn" header cannot be stripped from middleware —
    # uvicorn sets it after the ASGI app returns. It is disabled at the
    # server level instead: see `--no-server-header` in Dockerfile CMD
    # (found during Milestone 3 pentest, remediated at the correct layer).

    logger.info(
        "request method=%s path=%s status=%s duration_ms=%.2f",
        request.method, request.url.path, response.status_code, duration_ms,
    )
    return response


# --- Global error handler: never leak stack traces to clients --------------
@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.exception("unhandled_error path=%s", request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error. Please contact support."},
    )


# --- Routers -----------------------------------------------------------
app.include_router(auth_router, prefix=settings.API_V1_PREFIX)
app.include_router(inference_router, prefix=settings.API_V1_PREFIX)


@app.get("/health", tags=["health"])
def health_check():
    """Liveness/readiness probe for AKS. Returns no sensitive information."""
    return {"status": "ok", "environment": settings.ENVIRONMENT}
