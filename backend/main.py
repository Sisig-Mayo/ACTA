"""
ACTA Backend — Application Entry Point
========================================
FastAPI application factory with CORS, lifespan events,
and router registration.

Target Branch : feature/backend-decay
Commit        : feat(backend): add application entry point with lifespan and CORS

Usage:
    uvicorn main:app --reload --host 0.0.0.0 --port 8000
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.routes import auth, barangays, routing, simulation
from app.services.bypass_router import close_pool

# -----------------------------------------------------------
# Logging
# -----------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("acta")


# -----------------------------------------------------------
# Lifespan — Startup / Shutdown Events
# -----------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """
    Manage application lifecycle events.
    Startup: Validate configuration, warm connections.
    Shutdown: Graceful cleanup of async resources.
    """
    logger.info("🚀 ACTA Backend starting — %s", settings.PROJECT_NAME)
    logger.info("   Database URL configured: %s", bool(settings.SUPABASE_DATABASE_URL))
    logger.info("   Gemini API key configured: %s", bool(settings.GEMINI_API_KEY))
    yield
    # Close database pool for auth if created
    from app.routes.auth import _pool
    if _pool is not None:
        await _pool.close()
        logger.info("Auth Database connection pool closed.")
    logger.info("🛑 ACTA Backend shutting down gracefully.")
    await close_pool()


# -----------------------------------------------------------
# Application Factory
# -----------------------------------------------------------

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=(
        "ACTA: Context-Aware Decision-to-Action Simulation Engine. "
        "AI-powered disaster preparedness planning for Manila LGU operators."
    ),
    version="0.1.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# -----------------------------------------------------------
# CORS Middleware
# -----------------------------------------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------------------------------------------
# Router Registration
# -----------------------------------------------------------

app.include_router(
    auth.router,
    prefix="/api/v1/auth",
    tags=["Authentication"],
)

app.include_router(
    simulation.router,
    prefix="/api/v1/simulation",
    tags=["Simulation"],
)

app.include_router(
    routing.router,
    prefix="/api/v1/routing",
    tags=["Routing"],
)

app.include_router(
    barangays.router,
    prefix="/api/v1/barangays",
    tags=["Barangays"],
)


# -----------------------------------------------------------
# Health Check
# -----------------------------------------------------------

@app.get("/health", tags=["System"])
async def health_check() -> dict[str, str]:
    """Return basic application health status."""
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": "0.1.0",
    }
