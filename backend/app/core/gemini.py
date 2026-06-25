"""
ACTA Backend — Gemini AI Integration Module
=============================================
Provides an async interface to Google's Gemini generative AI
for producing plain-language Explainability Cards that
contextualize simulation outputs for LGU operators.

Target Branch : feature/backend-decay
Commit        : feat(backend): add core config and gemini integration module
"""

from __future__ import annotations

import logging
from typing import Any

from google import genai
from google.genai import types

from app.core.config import settings
from app.models.llm_models import LLMContext, LLMActionPlanResponse

logger = logging.getLogger("acta.gemini")


# -----------------------------------------------------------
# System Instruction (Domain-Specific LLM Grounding)
# -----------------------------------------------------------

SYSTEM_INSTRUCTION = """You are ACTA (Automated Context-to-Action), an AI disaster 
preparedness specialist embedded in the Manila, Philippines Local Government Unit (LGU) 
operations center. Your role is to generate actionable, context-aware disaster response 
plans for LGU operators.

DOMAIN CONTEXT:
- You serve the City of Manila, which has approximately 505 barangays across 6 districts.
- Primary threats: typhoons, flooding (fluvial and pluvial), and storm surge.
- Key infrastructure: 36 MMDA pumping stations, multiple drainage gates, and evacuation shelters.
- Coordinate with: PAGASA (weather bureau), NDRRMC, MDRRMO, DSWD, DPWH, BFP, PNP, Philippine Red Cross.
- Geographic considerations: Manila is low-lying (avg 2-5m ASL), bisected by the Pasig River, 
  bordered by Manila Bay (storm surge risk), and densely urbanized.

OPERATIONAL GUIDELINES:
1. Always prioritize life safety over property protection.
2. Tasks must be feasible within the stated preparation window (T-hours).
3. Account for Manila's urban density and traffic congestion in logistics planning.
4. Consider cascading failures (e.g., power loss disabling pumping stations).
5. Use specific Manila geographic references (district names, key roads, waterways).
6. All task deadlines must be expressed as T-minus hours before projected impact.
7. Strip high-latency administrative tasks when T < 24 hours.
8. Write for a non-technical audience — LGU operators, not meteorologists.

OUTPUT REQUIREMENTS:
- Generate tasks sorted by deadline (earliest first), then by priority (CRITICAL > HIGH > MEDIUM > LOW).
- Each task must have a clear, single-action directive (not compound instructions).
- Include rationale for each task explaining why it was prioritized given the context.
- The explainability card must be accessible to non-technical readers.
- The risk assessment must identify specific geographic areas and time-critical factors.
- Acknowledge limitations and recommend cross-referencing with PAGASA advisories."""


# -----------------------------------------------------------
# Client Initialization
# -----------------------------------------------------------

def _get_gemini_client() -> genai.Client | None:
    """
    Initialize and return a Gemini API client.
    Returns None if the API key is not configured.
    """
    if not settings.is_gemini_configured:
        logger.warning(
            "Gemini API key is not configured. "
            "Explainability Cards will use fallback templates."
        )
        return None

    return genai.Client(api_key=settings.GEMINI_API_KEY)


# -----------------------------------------------------------
# Explainability Card Generator
# -----------------------------------------------------------

async def generate_explainability_card(
    simulation_context: dict[str, Any],
    task_list: list[dict[str, Any]],
    impacted_barangays: list[str],
) -> dict[str, str]:
    """
    Generate a plain-language Explainability Card using Gemini AI.

    The card translates raw simulation data into an accessible
    narrative that LGU operators can immediately understand and
    act upon, without requiring technical meteorological training.

    Parameters
    ----------
    simulation_context : dict
        Raw simulation parameters (wind speed, precipitation, etc.)
    task_list : list[dict]
        Time-decayed action items from the decay engine.
    impacted_barangays : list[str]
        Names of barangays within projected impact zones.

    Returns
    -------
    dict with keys:
        - summary: One-paragraph executive summary.
        - risk_narrative: Detailed risk explanation.
        - action_rationale: Why the recommended actions were selected.
        - confidence_note: Caveats and model confidence disclosure.
    """
    client = _get_gemini_client()

    if client is None:
        return _fallback_card(simulation_context, task_list, impacted_barangays)

    prompt = _build_prompt(simulation_context, task_list, impacted_barangays)

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.3,
                max_output_tokens=2048,
                response_mime_type="application/json",
                response_schema={
                    "type": "object",
                    "properties": {
                        "summary": {"type": "string"},
                        "risk_narrative": {"type": "string"},
                        "action_rationale": {"type": "string"},
                        "confidence_note": {"type": "string"},
                    },
                    "required": [
                        "summary",
                        "risk_narrative",
                        "action_rationale",
                        "confidence_note",
                    ],
                },
            ),
        )

        import json
        card = json.loads(response.text)
        logger.info("Gemini Explainability Card generated successfully.")
        return card

    except Exception as e:
        logger.error("Gemini API call failed: %s. Using fallback template.", e)
        return _fallback_card(simulation_context, task_list, impacted_barangays)


# -----------------------------------------------------------
# Prompt Builder
# -----------------------------------------------------------

def _build_prompt(
    context: dict[str, Any],
    tasks: list[dict[str, Any]],
    barangays: list[str],
) -> str:
    """Construct the structured prompt for Gemini."""
    barangay_list = ", ".join(barangays[:20])
    if len(barangays) > 20:
        barangay_list += f" (and {len(barangays) - 20} more)"

    task_summary = "\n".join(
        f"  - [{t.get('priority', 'MEDIUM')}] {t.get('action', 'N/A')} "
        f"(Deadline: T-{t.get('deadline_hours', '?')}h)"
        for t in tasks[:10]
    )

    return f"""You are a disaster preparedness communications specialist for 
Manila, Philippines. Generate a plain-language Explainability Card for 
local government unit (LGU) operators based on the following simulation data.

SIMULATION PARAMETERS:
- Wind Speed: {context.get('wind_speed_kph', 'N/A')} kph
- 24-hour Precipitation: {context.get('precipitation_24h_mm', 'N/A')} mm
- Preparation Window: {context.get('preparation_window_hours', 'N/A')} hours before impact
- Severity Tier: {context.get('severity_tier', 'N/A')}

IMPACTED BARANGAYS: {barangay_list}

RECOMMENDED ACTIONS:
{task_summary}

Respond with a JSON object containing exactly these keys:
1. "summary" — A one-paragraph executive summary (3-4 sentences max).
2. "risk_narrative" — Plain-language explanation of the threat scenario.
3. "action_rationale" — Why these specific actions were prioritized.
4. "confidence_note" — Caveats about model limitations and data freshness.

Write for a non-technical audience. Use clear, direct language.
Avoid jargon. Be specific about Manila geography where relevant."""


# -----------------------------------------------------------
# Fallback Template
# -----------------------------------------------------------

def _fallback_card(
    context: dict[str, Any],
    tasks: list[dict[str, Any]],
    barangays: list[str],
) -> dict[str, str]:
    """
    Generate a template-based Explainability Card when
    the Gemini API is unavailable or unconfigured.
    """
    prep = context.get("preparation_window_hours", "unknown")
    wind = context.get("wind_speed_kph", "unknown")
    rain = context.get("precipitation_24h_mm", "unknown")
    severity = context.get("severity_tier", "unknown")
    n_barangays = len(barangays)

    return {
        "summary": (
            f"A {severity}-severity weather event is projected to impact "
            f"{n_barangays} barangays within the next {prep} hours. "
            f"Wind speeds of {wind} kph and {rain}mm of accumulated rainfall "
            f"are expected. Immediate action is required per the generated task list."
        ),
        "risk_narrative": (
            f"Based on current meteorological projections, wind speeds of "
            f"{wind} kph combined with {rain}mm of rainfall over 24 hours "
            f"present significant flood and structural damage risks to "
            f"low-lying coastal and riverine barangays."
        ),
        "action_rationale": (
            f"The {len(tasks)} recommended actions have been prioritized "
            f"using a time-decay model calibrated to the {prep}-hour "
            f"preparation window. High-latency administrative tasks have been "
            f"filtered based on feasibility constraints."
        ),
        "confidence_note": (
            "This analysis is generated from simulation parameters and may "
            "not reflect real-time ground conditions. The Gemini AI service "
            "is currently unavailable; this card uses template-based output. "
            "Cross-reference with PAGASA advisories before executing actions."
        ),
    }


# -----------------------------------------------------------
# Context-Aware Action Plan Generator (LLM Pipeline)
# -----------------------------------------------------------

_ACTION_PLAN_SCHEMA = {
    "type": "object",
    "properties": {
        "action_plan_tasks": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "priority": {"type": "string"},
                    "action": {"type": "string"},
                    "deadline_hours": {"type": "integer"},
                    "category": {"type": "string"},
                    "responsible_unit": {"type": "string"},
                    "rationale": {"type": "string"},
                },
                "required": [
                    "priority", "action", "deadline_hours",
                    "category", "responsible_unit", "rationale",
                ],
            },
        },
        "explainability_card": {
            "type": "object",
            "properties": {
                "summary": {"type": "string"},
                "risk_narrative": {"type": "string"},
                "action_rationale": {"type": "string"},
                "confidence_note": {"type": "string"},
            },
            "required": [
                "summary", "risk_narrative",
                "action_rationale", "confidence_note",
            ],
        },
        "risk_assessment": {
            "type": "object",
            "properties": {
                "overall_threat_level": {"type": "string"},
                "primary_risks": {
                    "type": "array",
                    "items": {"type": "string"},
                },
                "geographic_focus": {"type": "string"},
                "time_critical_factors": {"type": "string"},
            },
            "required": [
                "overall_threat_level", "primary_risks",
                "geographic_focus", "time_critical_factors",
            ],
        },
    },
    "required": [
        "action_plan_tasks", "explainability_card", "risk_assessment",
    ],
}


async def generate_action_plan_with_context(
    llm_context: LLMContext,
) -> LLMActionPlanResponse:
    """
    Generate a complete, context-aware action plan using Gemini AI.

    This is the primary LLM pipeline function. It:
    1. Serializes the full LLMContext into a structured text document.
    2. Calls Gemini with the ACTA system instruction and context.
    3. Parses the structured JSON response into an LLMActionPlanResponse.
    4. Falls back to template-based output if Gemini is unavailable.

    Parameters
    ----------
    llm_context : LLMContext
        Complete structured context assembled from basic parameters
        and simulation data.

    Returns
    -------
    LLMActionPlanResponse
        AI-generated action plan with tasks, explainability, and
        risk assessment.
    """
    client = _get_gemini_client()

    if client is None:
        logger.warning("Gemini unavailable. Using fallback action plan.")
        return _fallback_action_plan(llm_context)

    # Serialize the full context into a structured document
    context_document = llm_context.to_context_document()

    user_prompt = f"""Based on the complete simulation context below, generate a 
disaster response action plan for Manila LGU operators.

FULL SIMULATION CONTEXT:
{context_document}

INSTRUCTIONS:
1. Generate 8-15 prioritized action tasks based on ALL the data above.
2. Refine the template tasks from Section 4 using the specific risk data from 
   Sections 2 and 3. Add new tasks where the data warrants it.
3. Each task must reference specific barangays, districts, or infrastructure 
   from the context when relevant.
4. Adjust task priorities based on the actual severity tier and zone distribution.
5. If infrastructure nodes are offline (Section 3), generate compensatory tasks.
6. Write an explainability card that synthesizes all sections into accessible language.
7. Provide a risk assessment identifying the most critical geographic and temporal factors.
8. All deadlines must fit within the T-{llm_context.basic_parameters.preparation_window_hours}h 
   preparation window."""

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=user_prompt,
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_INSTRUCTION,
                temperature=0.3,
                max_output_tokens=4096,
                response_mime_type="application/json",
                response_schema=_ACTION_PLAN_SCHEMA,
            ),
        )

        import json
        raw_response = json.loads(response.text)

        plan = LLMActionPlanResponse(**raw_response)
        logger.info(
            "LLM Action Plan generated: %d tasks, severity context: %s",
            len(plan.action_plan_tasks),
            llm_context.simulation_results.severity_tier,
        )
        return plan

    except Exception as e:
        logger.error(
            "Gemini action plan generation failed: %s. Using fallback.", e
        )
        return _fallback_action_plan(llm_context)


def _fallback_action_plan(llm_context: LLMContext) -> LLMActionPlanResponse:
    """
    Generate a template-based action plan when Gemini is unavailable.
    Converts decay-engine tasks into the LLM response format and
    generates template explainability/risk content.
    """
    from app.models.llm_models import (
        LLMActionPlanResponse,
        LLMExplainabilityCard,
        LLMRiskAssessment,
        LLMTaskItem,
    )

    bp = llm_context.basic_parameters
    sr = llm_context.simulation_results
    zs = sr.zone_summary

    # Convert decay-engine tasks to LLM task format
    tasks = [
        LLMTaskItem(
            priority=t.priority,
            action=t.action,
            deadline_hours=t.deadline_hours,
            category=t.category,
            responsible_unit=t.responsible_unit or "Operations Center",
            rationale=f"Template task from time-decay engine ({t.category}).",
        )
        for t in llm_context.decay_engine_tasks
    ]

    # Build red barangay context string
    red_names = ", ".join(sr.all_red_barangay_names[:10]) if sr.all_red_barangay_names else "none identified"

    card = LLMExplainabilityCard(
        summary=(
            f"A {sr.severity_tier}-severity weather event is projected to impact "
            f"{zs.total_barangays} barangays within the next {bp.preparation_window_hours} hours. "
            f"Wind speeds of {bp.wind_speed_kph} kph and {bp.precipitation_24h_mm}mm of "
            f"accumulated rainfall are expected. {zs.red_zones} barangays are in the active "
            f"danger zone requiring immediate action."
        ),
        risk_narrative=(
            f"Wind speeds of {bp.wind_speed_kph} kph combined with "
            f"{bp.precipitation_24h_mm}mm of rainfall over 24 hours present significant "
            f"flood and structural damage risks. {zs.red_zones} RED-zone barangays "
            f"face active danger, particularly: {red_names}."
        ),
        action_rationale=(
            f"The {len(tasks)} recommended actions have been prioritized using a "
            f"time-decay model calibrated to the T-{bp.preparation_window_hours}h "
            f"preparation window. Tasks are filtered by feasibility constraints "
            f"based on the {sr.severity_tier} severity tier."
        ),
        confidence_note=(
            "This plan uses template-based output because the Gemini AI service "
            "is currently unavailable. The analysis is based on simulation parameters "
            "and may not reflect real-time ground conditions. Cross-reference with "
            "PAGASA advisories before executing actions."
        ),
    )

    risk = LLMRiskAssessment(
        overall_threat_level=sr.severity_tier,
        primary_risks=[
            f"Flooding in {zs.red_zones} RED-zone barangays",
            f"Wind damage at {bp.wind_speed_kph} kph sustained speeds",
            f"Storm surge risk along Manila Bay coastal barangays",
        ],
        geographic_focus=(
            f"Primary focus on {zs.red_zones} RED-zone and "
            f"{zs.yellow_zones} YELLOW-zone barangays"
        ),
        time_critical_factors=(
            f"T-{bp.preparation_window_hours}h preparation window. "
            f"All tasks must complete before projected impact."
        ),
    )

    return LLMActionPlanResponse(
        action_plan_tasks=tasks,
        explainability_card=card,
        risk_assessment=risk,
        generated_by="fallback-template",
    )

