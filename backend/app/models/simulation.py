"""
ACTA Backend — Simulation Input/Output Models
===============================================
Pydantic validation schemas for simulation request payloads
and structured response objects.

Target Branch : feature/backend-decay
Commit        : feat(backend): add pydantic simulation and action plan models
"""

from __future__ import annotations

from enum import Enum
from typing import Any

from pydantic import BaseModel, Field, field_validator


# -----------------------------------------------------------
# Enums
# -----------------------------------------------------------

class SeverityTier(str, Enum):
    """Threat severity classification tiers."""
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"
    CRITICAL = "critical"


class ZoneStatus(str, Enum):
    """Barangay risk zone designations."""
    GREEN = "green"     # No immediate threat
    YELLOW = "yellow"   # Elevated risk — monitor
    RED = "red"         # Active danger — immediate action required


# -----------------------------------------------------------
# Request Models
# -----------------------------------------------------------

class SimulationInput(BaseModel):
    """
    Incoming simulation parameters from the LGU operator dashboard.

    Attributes
    ----------
    wind_speed_kph : float
        Sustained wind speed in kilometers per hour.
    precipitation_24h_mm : float
        Accumulated rainfall over the past/projected 24 hours in mm.
    preparation_window_hours : int
        Hours remaining before projected disaster impact (T).
    storm_track_points : list[list[float]]
        Ordered sequence of [longitude, latitude] coordinate pairs
        representing the projected storm track polyline.
    """

    wind_speed_kph: float = Field(
        ...,
        ge=0,
        le=400,
        description="Sustained wind speed in kph.",
        examples=[120.5],
    )
    precipitation_24h_mm: float = Field(
        ...,
        ge=0,
        le=2000,
        description="24-hour accumulated precipitation in mm.",
        examples=[350.0],
    )
    preparation_window_hours: int = Field(
        ...,
        ge=0,
        le=168,
        description="Hours until projected impact (T).",
        examples=[36],
    )
    storm_track_points: list[list[float]] = Field(
        ...,
        min_length=2,
        description="Storm track as [[lng, lat], ...] coordinate pairs.",
        examples=[[[120.98, 14.60], [120.95, 14.55], [120.90, 14.50]]],
    )

    @field_validator("storm_track_points", mode="after")
    @classmethod
    def validate_coordinates(cls, v: list[list[float]]) -> list[list[float]]:
        """Ensure each coordinate pair has exactly [lng, lat]."""
        for idx, point in enumerate(v):
            if len(point) != 2:
                raise ValueError(
                    f"Storm track point at index {idx} must have exactly "
                    f"2 values [lng, lat], got {len(point)}."
                )
            lng, lat = point
            if not (-180 <= lng <= 180):
                raise ValueError(
                    f"Longitude at index {idx} ({lng}) out of range [-180, 180]."
                )
            if not (-90 <= lat <= 90):
                raise ValueError(
                    f"Latitude at index {idx} ({lat}) out of range [-90, 90]."
                )
        return v


# -----------------------------------------------------------
# Response Models
# -----------------------------------------------------------

class BarangayImpact(BaseModel):
    """Impact assessment for a single barangay."""
    barangay_name: str
    district: str
    zone_status: ZoneStatus
    coverage_pct: float = Field(ge=0, le=100)
    centroid: list[float] = Field(description="[lng, lat] centroid.")


class TaskItem(BaseModel):
    """A single time-decayed action item."""
    priority: str = Field(description="CRITICAL, HIGH, MEDIUM, or LOW.")
    action: str = Field(description="Plain-language action directive.")
    deadline_hours: int = Field(description="Hours before impact deadline.")
    category: str = Field(description="Task category (e.g., evacuation, logistics).")


class ExplainabilityCard(BaseModel):
    """Gemini-generated plain-language explanation."""
    summary: str
    risk_narrative: str
    action_rationale: str
    confidence_note: str


class SimulationOutput(BaseModel):
    """
    Complete simulation response returned to the frontend.
    Combines impact assessment, action plan, and explainability.
    """
    severity_tier: SeverityTier
    preparation_window_hours: int
    impacted_barangays: list[BarangayImpact]
    task_list: list[TaskItem]
    explainability_card: ExplainabilityCard
    metadata: dict[str, Any] = Field(
        default_factory=dict,
        description="Additional diagnostic metadata.",
    )
