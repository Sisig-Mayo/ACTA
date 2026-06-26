"""
ACTA Backend — LLM Pipeline Data Models
==========================================
Pydantic schemas for the LLM context pipeline that assembles
basic parameters and simulation data into a structured context
for Gemini AI to generate context-aware action plans.

Target Branch : feature/llm-pipeline
Commit        : feat(backend): add LLM pipeline context and response models
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


# -----------------------------------------------------------
# Context Components
# -----------------------------------------------------------

class BasicParameters(BaseModel):
    """
    Raw simulation input parameters from the LGU operator.
    These are the 'basic data' that ground the LLM's understanding
    of the weather event.
    """
    wind_speed_kph: float = Field(description="Sustained wind speed in kph.")
    precipitation_24h_mm: float = Field(description="24-hour accumulated precipitation in mm.")
    preparation_window_hours: int = Field(description="Hours until projected impact (T).")
    storm_track_points: list[list[float]] = Field(
        default_factory=list,
        description="Storm track as [[lng, lat], ...] coordinate pairs.",
    )
    storm_radius_km: float = Field(default=50.0, description="Impact radius in km.")


class RiskScoreSummary(BaseModel):
    """Aggregated risk score summary for a single barangay."""
    barangay_name: str
    district: str
    total_risk_score: float
    risk_tier: str = Field(description="RED, YELLOW, or GREEN.")
    water_accumulation_score: float = 0.0
    elevation_factor: float = 0.0
    historical_frequency: float = 0.0


class ZoneSummary(BaseModel):
    """Counts of barangays by risk zone."""
    red_zones: int = 0
    yellow_zones: int = 0
    green_zones: int = 0
    total_barangays: int = 0


class InfrastructureNode(BaseModel):
    """Operational state of a single infrastructure node."""
    node_name: str
    node_type: str = Field(description="pumping_station or drainage_gate.")
    is_operational: bool = True
    latitude: float | None = None
    longitude: float | None = None


class DecayEngineTask(BaseModel):
    """A time-decayed task from the template-based decay engine."""
    task_id: str = ""
    priority: str
    action: str
    category: str
    deadline_hours: int
    responsible_unit: str = ""
    estimated_duration_hours: float = 1.0


class SimulationResults(BaseModel):
    """
    Aggregated simulation outputs that form the 'simulation data'
    context for the LLM.
    """
    severity_tier: str = Field(description="LOW, MODERATE, HIGH, or CRITICAL.")
    zone_summary: ZoneSummary = Field(default_factory=ZoneSummary)
    top_risk_barangays: list[RiskScoreSummary] = Field(
        default_factory=list,
        description="Top 15 highest-risk barangays by total_risk_score.",
    )
    all_red_barangay_names: list[str] = Field(
        default_factory=list,
        description="Names of all RED-zone barangays.",
    )


# -----------------------------------------------------------
# Full LLM Context
# -----------------------------------------------------------

class LLMContext(BaseModel):
    """
    Complete structured context document assembled from basic
    parameters and simulation data. This is the input fed to the
    Gemini LLM for context-aware action plan generation.

    Sections:
        1. basic_parameters — raw operator inputs
        2. simulation_results — risk scores, zone counts, severity
        3. infrastructure_status — pumping stations, drainage gates
        4. decay_engine_tasks — template-based tasks for refinement
        5. metadata — run ID, timestamps, pipeline version
    """
    basic_parameters: BasicParameters
    simulation_results: SimulationResults
    infrastructure_status: list[InfrastructureNode] = Field(default_factory=list)
    decay_engine_tasks: list[DecayEngineTask] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)

    def to_context_document(self) -> str:
        """
        Serialize the full context into a human-readable structured
        text document suitable for inclusion in an LLM prompt.
        """
        bp = self.basic_parameters
        sr = self.simulation_results
        zs = sr.zone_summary

        sections: list[str] = []

        # --- Section 1: Basic Parameters ---
        sections.append(
            "=== SECTION 1: BASIC PARAMETERS (Operator Inputs) ===\n"
            f"  Wind Speed: {bp.wind_speed_kph} kph\n"
            f"  24-hour Precipitation: {bp.precipitation_24h_mm} mm\n"
            f"  Preparation Window: T-{bp.preparation_window_hours} hours\n"
            f"  Storm Radius: {bp.storm_radius_km} km\n"
            f"  Storm Track Points: {len(bp.storm_track_points)} coordinates"
        )

        if bp.storm_track_points:
            track_str = " -> ".join(
                f"[{p[0]:.4f}, {p[1]:.4f}]" for p in bp.storm_track_points[:8]
            )
            if len(bp.storm_track_points) > 8:
                track_str += f" (... +{len(bp.storm_track_points) - 8} more)"
            sections[-1] += f"\n  Track Path: {track_str}"

        # --- Section 2: Simulation Results ---
        sections.append(
            "=== SECTION 2: SIMULATION RESULTS ===\n"
            f"  Overall Severity Tier: {sr.severity_tier}\n"
            f"  Total Barangays Assessed: {zs.total_barangays}\n"
            f"  RED Zones (Active Danger): {zs.red_zones}\n"
            f"  YELLOW Zones (Elevated Risk): {zs.yellow_zones}\n"
            f"  GREEN Zones (No Immediate Threat): {zs.green_zones}"
        )

        if sr.all_red_barangay_names:
            red_list = ", ".join(sr.all_red_barangay_names[:25])
            if len(sr.all_red_barangay_names) > 25:
                red_list += f" (+{len(sr.all_red_barangay_names) - 25} more)"
            sections[-1] += f"\n  RED-Zone Barangays: {red_list}"

        if sr.top_risk_barangays:
            top_lines = "\n".join(
                f"    {i+1}. {b.barangay_name} ({b.district}) - "
                f"Risk Score: {b.total_risk_score:.3f} [{b.risk_tier}] "
                f"(Water: {b.water_accumulation_score:.3f}, "
                f"Elevation: {b.elevation_factor:.3f}, "
                f"Historical: {b.historical_frequency:.3f})"
                for i, b in enumerate(sr.top_risk_barangays[:15])
            )
            sections[-1] += f"\n\n  TOP-15 HIGHEST-RISK BARANGAYS:\n{top_lines}"

        # --- Section 3: Infrastructure Status ---
        if self.infrastructure_status:
            operational = [n for n in self.infrastructure_status if n.is_operational]
            non_operational = [n for n in self.infrastructure_status if not n.is_operational]

            infra_text = (
                f"=== SECTION 3: INFRASTRUCTURE STATUS ===\n"
                f"  Total Nodes: {len(self.infrastructure_status)}\n"
                f"  Operational: {len(operational)}\n"
                f"  Non-Operational: {len(non_operational)}"
            )

            if non_operational:
                infra_text += "\n\n  WARNING - NON-OPERATIONAL NODES (Critical Attention):"
                for node in non_operational:
                    infra_text += f"\n    - {node.node_name} ({node.node_type}) - OFFLINE"

            pumping = [n for n in self.infrastructure_status if n.node_type == "pumping_station"]
            gates = [n for n in self.infrastructure_status if n.node_type == "drainage_gate"]
            infra_text += (
                f"\n\n  Breakdown:"
                f"\n    - Pumping Stations: {len(pumping)} total, "
                f"{sum(1 for p in pumping if p.is_operational)} operational"
                f"\n    - Drainage Gates: {len(gates)} total, "
                f"{sum(1 for g in gates if g.is_operational)} operational"
            )

            sections.append(infra_text)
        else:
            sections.append(
                "=== SECTION 3: INFRASTRUCTURE STATUS ===\n"
                "  No infrastructure status data currently available.\n"
                "  Assume all pumping stations and drainage gates require verification."
            )

        # --- Section 4: Decay Engine Tasks (Templates) ---
        if self.decay_engine_tasks:
            task_lines = "\n".join(
                f"    - [{t.priority}] {t.action} "
                f"(Deadline: T-{t.deadline_hours}h, Category: {t.category}, "
                f"Unit: {t.responsible_unit})"
                for t in self.decay_engine_tasks
            )
            sections.append(
                f"=== SECTION 4: TEMPLATE ACTION TASKS (Decay Engine) ===\n"
                f"  Total Template Tasks: {len(self.decay_engine_tasks)}\n"
                f"  These are baseline tasks generated by the time-decay algorithm.\n"
                f"  Refine, augment, or reprioritize based on the full context above.\n\n"
                f"{task_lines}"
            )
        else:
            sections.append(
                "=== SECTION 4: TEMPLATE ACTION TASKS ===\n"
                "  No template tasks available. Generate tasks from scratch based on context."
            )

        # --- Section 5: Metadata ---
        meta_items = "\n".join(
            f"  {k}: {v}" for k, v in self.metadata.items()
        ) if self.metadata else "  No additional metadata."

        sections.append(
            f"=== SECTION 5: PIPELINE METADATA ===\n"
            f"{meta_items}"
        )

        return "\n\n".join(sections)


# -----------------------------------------------------------
# LLM Response Models
# -----------------------------------------------------------

class LLMTaskItem(BaseModel):
    """
    AI-generated/refined action task with richer metadata
    than the template-based TaskItem.
    """
    priority: str = Field(description="CRITICAL, HIGH, MEDIUM, or LOW.")
    action: str = Field(description="Plain-language action directive.")
    deadline_hours: int = Field(description="Hours before impact deadline.")
    category: str = Field(description="Task category (evacuation, logistics, etc.).")
    responsible_unit: str = Field(
        default="Operations Center",
        description="Organizational unit or role responsible.",
    )
    rationale: str = Field(
        default="",
        description="Brief explanation of why this task was included/prioritized.",
    )


class LLMExplainabilityCard(BaseModel):
    """AI-generated plain-language explanation card."""
    summary: str = Field(description="One-paragraph executive summary (3-4 sentences).")
    risk_narrative: str = Field(description="Plain-language risk explanation.")
    action_rationale: str = Field(description="Why these actions were prioritized.")
    confidence_note: str = Field(description="Caveats about model limitations.")


class LLMRiskAssessment(BaseModel):
    """AI-generated risk assessment narrative."""
    overall_threat_level: str = Field(description="AI's assessment of overall threat.")
    primary_risks: list[str] = Field(
        default_factory=list,
        description="Top 3-5 primary risk factors identified.",
    )
    geographic_focus: str = Field(
        default="",
        description="Geographic areas requiring highest attention.",
    )
    time_critical_factors: str = Field(
        default="",
        description="Time-sensitive factors that affect response planning.",
    )


class LLMActionPlanResponse(BaseModel):
    """
    Complete structured response from the Gemini LLM.
    Contains the full AI-generated action plan with tasks,
    explainability, and risk assessment.
    """
    action_plan_tasks: list[LLMTaskItem] = Field(
        default_factory=list,
        description="AI-generated/refined prioritized task list.",
    )
    explainability_card: LLMExplainabilityCard
    risk_assessment: LLMRiskAssessment
    generated_by: str = Field(
        default="gemini-2.5-flash",
        description="Model identifier used for generation.",
    )
