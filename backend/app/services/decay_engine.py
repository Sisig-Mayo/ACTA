"""
ACTA Backend — Time-Decay Planning Engine
==========================================
Generates time-decayed, priority-ordered action tasks based on
the preparation window duration and threat severity tier.

Core Algorithm:
    As the preparation window shrinks (T → 0), complex high-latency
    administrative tasks are progressively stripped, leaving only
    immediate lifesaving directives.

State-Transition Boundaries:
    T >= 48h : Structural pre-impact readiness
    24 <= T < 48h : Logistical transition actions
    T < 24h : Immediate forced-response directives only

Target Branch : feature/backend-decay
Commit        : feat(backend): implement async endpoints and proximity time decay service logic
"""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger("acta.decay_engine")


# -----------------------------------------------------------
# Task Templates by Phase
# -----------------------------------------------------------

_STRUCTURAL_TASKS: list[dict[str, Any]] = [
    {
        "task_id": "T-001",
        "priority": "MEDIUM",
        "action": "Verify clearance metrics of primary drainage channels across all districts",
        "category": "infrastructure_inspection",
        "deadline_hours": 72,
        "responsible_unit": "DPWH District Engineering",
        "estimated_duration_hours": 12.0,
    },
    {
        "task_id": "T-002",
        "priority": "MEDIUM",
        "action": "Pre-position mechanical pumping fuel reserves at all 36 pumping stations",
        "category": "logistics",
        "deadline_hours": 60,
        "responsible_unit": "MMDA Flood Control",
        "estimated_duration_hours": 8.0,
    },
    {
        "task_id": "T-003",
        "priority": "LOW",
        "action": "Conduct structural integrity assessment of identified high-risk evacuation shelters",
        "category": "infrastructure_inspection",
        "deadline_hours": 66,
        "responsible_unit": "City Engineering Office",
        "estimated_duration_hours": 16.0,
    },
    {
        "task_id": "T-004",
        "priority": "MEDIUM",
        "action": "Test and calibrate all automated flood sensor telemetry systems",
        "category": "systems_check",
        "deadline_hours": 54,
        "responsible_unit": "DOST-ASTI",
        "estimated_duration_hours": 6.0,
    },
    {
        "task_id": "T-005",
        "priority": "LOW",
        "action": "Coordinate with PAGASA for high-resolution storm track model updates every 6 hours",
        "category": "coordination",
        "deadline_hours": 48,
        "responsible_unit": "MDRRMO Intelligence",
        "estimated_duration_hours": 2.0,
    },
]

_LOGISTICAL_TASKS: list[dict[str, Any]] = [
    {
        "task_id": "T-010",
        "priority": "HIGH",
        "action": "Deploy emergency relief distribution hubs at pre-designated school gymnasiums",
        "category": "logistics",
        "deadline_hours": 36,
        "responsible_unit": "DSWD Field Office",
        "estimated_duration_hours": 6.0,
    },
    {
        "task_id": "T-011",
        "priority": "HIGH",
        "action": "Execute voluntary evacuation advisories for all low-lying barangay sectors below 3m ASL",
        "category": "evacuation",
        "deadline_hours": 30,
        "responsible_unit": "Barangay Captains",
        "estimated_duration_hours": 8.0,
    },
    {
        "task_id": "T-012",
        "priority": "HIGH",
        "action": "Activate all barangay emergency communication radio networks and SMS blast systems",
        "category": "communications",
        "deadline_hours": 28,
        "responsible_unit": "MDRRMO Communications",
        "estimated_duration_hours": 2.0,
    },
    {
        "task_id": "T-013",
        "priority": "MEDIUM",
        "action": "Stage rescue watercraft and inflatable boats at 12 priority riverine access points",
        "category": "logistics",
        "deadline_hours": 26,
        "responsible_unit": "BFP Marine Division",
        "estimated_duration_hours": 4.0,
    },
    {
        "task_id": "T-014",
        "priority": "MEDIUM",
        "action": "Coordinate hospital surge capacity activation with Manila Health Department",
        "category": "medical",
        "deadline_hours": 24,
        "responsible_unit": "Manila Health Department",
        "estimated_duration_hours": 3.0,
    },
]

_IMMEDIATE_TASKS: list[dict[str, Any]] = [
    {
        "task_id": "T-020",
        "priority": "CRITICAL",
        "action": "Trigger mandatory forced evacuations along all coastal edges and riverine flood plains",
        "category": "evacuation",
        "deadline_hours": 12,
        "responsible_unit": "PNP / Barangay Tanods",
        "estimated_duration_hours": 6.0,
    },
    {
        "task_id": "T-021",
        "priority": "CRITICAL",
        "action": "Activate all pumping station operations to maximum continuous capacity",
        "category": "infrastructure_operations",
        "deadline_hours": 8,
        "responsible_unit": "MMDA Flood Control",
        "estimated_duration_hours": 1.0,
    },
    {
        "task_id": "T-022",
        "priority": "CRITICAL",
        "action": "Close all identified drainage gates in tidal surge exposure zones",
        "category": "infrastructure_operations",
        "deadline_hours": 6,
        "responsible_unit": "DPWH Operations",
        "estimated_duration_hours": 2.0,
    },
    {
        "task_id": "T-023",
        "priority": "HIGH",
        "action": "Deploy search-and-rescue standby teams to all 6 district command posts",
        "category": "emergency_response",
        "deadline_hours": 4,
        "responsible_unit": "BFP / Philippine Red Cross",
        "estimated_duration_hours": 2.0,
    },
    {
        "task_id": "T-024",
        "priority": "HIGH",
        "action": "Suspend all non-essential vehicular traffic on primary arterial roads",
        "category": "traffic_management",
        "deadline_hours": 3,
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

    State-Transition Constraints:
        - Long (T >= 48h): Full structural pre-impact readiness tasks.
        - Medium (24 <= T < 48h): Logistical transition actions.
        - Short (T < 24h): ONLY immediate lifesaving directives.
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

    tasks: list[dict[str, Any]] = []

    # -------------------------------------------------------
    # State-Transition Logic
    # -------------------------------------------------------

    if prep_window >= 48:
        # LONG WINDOW: Full operational readiness pipeline.
        # Include ALL task phases — structural, logistical, and immediate.
        logger.info(
            "Prep window >= 48h (%dh). Generating full readiness pipeline.",
            prep_window,
        )
        tasks.extend(_STRUCTURAL_TASKS)
        tasks.extend(_LOGISTICAL_TASKS)
        tasks.extend(_IMMEDIATE_TASKS)

    elif 24 <= prep_window < 48:
        # MEDIUM WINDOW: Logistical transition focus.
        # Strip structural tasks — insufficient time for completion.
        logger.info(
            "Prep window 24-48h (%dh). Stripping structural tasks, "
            "focusing on logistical transition.",
            prep_window,
        )
        tasks.extend(_LOGISTICAL_TASKS)
        tasks.extend(_IMMEDIATE_TASKS)

    else:
        # SHORT WINDOW (< 24h): Immediate directives ONLY.
        # Strip ALL complex, high-latency administrative tasks.
        # Output exclusively localized lifesaving operations.
        logger.warning(
            "Prep window < 24h (%dh). EMERGENCY MODE — "
            "only immediate lifesaving directives.",
            prep_window,
        )
        tasks.extend(_IMMEDIATE_TASKS)

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
        "Generated %d tasks for T-%dh, severity=%s.",
        len(boosted_tasks), prep_window, severity_tier,
    )

    return boosted_tasks
