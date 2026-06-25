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

from fastapi import APIRouter, HTTPException, status

from app.core.gemini import generate_explainability_card
from app.models.simulation import (
    BarangayImpact,
    ExplainabilityCard,
    SeverityTier,
    SimulationInput,
    SimulationOutput,
    TaskItem,
    ZoneStatus,
)
from app.services.decay_engine import generate_time_decay_tasks

logger = logging.getLogger("acta.routes.simulation")

router = APIRouter()


# -----------------------------------------------------------
# Severity Classification
# -----------------------------------------------------------

def _classify_severity(wind_speed: float, precipitation: float) -> SeverityTier:
    """
    Classify threat severity based on combined meteorological parameters.

    Thresholds are calibrated to Philippine typhoon signal classifications
    and PAGASA rainfall intensity categories.
    """
    # Composite threat score (weighted combination).
    threat_score = (wind_speed * 0.6) + (precipitation * 0.15)

    if threat_score >= 100:
        return SeverityTier.CRITICAL
    elif threat_score >= 60:
        return SeverityTier.HIGH
    elif threat_score >= 30:
        return SeverityTier.MODERATE
    else:
        return SeverityTier.LOW


def _classify_zone(coverage_pct: float, severity: SeverityTier) -> ZoneStatus:
    """
    Determine barangay zone status based on flood coverage
    and overall severity tier.
    """
    if severity in (SeverityTier.CRITICAL, SeverityTier.HIGH):
        if coverage_pct >= 30:
            return ZoneStatus.RED
        elif coverage_pct >= 10:
            return ZoneStatus.YELLOW
        return ZoneStatus.GREEN
    else:
        if coverage_pct >= 50:
            return ZoneStatus.RED
        elif coverage_pct >= 20:
            return ZoneStatus.YELLOW
        return ZoneStatus.GREEN


# -----------------------------------------------------------
# Simulated Impact Assessment (placeholder until live DB)
# -----------------------------------------------------------

def _simulate_barangay_impacts(
    severity: SeverityTier,
    storm_track: list[list[float]],
) -> list[BarangayImpact]:
    """
    Generate simulated barangay impact data.

    In production, this queries the PostGIS database using
    `get_impacted_barangays()` with real flood geometries.
    This stub provides representative sample data for
    development and testing.
    """
    # Sample Manila barangays representing diverse risk profiles.
    sample_barangays = [
        {"name": "Baseco", "district": "District I (Tondo)", "coverage": 85.0, "centroid": [120.9667, 14.5917]},
        {"name": "Tondo", "district": "District I (Tondo)", "coverage": 62.0, "centroid": [120.9650, 14.6100]},
        {"name": "Binondo", "district": "District I (Tondo)", "coverage": 45.0, "centroid": [120.9736, 14.5986]},
        {"name": "San Nicolas", "district": "District I (Tondo)", "coverage": 38.0, "centroid": [120.9750, 14.6050]},
        {"name": "Ermita", "district": "District V (Ermita)", "coverage": 28.0, "centroid": [120.9819, 14.5833]},
        {"name": "Malate", "district": "District V (Ermita)", "coverage": 22.0, "centroid": [120.9886, 14.5667]},
        {"name": "Pandacan", "district": "District IV (Sampaloc)", "coverage": 55.0, "centroid": [121.0050, 14.5850]},
        {"name": "Santa Ana", "district": "District II (Santa Ana)", "coverage": 48.0, "centroid": [121.0117, 14.5700]},
        {"name": "Intramuros", "district": "District V (Ermita)", "coverage": 15.0, "centroid": [120.9750, 14.5917]},
        {"name": "Sampaloc", "district": "District IV (Sampaloc)", "coverage": 8.0, "centroid": [120.9950, 14.6167]},
    ]

    impacts: list[BarangayImpact] = []
    for brgy in sample_barangays:
        zone = _classify_zone(brgy["coverage"], severity)
        impacts.append(
            BarangayImpact(
                barangay_name=brgy["name"],
                district=brgy["district"],
                zone_status=zone,
                coverage_pct=brgy["coverage"],
                centroid=brgy["centroid"],
            )
        )

    # Sort by coverage descending (highest risk first).
    impacts.sort(key=lambda b: b.coverage_pct, reverse=True)
    return impacts


# -----------------------------------------------------------
# POST /api/v1/simulation/run
# -----------------------------------------------------------

@router.post(
    "/run",
    response_model=SimulationOutput,
    status_code=status.HTTP_200_OK,
    summary="Execute Disaster Simulation",
    description=(
        "Process simulation parameters, generate time-decayed action plans, "
        "compile Gemini AI Explainability Cards, and return an integrated "
        "strategy object for the LGU operator dashboard."
    ),
)
async def run_simulation(payload: SimulationInput) -> SimulationOutput:
    """
    Primary simulation execution endpoint.

    Pipeline:
    1. Classify threat severity from meteorological inputs.
    2. Map projected impact zones to barangay boundaries.
    3. Generate time-decayed action tasks via decay engine.
    4. Request Gemini AI to compile an Explainability Card.
    5. Assemble and return the integrated strategy response.
    """
    logger.info(
        "Simulation requested — Wind: %.1f kph, Rain: %.1f mm, T-%dh",
        payload.wind_speed_kph,
        payload.precipitation_24h_mm,
        payload.preparation_window_hours,
    )

    try:
        # 1. Classify severity.
        severity = _classify_severity(
            payload.wind_speed_kph,
            payload.precipitation_24h_mm,
        )
        logger.info("Severity classified: %s", severity.value)

        # 2. Assess barangay impacts.
        impacted_barangays = _simulate_barangay_impacts(
            severity, payload.storm_track_points
        )
        logger.info("Impacted barangays assessed: %d", len(impacted_barangays))

        # 3. Generate time-decayed action tasks.
        raw_tasks = generate_time_decay_tasks(
            prep_window=payload.preparation_window_hours,
            severity_tier=severity.value,
        )

        task_list = [
            TaskItem(
                priority=t["priority"],
                action=t["action"],
                deadline_hours=t["deadline_hours"],
                category=t["category"],
            )
            for t in raw_tasks
        ]
        logger.info("Generated %d time-decayed tasks.", len(task_list))

        # 4. Generate Explainability Card via Gemini AI.
        simulation_context: dict[str, Any] = {
            "wind_speed_kph": payload.wind_speed_kph,
            "precipitation_24h_mm": payload.precipitation_24h_mm,
            "preparation_window_hours": payload.preparation_window_hours,
            "severity_tier": severity.value,
        }

        barangay_names = [b.barangay_name for b in impacted_barangays]

        card_data = await generate_explainability_card(
            simulation_context=simulation_context,
            task_list=raw_tasks,
            impacted_barangays=barangay_names,
        )

        explainability_card = ExplainabilityCard(**card_data)
        logger.info("Explainability Card compiled.")

        # 5. Assemble response.
        output = SimulationOutput(
            severity_tier=severity,
            preparation_window_hours=payload.preparation_window_hours,
            impacted_barangays=impacted_barangays,
            task_list=task_list,
            explainability_card=explainability_card,
            metadata={
                "generated_at": datetime.now(timezone.utc).isoformat(),
                "model_version": "0.1.0",
                "storm_track_points_count": len(payload.storm_track_points),
                "total_impacted_barangays": len(impacted_barangays),
                "red_zone_count": sum(
                    1 for b in impacted_barangays if b.zone_status == ZoneStatus.RED
                ),
            },
        )

        logger.info(
            "Simulation complete — %s severity, %d tasks, %d barangays impacted.",
            severity.value, len(task_list), len(impacted_barangays),
        )

        return output

    except Exception as e:
        logger.error("Simulation execution failed: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Simulation engine error: {str(e)}",
        )
