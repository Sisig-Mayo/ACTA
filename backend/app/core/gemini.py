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

logger = logging.getLogger("acta.gemini")


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
    base_tasks: list[dict[str, Any]],
    impacted_barangays: list[dict[str, Any]],
) -> dict[str, Any]:
    """
    Generate a plain-language Explainability Card and a highly specific
    Action Plan (Task List) using Gemini AI.

    Parameters
    ----------
    simulation_context : dict
        Raw simulation parameters (wind speed, precipitation, etc.)
    base_tasks : list[dict]
        Time-decayed base action guidelines from the decay engine.
    impacted_barangays : list[dict]
        List of dicts containing barangay_name, risk_tier, and population.

    Returns
    -------
    dict with keys:
        - explainability_card: dict
            - summary: One-paragraph executive summary.
            - risk_narrative: Detailed risk explanation.
            - action_rationale: Why the recommended actions were selected.
            - confidence_note: Caveats and model confidence disclosure.
        - tasks: list[dict]
            List of generated highly specific action items for the barangays.
    """
    client = _get_gemini_client()

    if client is None:
        return _fallback_card(simulation_context, base_tasks, impacted_barangays)

    prompt = _build_prompt(simulation_context, base_tasks, impacted_barangays)

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.4,
                max_output_tokens=4096,
                response_mime_type="application/json",
                response_schema={
                    "type": "object",
                    "properties": {
                        "explainability_card": {
                            "type": "object",
                            "properties": {
                                "summary": {"type": "string"},
                                "risk_narrative": {"type": "string"},
                                "action_rationale": {"type": "string"},
                                "confidence_note": {"type": "string"},
                            },
                            "required": ["summary", "risk_narrative", "action_rationale", "confidence_note"],
                        },
                        "tasks": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "priority": {"type": "string"},
                                    "action": {"type": "string"},
                                    "deadline_hours": {"type": "integer"},
                                    "category": {"type": "string"},
                                },
                                "required": ["priority", "action", "deadline_hours", "category"],
                            }
                        }
                    },
                    "required": ["explainability_card", "tasks"],
                },
            ),
        )

        import json
        result = json.loads(response.text)
        logger.info("Gemini Explainability Card and Task List generated successfully.")
        return result

    except Exception as e:
        logger.error("Gemini API call failed: %s. Using fallback template.", e)
        return _fallback_card(simulation_context, base_tasks, impacted_barangays)


# -----------------------------------------------------------
# Prompt Builder
# -----------------------------------------------------------

def _build_prompt(
    context: dict[str, Any],
    base_tasks: list[dict[str, Any]],
    barangays: list[dict[str, Any]],
) -> str:
    """Construct the structured prompt for Gemini."""
    
    # Format the impacted barangays to include their specific population and risk level
    b_strings = []
    for b in barangays:
        b_strings.append(f"{b['barangay_name']} ({b['risk_tier']} zone, Population: {b['population']})")
    
    barangay_list = "\n".join(b_strings[:30])
    if len(barangays) > 30:
        barangay_list += f"\n...and {len(barangays) - 30} more barangays."

    task_summary = "\n".join(
        f"  - [{t.get('priority', 'MEDIUM')}] {t.get('action', 'N/A')} "
        f"(Deadline: T-{t.get('deadline_hours', '?')}h) - Category: {t.get('category', 'general')}"
        for t in base_tasks[:10]
    )

    return f"""You are a highly analytical disaster preparedness decision engine for 
Manila, Philippines. Generate a highly specific Action Plan (Task List) and an Explainability Card 
for local government unit (LGU) operators based on the following simulation data.

SIMULATION PARAMETERS:
- Wind Speed: {context.get('wind_speed_kph', 'N/A')} kph (PAGASA: {context.get('wind_classification', 'N/A')})
- 24-hour Precipitation: {context.get('precipitation_24h_mm', 'N/A')} mm (PAGASA: {context.get('rainfall_advisory_tier', 'N/A')} Advisory)
- Preparation Window: {context.get('preparation_window_hours', 'N/A')} hours before impact
- Planning Phase: {context.get('planning_phase', 'N/A')}
- Severity Tier: {context.get('severity_tier', 'N/A')}

IMPACTED BARANGAYS (RED/YELLOW ZONES) WITH POPULATION DATA:
{barangay_list}

BASE GUIDELINE ACTIONS (PAGASA-Aligned):
{task_summary}

TIME CONTEXT (CRITICAL):
You must adjust your tone and focus based on the Planning Phase:
- If "Immediate Tactical Response" (< 48h): Focus on immediate life-safety, urgent directives, and forced evacuations.
- If "Logistical Deployment" (48h–1wk): Focus on logistical mobilization, resource staging, and voluntary evacuations.
- If "Pre-positioning & Readiness" (1wk–1mo): Focus on preparedness drills, pre-positioning assets, and community awareness.
- If "Structural Preparedness" (1–6mo): Focus on long-term structural improvements, inter-agency coordination, and capacity building.

TASK GENERATION INSTRUCTIONS:
Do NOT return generic tasks. You must use the Base Guideline Actions as a starting point, but transform them into specific directives targeting the Impacted Barangays based on their risk tier and population.
Example: "Dispatch 5 rescue boats and 10 transport trucks to Barangay 652 to evacuate 39 high-risk residents before T-36h."
Scale the required resources to the population size of the affected barangays. Limit to 5-8 highly impactful, specific tasks.

Respond with a JSON object containing exactly these keys:
1. "explainability_card": A nested object containing:
   - "summary": A one-paragraph executive summary (3-4 sentences max) incorporating the PAGASA classifications.
   - "risk_narrative": Plain-language explanation of the threat scenario referencing the impacted populations.
   - "action_rationale": Why these specific actions and resource allocations were prioritized.
   - "confidence_note": Caveats about model limitations and data freshness.
2. "tasks": An array of highly specific task objects, each containing:
   - "priority": "LOW", "MEDIUM", "HIGH", or "CRITICAL".
   - "action": The specific action directive mentioning barangay names and population-scaled resource numbers.
   - "deadline_hours": Integer hours before impact.
   - "category": e.g., "evacuation", "logistics", "infrastructure_operations", "medical".

Write for a non-technical audience. Use clear, direct language. Avoid jargon. Strictly focus your explanation on the City of Manila and its barangays, do not include or mention other cities or provinces outside Manila."""


# -----------------------------------------------------------
# Fallback Template
# -----------------------------------------------------------

def _fallback_card(
    context: dict[str, Any],
    base_tasks: list[dict[str, Any]],
    barangays: list[dict[str, Any]],
) -> dict[str, Any]:
    """
    Generate a template-based Explainability Card and Task List when
    the Gemini API is unavailable or unconfigured.
    """
    prep = context.get("preparation_window_hours", "unknown")
    wind = context.get("wind_speed_kph", "unknown")
    rain = context.get("precipitation_24h_mm", "unknown")
    severity = context.get("severity_tier", "unknown")
    n_barangays = len(barangays)

    return {
        "explainability_card": {
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
                f"The recommended actions have been prioritized "
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
        },
        "tasks": base_tasks
    }
