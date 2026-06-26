"""
ACTA Backend — Time-Decay Planning Engine
==========================================
Generates time-decayed, priority-ordered action tasks based on
the preparation window duration and threat severity tier.

Core Algorithm (PAGASA-aligned):
    As the preparation window shrinks (T → 0), complex high-latency
    administrative tasks are progressively stripped, leaving only
    immediate lifesaving directives.

State-Transition Boundaries (expanded):
    T >= 720h (1 month+)  : Structural & long-term preparedness
    168h <= T < 720h (1 wk–1 mo) : Pre-positioning & readiness drills
    48h <= T < 168h (48h–1 wk) : Logistical deployment & mobilization
    T < 48h : Immediate forced-response directives only

References:
    - PAGASA Tropical Cyclone Warning System
    - app.core.pagasa_constants — official thresholds
"""

from __future__ import annotations

import logging
from typing import Any

from app.core.pagasa_constants import classify_prep_window, PHASE_LABELS

logger = logging.getLogger("acta.decay_engine")


# -----------------------------------------------------------
# Task Templates by Phase
# -----------------------------------------------------------

# LONG_TERM: 1 month – 6 months before impact
# Focus: Structural audits, infrastructure upgrades, inter-agency MOAs, drills
_LONG_TERM_TASKS: list[dict[str, Any]] = [
    {
        "task_id": "T-L01",
        "priority": "LOW",
        "action": "Conduct comprehensive structural integrity audit of all designated evacuation centers across 6 districts",
        "category": "infrastructure_inspection",
        "deadline_hours": 4320,
        "responsible_unit": "City Engineering Office",
        "estimated_duration_hours": 120.0,
    },
    {
        "task_id": "T-L02",
        "priority": "LOW",
        "action": "Execute full clearing and desiltation of primary and secondary drainage channels citywide",
        "category": "infrastructure_maintenance",
        "deadline_hours": 3600,
        "responsible_unit": "DPWH District Engineering",
        "estimated_duration_hours": 240.0,
    },
    {
        "task_id": "T-L03",
        "priority": "LOW",
        "action": "Negotiate and sign inter-agency Memoranda of Agreement (MOAs) with DSWD, BFP, PRC, and PNP for disaster coordination",
        "category": "coordination",
        "deadline_hours": 2880,
        "responsible_unit": "MDRRMO Office",
        "estimated_duration_hours": 160.0,
    },
    {
        "task_id": "T-L04",
        "priority": "LOW",
        "action": "Conduct community-level flood evacuation drills in all historically RED-tier barangays",
        "category": "community_preparedness",
        "deadline_hours": 2160,
        "responsible_unit": "Barangay Captains / MDRRMO",
        "estimated_duration_hours": 80.0,
    },
    {
        "task_id": "T-L05",
        "priority": "LOW",
        "action": "Procure and pre-position strategic reserves of rescue watercraft, emergency rations, and medical supplies",
        "category": "logistics",
        "deadline_hours": 1440,
        "responsible_unit": "City General Services / DSWD",
        "estimated_duration_hours": 96.0,
    },
]

# MEDIUM_TERM: 1 week – 1 month before impact
# Focus: Pre-positioning, sensor calibration, community awareness, shelter prep
_MEDIUM_TERM_TASKS: list[dict[str, Any]] = [
    {
        "task_id": "T-M01",
        "priority": "MEDIUM",
        "action": "Verify clearance metrics of primary drainage channels across all districts",
        "category": "infrastructure_inspection",
        "deadline_hours": 504,
        "responsible_unit": "DPWH District Engineering",
        "estimated_duration_hours": 12.0,
    },
    {
        "task_id": "T-M02",
        "priority": "MEDIUM",
        "action": "Pre-position mechanical pumping fuel reserves at all 36 pumping stations",
        "category": "logistics",
        "deadline_hours": 480,
        "responsible_unit": "MMDA Flood Control",
        "estimated_duration_hours": 8.0,
    },
    {
        "task_id": "T-M03",
        "priority": "MEDIUM",
        "action": "Test and calibrate all automated flood sensor telemetry and rain gauge systems",
        "category": "systems_check",
        "deadline_hours": 360,
        "responsible_unit": "DOST-ASTI",
        "estimated_duration_hours": 6.0,
    },
    {
        "task_id": "T-M04",
        "priority": "MEDIUM",
        "action": "Coordinate with PAGASA for enhanced storm track model updates and issue preliminary advisory to barangay captains",
        "category": "coordination",
        "deadline_hours": 336,
        "responsible_unit": "MDRRMO Intelligence",
        "estimated_duration_hours": 4.0,
    },
    {
        "task_id": "T-M05",
        "priority": "MEDIUM",
        "action": "Conduct structural integrity assessment of identified high-risk evacuation shelters and certify occupancy limits",
        "category": "infrastructure_inspection",
        "deadline_hours": 240,
        "responsible_unit": "City Engineering Office",
        "estimated_duration_hours": 16.0,
    },
]

# SHORT_TERM: 48 hours – 1 week before impact
# Focus: Logistical mobilization, voluntary evacuations, hospital surge
_SHORT_TERM_TASKS: list[dict[str, Any]] = [
    {
        "task_id": "T-S01",
        "priority": "HIGH",
        "action": "Deploy emergency relief distribution hubs at pre-designated school gymnasiums in all 6 districts",
        "category": "logistics",
        "deadline_hours": 120,
        "responsible_unit": "DSWD Field Office",
        "estimated_duration_hours": 6.0,
    },
    {
        "task_id": "T-S02",
        "priority": "HIGH",
        "action": "Execute voluntary evacuation advisories for all low-lying barangay sectors below 3m ASL",
        "category": "evacuation",
        "deadline_hours": 96,
        "responsible_unit": "Barangay Captains",
        "estimated_duration_hours": 8.0,
    },
    {
        "task_id": "T-S03",
        "priority": "HIGH",
        "action": "Activate all barangay emergency communication radio networks and SMS blast systems",
        "category": "communications",
        "deadline_hours": 72,
        "responsible_unit": "MDRRMO Communications",
        "estimated_duration_hours": 2.0,
    },
    {
        "task_id": "T-S04",
        "priority": "MEDIUM",
        "action": "Stage rescue watercraft and inflatable boats at 12 priority riverine access points",
        "category": "logistics",
        "deadline_hours": 60,
        "responsible_unit": "BFP Marine Division",
        "estimated_duration_hours": 4.0,
    },
    {
        "task_id": "T-S05",
        "priority": "MEDIUM",
        "action": "Coordinate hospital surge capacity activation with Manila Health Department and Philippine Red Cross",
        "category": "medical",
        "deadline_hours": 48,
        "responsible_unit": "Manila Health Department",
        "estimated_duration_hours": 3.0,
    },
]

# EMERGENCY: < 48 hours before impact
# Focus: Forced evacuations, pumping activation, road closures, SAR deployment
_EMERGENCY_TASKS: list[dict[str, Any]] = [
    {
        "task_id": "T-E01",
        "priority": "CRITICAL",
        "action": "Trigger mandatory forced evacuations along all coastal edges and riverine flood plains",
        "category": "evacuation",
        "deadline_hours": 36,
        "responsible_unit": "PNP / Barangay Tanods",
        "estimated_duration_hours": 6.0,
    },
    {
        "task_id": "T-E02",
        "priority": "CRITICAL",
        "action": "Activate all pumping station operations to maximum continuous capacity",
        "category": "infrastructure_operations",
        "deadline_hours": 24,
        "responsible_unit": "MMDA Flood Control",
        "estimated_duration_hours": 1.0,
    },
    {
        "task_id": "T-E03",
        "priority": "CRITICAL",
        "action": "Close all identified drainage gates in tidal surge exposure zones",
        "category": "infrastructure_operations",
        "deadline_hours": 18,
        "responsible_unit": "DPWH Operations",
        "estimated_duration_hours": 2.0,
    },
    {
        "task_id": "T-E04",
        "priority": "HIGH",
        "action": "Deploy search-and-rescue standby teams to all 6 district command posts",
        "category": "emergency_response",
        "deadline_hours": 12,
        "responsible_unit": "BFP / Philippine Red Cross",
        "estimated_duration_hours": 2.0,
    },
    {
        "task_id": "T-E05",
        "priority": "HIGH",
        "action": "Suspend all non-essential vehicular traffic on primary arterial roads",
        "category": "traffic_management",
        "deadline_hours": 6,
        "responsible_unit": "MMDA Traffic Division",
        "estimated_duration_hours": 1.0,
    },
]


# -----------------------------------------------------------
# Severity Modifiers
# -----------------------------------------------------------

_SEVERITY_PRIORITY_BOOST: dict[str, int] = {
    "low": 0,
    "moderate": 0,
    "high": 1,
    "critical": 2,
}

_PRIORITY_LEVELS = ["LOW", "MEDIUM", "HIGH", "CRITICAL"]


def _boost_priority(current: str, boost: int) -> str:
    """Elevate a task's priority by `boost` levels."""
    idx = _PRIORITY_LEVELS.index(current)
    new_idx = min(idx + boost, len(_PRIORITY_LEVELS) - 1)
    return _PRIORITY_LEVELS[new_idx]


# -----------------------------------------------------------
# Core Engine Function
# -----------------------------------------------------------

def generate_time_decay_tasks(
    prep_window: int,
    severity_tier: str,
) -> list[dict[str, Any]]:
    """
    Generate a time-decayed list of disaster preparedness tasks.

    State-Transition Constraints (PAGASA-aligned):
        - LONG_TERM (T >= 720h / 1 month): Full structural preparedness.
        - MEDIUM_TERM (168h <= T < 720h / 1 wk–1 mo): Pre-positioning & drills.
        - SHORT_TERM (48h <= T < 168h / 48h–1 wk): Logistical deployment.
        - EMERGENCY (T < 48h): ONLY immediate lifesaving directives.
          All complex, high-latency administrative tasks are stripped.

    Parameters
    ----------
    prep_window : int
        Hours remaining before projected disaster impact.
    severity_tier : str
        Threat severity: 'low', 'moderate', 'high', or 'critical'.

    Returns
    -------
    list[dict]
        Ordered list of task dictionaries, sorted by deadline.
    """
    severity_tier = severity_tier.lower()
    boost = _SEVERITY_PRIORITY_BOOST.get(severity_tier, 0)
    phase = classify_prep_window(prep_window)

    tasks: list[dict[str, Any]] = []

    # -------------------------------------------------------
    # State-Transition Logic (cascading inclusion)
    # -------------------------------------------------------

    if phase == "LONG_TERM":
        # LONG WINDOW (>= 1 month): Full operational readiness pipeline.
        # Include ALL task phases — long-term through emergency.
        logger.info(
            "Prep window %dh → phase: %s. Generating full structural readiness pipeline.",
            prep_window, PHASE_LABELS[phase],
        )
        tasks.extend(_LONG_TERM_TASKS)
        tasks.extend(_MEDIUM_TERM_TASKS)
        tasks.extend(_SHORT_TERM_TASKS)
        tasks.extend(_EMERGENCY_TASKS)

    elif phase == "MEDIUM_TERM":
        # MEDIUM WINDOW (1 week – 1 month): Pre-positioning focus.
        # Strip long-term structural tasks — insufficient time.
        logger.info(
            "Prep window %dh → phase: %s. Pre-positioning and readiness.",
            prep_window, PHASE_LABELS[phase],
        )
        tasks.extend(_MEDIUM_TERM_TASKS)
        tasks.extend(_SHORT_TERM_TASKS)
        tasks.extend(_EMERGENCY_TASKS)

    elif phase == "SHORT_TERM":
        # SHORT WINDOW (48h – 1 week): Logistical deployment.
        # Strip pre-positioning and structural tasks.
        logger.info(
            "Prep window %dh → phase: %s. Logistical mobilization.",
            prep_window, PHASE_LABELS[phase],
        )
        tasks.extend(_SHORT_TERM_TASKS)
        tasks.extend(_EMERGENCY_TASKS)

    else:
        # EMERGENCY (< 48h): Immediate directives ONLY.
        # Strip ALL complex, high-latency administrative tasks.
        logger.warning(
            "Prep window %dh → phase: %s. EMERGENCY MODE — "
            "only immediate lifesaving directives.",
            prep_window, PHASE_LABELS.get(phase, phase),
        )
        tasks.extend(_EMERGENCY_TASKS)

    # -------------------------------------------------------
    # Apply severity-based priority boost
    # -------------------------------------------------------

    boosted_tasks: list[dict[str, Any]] = []
    for task in tasks:
        t = task.copy()
        t["priority"] = _boost_priority(t["priority"], boost)

        # Clamp deadline to preparation window.
        if t["deadline_hours"] > prep_window:
            t["deadline_hours"] = max(prep_window - 1, 0)

        boosted_tasks.append(t)

    # Sort by deadline (earliest first), then by priority (highest first).
    priority_order = {p: i for i, p in enumerate(reversed(_PRIORITY_LEVELS))}
    boosted_tasks.sort(
        key=lambda t: (t["deadline_hours"], priority_order.get(t["priority"], 99))
    )

    logger.info(
        "Generated %d tasks for T-%dh (phase=%s, severity=%s).",
        len(boosted_tasks), prep_window, phase, severity_tier,
    )

    return boosted_tasks
