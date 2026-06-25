"""
ACTA Backend — LLM Context Pipeline Service
===============================================
Orchestrates the assembly of basic parameters and simulation
data into a structured LLMContext, then feeds it through the
Gemini AI for context-aware action plan generation.

Pipeline Stages:
    1. Collect basic parameters (operator inputs)
    2. Collect simulation results (risk scores, zone summaries)
    3. Collect infrastructure status (pumping stations, gates)
    4. Collect decay-engine tasks (template baselines)
    5. Assemble into LLMContext
    6. Call Gemini via generate_action_plan_with_context()
    7. Return LLMActionPlanResponse

Target Branch : feature/llm-pipeline
Commit        : feat(backend): add LLM context assembly and pipeline service
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from app.models.llm_models import (
    BasicParameters,
    DecayEngineTask,
    InfrastructureNode,
    LLMActionPlanResponse,
    LLMContext,
    RiskScoreSummary,
    SimulationResults,
    ZoneSummary,
)
from app.models.simulation import SimulationInput

logger = logging.getLogger("acta.llm_pipeline")


# -----------------------------------------------------------
# Stage 1: Collect Basic Parameters
# -----------------------------------------------------------

def _collect_basic_parameters(payload: SimulationInput) -> BasicParameters:
    """
    Extract basic parameters from the operator's simulation input.
    These are the raw weather/storm parameters that ground the LLM.
    """
    return BasicParameters(
        wind_speed_kph=payload.wind_speed_kph,
        precipitation_24h_mm=payload.precipitation_24h_mm,
        preparation_window_hours=payload.preparation_window_hours,
        storm_track_points=payload.storm_track_points,
        storm_radius_km=payload.storm_radius_km,
    )


# -----------------------------------------------------------
# Stage 2: Collect Simulation Results
# -----------------------------------------------------------

def _collect_simulation_results(
    severity_tier: str,
    scores: list[dict[str, Any]],
    summary: dict[str, int],
) -> SimulationResults:
    """
    Aggregate GEE risk scores and zone summary into a
    SimulationResults context object.

    Parameters
    ----------
    severity_tier : str
        Overall severity determination (LOW/MODERATE/HIGH/CRITICAL).
    scores : list[dict]
        Per-barangay risk score records from the GEE engine.
    summary : dict
        Zone counts: {red_zones, yellow_zones, green_zones}.
    """
    # Build zone summary
    zone_summary = ZoneSummary(
        red_zones=summary.get("red_zones", 0),
        yellow_zones=summary.get("yellow_zones", 0),
        green_zones=summary.get("green_zones", 0),
        total_barangays=len(scores),
    )

    # Extract top 15 highest-risk barangays
    sorted_scores = sorted(
        scores, key=lambda s: s.get("total_risk_score", 0), reverse=True
    )
    top_risk = [
        RiskScoreSummary(
            barangay_name=s.get("barangay_name", "Unknown"),
            district=s.get("district", "Unknown"),
            total_risk_score=s.get("total_risk_score", 0.0),
            risk_tier=s.get("risk_tier", "GREEN"),
            water_accumulation_score=s.get("water_accumulation_score", 0.0),
            elevation_factor=s.get("elevation_factor", 0.0),
            historical_frequency=s.get("historical_frequency", 0.0),
        )
        for s in sorted_scores[:15]
    ]

    # Collect all RED-zone barangay names
    red_names = [
        s.get("barangay_name", "Unknown")
        for s in scores
        if s.get("risk_tier") == "RED"
    ]

    return SimulationResults(
        severity_tier=severity_tier,
        zone_summary=zone_summary,
        top_risk_barangays=top_risk,
        all_red_barangay_names=red_names,
    )


# -----------------------------------------------------------
# Stage 3: Collect Infrastructure Status
# -----------------------------------------------------------

async def _collect_infrastructure_status() -> list[InfrastructureNode]:
    """
    Fetch current infrastructure operational status from the
    infrastructure_status table via the asyncpg pool.

    Returns an empty list if the table has no data or the
    query fails (graceful degradation).
    """
    try:
        from app.services.bypass_router import _get_pool

        pool = await _get_pool()
        query = """
            SELECT
                node_name,
                node_type,
                is_operational,
                ST_Y(geom) AS latitude,
                ST_X(geom) AS longitude
            FROM infrastructure_status
            ORDER BY node_type, node_name;
        """
        async with pool.acquire() as conn:
            rows = await conn.fetch(query)

        nodes = [
            InfrastructureNode(
                node_name=row["node_name"],
                node_type=row["node_type"],
                is_operational=row["is_operational"],
                latitude=row["latitude"],
                longitude=row["longitude"],
            )
            for row in rows
        ]
        logger.info(
            "Infrastructure status collected: %d nodes (%d operational)",
            len(nodes),
            sum(1 for n in nodes if n.is_operational),
        )
        return nodes

    except Exception as e:
        logger.warning(
            "Failed to collect infrastructure status (graceful degradation): %s", e
        )
        return []


# -----------------------------------------------------------
# Stage 4: Collect Decay Engine Tasks
# -----------------------------------------------------------

def _collect_decay_engine_tasks(
    raw_tasks: list[dict[str, Any]],
) -> list[DecayEngineTask]:
    """
    Convert raw task dictionaries from the decay engine into
    typed DecayEngineTask models for the LLM context.
    """
    return [
        DecayEngineTask(
            task_id=t.get("task_id", ""),
            priority=t.get("priority", "MEDIUM"),
            action=t.get("action", ""),
            category=t.get("category", "general"),
            deadline_hours=t.get("deadline_hours", 0),
            responsible_unit=t.get("responsible_unit", ""),
            estimated_duration_hours=t.get("estimated_duration_hours", 1.0),
        )
        for t in raw_tasks
    ]


# -----------------------------------------------------------
# Stage 5: Assemble Full LLM Context
# -----------------------------------------------------------

async def assemble_llm_context(
    run_id: str,
    payload: SimulationInput,
    severity_tier: str,
    scores: list[dict[str, Any]],
    summary: dict[str, int],
    raw_tasks: list[dict[str, Any]],
) -> LLMContext:
    """
    Assemble the complete LLMContext from all pipeline stages.

    This is the central orchestration function that gathers data
    from basic parameters, simulation results, infrastructure
    status, and decay-engine tasks into a single structured
    context object.

    Parameters
    ----------
    run_id : str
        UUID of the current simulation run.
    payload : SimulationInput
        Original operator input parameters.
    severity_tier : str
        Computed severity tier from zone analysis.
    scores : list[dict]
        Per-barangay risk score records.
    summary : dict
        Zone count summary.
    raw_tasks : list[dict]
        Time-decayed tasks from the decay engine.

    Returns
    -------
    LLMContext
        Complete structured context ready for LLM consumption.
    """
    logger.info("Assembling LLM context for run %s...", run_id)

    # Stage 1: Basic parameters
    basic_params = _collect_basic_parameters(payload)

    # Stage 2: Simulation results
    sim_results = _collect_simulation_results(severity_tier, scores, summary)

    # Stage 3: Infrastructure status (async DB query)
    infra_nodes = await _collect_infrastructure_status()

    # Stage 4: Decay engine tasks
    decay_tasks = _collect_decay_engine_tasks(raw_tasks)

    # Stage 5: Assemble
    context = LLMContext(
        basic_parameters=basic_params,
        simulation_results=sim_results,
        infrastructure_status=infra_nodes,
        decay_engine_tasks=decay_tasks,
        metadata={
            "run_id": run_id,
            "assembled_at": datetime.now(timezone.utc).isoformat(),
            "pipeline_version": "1.0.0",
            "context_sections": 5,
            "total_risk_scores": len(scores),
            "total_template_tasks": len(raw_tasks),
            "infrastructure_nodes_available": len(infra_nodes),
        },
    )

    logger.info(
        "LLM context assembled for run %s: "
        "%d barangays, %d RED zones, %d infra nodes, %d template tasks",
        run_id,
        len(scores),
        sim_results.zone_summary.red_zones,
        len(infra_nodes),
        len(decay_tasks),
    )

    return context


# -----------------------------------------------------------
# Stage 6 & 7: Execute LLM Pipeline
# -----------------------------------------------------------

async def execute_llm_pipeline(
    run_id: str,
    payload: SimulationInput,
    severity_tier: str,
    scores: list[dict[str, Any]],
    summary: dict[str, int],
    raw_tasks: list[dict[str, Any]],
) -> tuple[LLMActionPlanResponse, LLMContext]:
    """
    Execute the full LLM pipeline: assemble context → call Gemini → return plan.

    This is the top-level entry point called by the risk pipeline.

    Parameters
    ----------
    run_id : str
        UUID of the current simulation run.
    payload : SimulationInput
        Original operator input.
    severity_tier : str
        Computed severity tier.
    scores : list[dict]
        Per-barangay risk scores.
    summary : dict
        Zone count summary.
    raw_tasks : list[dict]
        Decay-engine template tasks.

    Returns
    -------
    tuple[LLMActionPlanResponse, LLMContext]
        The AI-generated action plan and the context used to produce it.
    """
    from app.core.gemini import generate_action_plan_with_context

    # Assemble the full context
    llm_context = await assemble_llm_context(
        run_id=run_id,
        payload=payload,
        severity_tier=severity_tier,
        scores=scores,
        summary=summary,
        raw_tasks=raw_tasks,
    )

    # Call Gemini with the assembled context
    logger.info("Executing LLM pipeline for run %s...", run_id)
    llm_plan = await generate_action_plan_with_context(llm_context)

    logger.info(
        "LLM pipeline completed for run %s: %d AI tasks, generated_by=%s",
        run_id,
        len(llm_plan.action_plan_tasks),
        llm_plan.generated_by,
    )

    return llm_plan, llm_context
