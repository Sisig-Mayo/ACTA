"""
ACTA Backend — Background Risk Pipeline Orchestrator
======================================================
Coordinates the async execution of the full simulation pipeline.

1. Create `simulation_runs` record (status: PROCESSING)
2. Call GEE engine for risk calculation
3. Batch insert 905 risk scores via Supabase bulk INSERT
4. Call `apply_flood_cost_modifiers(run_id)` to update road network
5. Generate time-decay tasks
6. Generate Gemini explainability card
7. Update `simulation_runs` status to COMPLETED
"""

from __future__ import annotations

import json
import logging
from typing import Any

from app.core.gemini import generate_explainability_card
from app.core.supabase_client import (
    bulk_insert_risk_scores,
    update_simulation_status,
)
from app.core.pagasa_constants import (
    determine_severity,
    classify_wind,
    classify_rainfall,
    classify_prep_window,
    WIND_LABELS,
    RAINFALL_TIERS,
    PHASE_LABELS,
)
from app.models.simulation import SimulationInput
from app.services.bypass_router import _get_pool
from app.services.decay_engine import generate_time_decay_tasks
from app.services.gee_engine import calculate_risk_scores

logger = logging.getLogger("acta.risk_pipeline")


async def run_simulation_pipeline(
    run_id: str,
    payload: SimulationInput,
) -> None:
    """
    Execute the full background simulation pipeline.
    """
    try:
        logger.info("Starting simulation pipeline for run %s", run_id)
        update_simulation_status(run_id, "PROCESSING", 10)

        # 1. Fetch all barangay geometries from DB
        barangay_geometries = await _fetch_all_barangay_geometries()
        if not barangay_geometries:
            raise ValueError("No barangay geometries found in database.")

        update_simulation_status(run_id, "PROCESSING", 20)

        # 2. Call GEE engine for risk calculation
        gee_result = await calculate_risk_scores(
            precipitation_mm=payload.precipitation_24h_mm,
            wind_speed_kph=payload.wind_speed_kph,
            storm_radius_km=payload.storm_radius_km,
            barangay_geometries=barangay_geometries,
        )

        scores = gee_result["scores"]
        summary = gee_result["summary"]
        
        # Determine overall severity tier using PAGASA methodology
        red_pct = summary["red_zones"] / max(summary["total_barangays"], 1)
        severity_tier = determine_severity(
            payload.wind_speed_kph,
            payload.precipitation_24h_mm,
            red_pct,
        )
        
        update_simulation_status(run_id, "PROCESSING", 50)

        # 3. Batch insert risk scores via Supabase REST API
        bulk_insert_risk_scores(run_id, scores)
        
        update_simulation_status(run_id, "PROCESSING", 60)

        # 4. Call SQL function to apply flood cost modifiers
        await _apply_flood_modifiers(run_id)

        update_simulation_status(run_id, "PROCESSING", 70)

        # 5. Generate time-decay tasks
        raw_tasks = generate_time_decay_tasks(
            prep_window=payload.preparation_window_hours,
            severity_tier=severity_tier,
        )

        update_simulation_status(run_id, "PROCESSING", 80)

        # 6. Generate Gemini explainability card
        wind_cat = classify_wind(payload.wind_speed_kph)
        rain_cat = classify_rainfall(payload.precipitation_24h_mm / 24.0)
        phase_cat = classify_prep_window(payload.preparation_window_hours)

        simulation_context: dict[str, Any] = {
            "wind_speed_kph": payload.wind_speed_kph,
            "wind_classification": WIND_LABELS.get(wind_cat, wind_cat),
            "precipitation_24h_mm": payload.precipitation_24h_mm,
            "rainfall_advisory_tier": RAINFALL_TIERS.get(rain_cat, {}).get("label", rain_cat),
            "preparation_window_hours": payload.preparation_window_hours,
            "planning_phase": PHASE_LABELS.get(phase_cat, phase_cat),
            "severity_tier": severity_tier,
            "storm_radius_km": payload.storm_radius_km,
        }

        # Pass RED and YELLOW barangays to Gemini for comprehensive context
        impacted = [
            s["barangay_name"] 
            for s in scores 
            if s["risk_tier"] in ("RED", "YELLOW")
        ]
        
        card_data = await generate_explainability_card(
            simulation_context=simulation_context,
            task_list=raw_tasks,
            impacted_barangays=impacted,
        )

        update_simulation_status(run_id, "PROCESSING", 90)

        # 7. Update simulation_runs status to COMPLETED with all metadata
        update_simulation_status(
            run_id=run_id,
            status="COMPLETED",
            progress_pct=100,
            extra_data={
                "severity_tier": severity_tier,
                "total_red_zones": summary["red_zones"],
                "total_yellow_zones": summary["yellow_zones"],
                "total_green_zones": summary["green_zones"],
                "explainability_card": card_data,
                "task_list": raw_tasks,
            }
        )
        logger.info("Simulation pipeline for run %s completed successfully.", run_id)

    except Exception as e:
        logger.error("Simulation pipeline for run %s failed: %s", run_id, e, exc_info=True)
        update_simulation_status(run_id, "FAILED", error_message=str(e))


async def _fetch_all_barangay_geometries() -> list[dict[str, Any]]:
    """Fetch ID, name, district, and GeoJSON geometry for all barangays."""
    pool = await _get_pool()
    query = """
        SELECT
            id,
            barangay_name,
            district,
            ST_AsGeoJSON(geom) AS geom_geojson
        FROM barangays;
    """
    try:
        async with pool.acquire() as conn:
            rows = await conn.fetch(query)

        return [
            {
                "id": row["id"],
                "barangay_name": row["barangay_name"],
                "district": row["district"],
                "geom_geojson": row["geom_geojson"],
            }
            for row in rows
        ]
    except Exception as e:
        logger.error("Failed to fetch barangay geometries: %s", e)
        raise


async def _apply_flood_modifiers(run_id: str) -> None:
    """Execute the apply_flood_cost_modifiers() SQL function."""
    pool = await _get_pool()
    query = "SELECT roads_modified, red_barangays, flood_area_sqm FROM apply_flood_cost_modifiers($1::UUID);"
    try:
        async with pool.acquire() as conn:
            row = await conn.fetchrow(query, run_id)
        if row:
            logger.info(
                "Flood modifiers applied for run %s: %d roads modified, %d red barangays, %.0f sqm area",
                run_id, row["roads_modified"], row["red_barangays"], row["flood_area_sqm"]
            )
    except Exception as e:
        logger.error("Failed to apply flood cost modifiers for run %s: %s", run_id, e)
        raise


