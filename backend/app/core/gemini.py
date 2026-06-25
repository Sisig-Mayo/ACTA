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
Avoid jargon. Be specific about Manila geography where relevant. Strictly focus your explanation on the City of Manila and its barangays, do not include or mention other cities or provinces outside Manila."""


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
