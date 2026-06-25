"""
ACTA Backend — Action Plan Models
====================================
Pydantic schemas for structured disaster response action plans,
including phase-based task groupings and timeline markers.

Target Branch : feature/backend-decay
Commit        : feat(backend): add pydantic simulation and action plan models
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


# -----------------------------------------------------------
# Enums
# -----------------------------------------------------------

class TaskPhase(str, Enum):
    """Operational phase classification for action items."""
    PRE_IMPACT_STRUCTURAL = "pre_impact_structural"
    LOGISTICAL_TRANSITION = "logistical_transition"
    IMMEDIATE_RESPONSE = "immediate_response"
    POST_IMPACT_RECOVERY = "post_impact_recovery"


class TaskPriority(str, Enum):
    """Task urgency classification."""
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"


# -----------------------------------------------------------
# Action Plan Models
# -----------------------------------------------------------

class ActionTask(BaseModel):
    """
    A discrete, actionable task within the disaster response plan.

    Attributes
    ----------
    task_id : str
        Unique identifier for tracking (e.g., 'T-001').
    phase : TaskPhase
        Operational phase this task belongs to.
    priority : TaskPriority
        Urgency classification.
    action : str
        Plain-language directive for the operator.
    responsible_unit : str
        The organizational unit or role responsible.
    deadline_hours : int
        Hours before impact by which this task must be completed.
    estimated_duration_hours : float
        Estimated time to execute this task.
    dependencies : list[str]
        List of task_ids that must complete before this task.
    location_context : str
        Geographic or organizational context for the task.
    """

    task_id: str = Field(description="Unique task identifier (e.g., 'T-001').")
    phase: TaskPhase
    priority: TaskPriority
    action: str
    responsible_unit: str = Field(default="Operations Center")
    deadline_hours: int = Field(ge=0)
    estimated_duration_hours: float = Field(default=1.0, ge=0)
    dependencies: list[str] = Field(default_factory=list)
    location_context: str = Field(default="City-wide")


class ActionPlan(BaseModel):
    """
    Complete disaster response action plan containing
    phase-grouped tasks with timeline metadata.
    """

    plan_id: str = Field(description="Unique plan identifier.")
    severity_tier: str
    preparation_window_hours: int
    generated_at: datetime = Field(default_factory=datetime.utcnow)
    total_tasks: int = Field(ge=0)
    tasks: list[ActionTask]
    phases_active: list[TaskPhase] = Field(
        description="Which operational phases are active in this plan."
    )

    @property
    def critical_tasks(self) -> list[ActionTask]:
        """Filter to CRITICAL priority tasks only."""
        return [t for t in self.tasks if t.priority == TaskPriority.CRITICAL]

    @property
    def next_deadline_hours(self) -> int | None:
        """Return the nearest deadline across all tasks."""
        deadlines = [t.deadline_hours for t in self.tasks]
        return min(deadlines) if deadlines else None
