"""
ACTA Backend — Supabase Client Singleton
==========================================
Provides a lazily-initialized Supabase client for REST API
operations (bulk inserts, storage). Complements the asyncpg
pool used for raw SQL queries.
"""

from __future__ import annotations

import logging
from typing import Any

from app.core.config import settings

logger = logging.getLogger("acta.supabase_client")

_client = None


def get_supabase_client():
    """
    Lazily initialize and return the Supabase client.

    Uses the service_role key for full write access,
    bypassing Row Level Security for backend operations.
    """
    global _client
    if _client is not None:
        return _client

    url = settings.SUPABASE_URL
    key = settings.SUPABASE_SERVICE_ROLE_KEY

    if not url or not key:
        logger.warning(
            "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not configured. "
            "Supabase client will not be available."
        )
        return None

    try:
        from supabase import create_client
        _client = create_client(url, key)
        logger.info("Supabase REST client initialized.")
        return _client
    except ImportError:
        logger.warning(
            "supabase-py not installed. Bulk operations unavailable. "
            "Install via: pip install supabase"
        )
        return None
    except Exception as e:
        logger.error("Failed to initialize Supabase client: %s", e)
        return None


def bulk_insert_risk_scores(
    run_id: str,
    scores: list[dict[str, Any]],
) -> int:
    """
    Batch-insert risk scores for a simulation run using a single
    Supabase REST API call instead of N individual INSERT statements.

    Parameters
    ----------
    run_id : str
        UUID of the simulation run.
    scores : list[dict]
        List of score dictionaries, each containing:
        - barangay_id (int)
        - water_accumulation_score (float)
        - elevation_factor (float)
        - historical_frequency (float)
        - total_risk_score (float)
        - risk_tier (str: RED/YELLOW/GREEN)

    Returns
    -------
    int
        Number of records inserted.
    """
    client = get_supabase_client()

    if client is None:
        logger.error("Supabase client not available for bulk insert.")
        return 0

    # Attach run_id to each score record.
    records = [
        {
            "run_id": run_id,
            "barangay_id": s["barangay_id"],
            "water_accumulation_score": round(s["water_accumulation_score"], 4),
            "elevation_factor": round(s["elevation_factor"], 4),
            "historical_frequency": round(s["historical_frequency"], 4),
            "total_risk_score": round(s["total_risk_score"], 4),
            "risk_tier": s["risk_tier"],
        }
        for s in scores
    ]

    try:
        # Single bulk insert — Supabase REST API handles batching.
        result = (
            client.table("barangay_risk_scores")
            .upsert(records, on_conflict="run_id,barangay_id")
            .execute()
        )
        inserted = len(result.data) if result.data else 0
        logger.info(
            "Bulk-inserted %d risk scores for run %s.", inserted, run_id
        )
        return inserted
    except Exception as e:
        logger.error("Bulk insert failed for run %s: %s", run_id, e)
        raise


def update_simulation_status(
    run_id: str,
    status: str,
    progress_pct: int = 0,
    error_message: str | None = None,
    extra_data: dict[str, Any] | None = None,
) -> None:
    """
    Update the status of a simulation run.

    Parameters
    ----------
    run_id : str
        UUID of the simulation run.
    status : str
        New status (PENDING, PROCESSING, COMPLETED, FAILED, CANCELLED).
    progress_pct : int
        Completion percentage (0-100).
    error_message : str, optional
        Error message if status is FAILED.
    extra_data : dict, optional
        Additional fields to update (severity_tier, zone counts, etc.).
    """
    client = get_supabase_client()
    if client is None:
        logger.error("Supabase client not available for status update.")
        return

    payload: dict[str, Any] = {
        "status": status,
        "progress_pct": progress_pct,
    }

    if error_message:
        payload["error_message"] = error_message

    if extra_data:
        payload.update(extra_data)

    try:
        client.table("simulation_runs").update(payload).eq("id", run_id).execute()
        logger.info(
            "Simulation %s status → %s (%d%%)", run_id, status, progress_pct
        )
    except Exception as e:
        logger.error("Status update failed for run %s: %s", run_id, e)
