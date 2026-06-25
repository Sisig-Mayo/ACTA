"""
ACTA Backend — Simulation Router
===================================
Asynchronous FastAPI router handling simulation execution requests.
Processes operator inputs, generates time-decayed action plans,
triggers Gemini AI for Explainability Cards, and returns
integrated strategy objects.

Target Branch : feature/backend-decay
Commit        : feat(backend): implement async endpoints and proximity time decay service logic
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, HTTPException, status, Response, BackgroundTasks

from app.core.supabase_client import get_supabase_client
from app.models.simulation import (
    BarangayImpact,
    ExplainabilityCard,
    SeverityTier,
    SimulationInput,
    SimulationOutput,
    TaskItem,
    ZoneStatus,
    SimulationRunResponse,
    SimulationStatusResponse,
    RiskScoreResult,
)
from app.services.risk_pipeline import run_simulation_pipeline
from app.services.pdf_generator import generate_master_action_plan
from app.services.dispatch import execute_action_plan

logger = logging.getLogger("acta.routes.simulation")

router = APIRouter()

# -----------------------------------------------------------
# POST /api/v1/simulation/run
# -----------------------------------------------------------

@router.post(
    "/run",
    response_model=SimulationRunResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Execute Disaster Simulation (Async)",
    description=(
        "Initiates an asynchronous simulation run. Returns a run_id immediately. "
        "The background task computes GEE risk layers, updates road costs, "
        "and generates actionable insights."
    ),
)
async def run_simulation(
    payload: SimulationInput,
    background_tasks: BackgroundTasks,
) -> SimulationRunResponse:
    """
    Primary simulation execution endpoint (Async).
    """
    logger.info(
        "Simulation requested — Wind: %.1f kph, Rain: %.1f mm, Radius: %.1f km, T-%dh",
        payload.wind_speed_kph,
        payload.precipitation_24h_mm,
        payload.storm_radius_km,
        payload.preparation_window_hours,
    )

    client = get_supabase_client()
    if client is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database connection not configured. Cannot create simulation run.",
        )

    # 1. Create a simulation_runs record
    db_payload = {
        "typhoon_parameters": payload.model_dump(),
        "preparation_window_hours": payload.preparation_window_hours,
        "status": "PENDING",
    }
    
    try:
        res = client.table("simulation_runs").insert(db_payload).execute()
        if not res.data:
            raise ValueError("No data returned from simulation_runs insert.")
        run_id = res.data[0]["id"]
    except Exception as e:
        logger.error("Failed to create simulation run record: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to initialize simulation: {str(e)}",
        )

    # 2. Add Background Task
    background_tasks.add_task(run_simulation_pipeline, run_id, payload)

    return SimulationRunResponse(
        run_id=run_id,
        status="PENDING",
        message="Simulation accepted and processing in the background.",
    )


# -----------------------------------------------------------
# GET /api/v1/simulation/status/{run_id}
# -----------------------------------------------------------

@router.get(
    "/status/{run_id}",
    response_model=SimulationStatusResponse,
    status_code=status.HTTP_200_OK,
    summary="Get Simulation Status",
)
async def get_simulation_status(run_id: str) -> SimulationStatusResponse:
    """Check the status of an ongoing simulation run."""
    client = get_supabase_client()
    if client is None:
        raise HTTPException(status_code=500, detail="Database unavailable")

    try:
        res = client.table("simulation_runs").select("id, status, progress_pct, error_message").eq("id", run_id).execute()
        if not res.data:
            raise HTTPException(status_code=404, detail="Simulation run not found")
        
        record = res.data[0]
        return SimulationStatusResponse(
            run_id=record["id"],
            status=record["status"],
            progress_pct=record.get("progress_pct", 0),
            error_message=record.get("error_message"),
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# -----------------------------------------------------------
# GET /api/v1/simulation/results/{run_id}
# -----------------------------------------------------------

@router.get(
    "/results/{run_id}",
    response_model=SimulationOutput,
    status_code=status.HTTP_200_OK,
    summary="Get Simulation Results",
)
async def get_simulation_results(run_id: str) -> SimulationOutput:
    """Retrieve the completed results for a simulation run."""
    client = get_supabase_client()
    if client is None:
        raise HTTPException(status_code=500, detail="Database unavailable")

    try:
        # Fetch simulation run metadata
        run_res = client.table("simulation_runs").select("*").eq("id", run_id).execute()
        if not run_res.data:
            raise HTTPException(status_code=404, detail="Simulation run not found")
        
        run_record = run_res.data[0]
        
        if run_record["status"] != "COMPLETED":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, 
                detail=f"Simulation is not complete. Current status: {run_record['status']}"
            )

        # Fetch risk scores (only returning top impacted for the output model to keep it light)
        scores_res = client.table("barangay_risk_scores").select(
            "barangay_id, barangays(barangay_name, district), water_accumulation_score, elevation_factor, historical_frequency, total_risk_score, risk_tier"
        ).eq("run_id", run_id).order("total_risk_score", desc=True).limit(50).execute()
        
        impacted = []
        for s in scores_res.data:
            # Reconstruct the BarangayImpact model from the joined data
            b_name = s["barangays"]["barangay_name"] if s.get("barangays") else "Unknown"
            b_dist = s["barangays"]["district"] if s.get("barangays") else "Unknown"
            
            zone = ZoneStatus.GREEN
            if s["risk_tier"] == "RED":
                zone = ZoneStatus.RED
            elif s["risk_tier"] == "YELLOW":
                zone = ZoneStatus.YELLOW
                
            impacted.append(BarangayImpact(
                barangay_name=b_name,
                district=b_dist,
                zone_status=zone,
                coverage_pct=s["total_risk_score"] * 100,  # Proxy mapping for UI
                centroid=[120.98, 14.59],  # Need to join centroid if needed by UI
            ))

        # Reconstruct TaskItem list
        raw_tasks = run_record.get("task_list", [])
        task_list = [TaskItem(**t) for t in raw_tasks]

        # Reconstruct ExplainabilityCard
        card_data = run_record.get("explainability_card", {})
        if not card_data:
            card_data = {
                "summary": "No summary available.",
                "risk_narrative": "",
                "action_rationale": "",
                "confidence_note": ""
            }
        card = ExplainabilityCard(**card_data)

        output = SimulationOutput(
            severity_tier=SeverityTier(run_record.get("severity_tier", "low").lower()),
            preparation_window_hours=run_record["preparation_window_hours"],
            impacted_barangays=impacted,
            task_list=task_list,
            explainability_card=card,
            metadata={
                "run_id": run_id,
                "generated_at": run_record["created_at"],
                "total_red_zones": run_record.get("total_red_zones", 0),
                "total_yellow_zones": run_record.get("total_yellow_zones", 0),
            }
        )

        return output

    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to fetch results: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# -----------------------------------------------------------
# POST /api/v1/simulation/export-pdf
# -----------------------------------------------------------

@router.post(
    "/export-pdf",
    status_code=status.HTTP_200_OK,
    summary="Generate Master Action Plan PDF",
)
async def export_pdf_blueprint(payload: SimulationOutput) -> Response:
    """Generate and return a PDF blueprint from simulation data."""
    logger.info("PDF Blueprint generation requested.")
    try:
        pdf_bytes = generate_master_action_plan(payload)
        
        return Response(
            content=bytes(pdf_bytes),
            media_type="application/pdf",
            headers={
                "Content-Disposition": 'attachment; filename="ACTA_Action_Plan.pdf"'
            }
        )
    except Exception as e:
        logger.error("PDF generation failed: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"PDF generation error: {str(e)}",
        )


# -----------------------------------------------------------
# POST /api/v1/simulation/dispatch
# -----------------------------------------------------------

@router.post(
    "/dispatch",
    status_code=status.HTTP_200_OK,
    summary="Approve and Execute Plan",
)
async def dispatch_plan(payload: dict[str, Any]) -> dict[str, Any]:
    """Execute action plan and dispatch resources."""
    logger.info("Plan execution dispatch requested.")
    try:
        manifest = await execute_action_plan(payload)
        return manifest
    except Exception as e:
        logger.error("Execution dispatch failed: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Dispatch error: {str(e)}",
        )
