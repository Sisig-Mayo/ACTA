"""
ACTA Backend — PAGASA Official Typhoon Classifications
========================================================
Single source of truth for all typhoon wind speed categories,
rainfall advisory tiers, and time-decay phase boundaries.

All thresholds are derived from official PAGASA (Philippine
Atmospheric, Geophysical and Astronomical Services Administration)
operational standards.

References:
    - PAGASA Tropical Cyclone Intensity Scale
    - PAGASA Color-Coded Rainfall Advisory System
    - PAGASA Storm Surge Advisory System
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any


# -----------------------------------------------------------
# 1. Wind Speed Classifications (km/h)
# -----------------------------------------------------------
# Official PAGASA Tropical Cyclone Intensity Scale.
# Used to classify the typhoon category from sustained wind speed.

WIND_CLASSIFICATIONS: dict[str, tuple[float, float]] = {
    "TD":  (0, 61),       # Tropical Depression
    "TS":  (62, 88),      # Tropical Storm
    "STS": (89, 117),     # Severe Tropical Storm
    "TY":  (118, 184),    # Typhoon
    "STY": (185, 400),    # Super Typhoon
}

WIND_LABELS: dict[str, str] = {
    "TD":  "Tropical Depression",
    "TS":  "Tropical Storm",
    "STS": "Severe Tropical Storm",
    "TY":  "Typhoon",
    "STY": "Super Typhoon",
}


def classify_wind(wind_speed_kph: float) -> str:
    """
    Classify wind speed into a PAGASA typhoon category code.

    Parameters
    ----------
    wind_speed_kph : float
        Sustained wind speed in kilometers per hour.

    Returns
    -------
    str
        PAGASA code: 'TD', 'TS', 'STS', 'TY', or 'STY'.
    """
    for code, (low, high) in WIND_CLASSIFICATIONS.items():
        if low <= wind_speed_kph <= high:
            return code
    # Above 400 kph — still Super Typhoon
    return "STY"


def wind_risk_factor(wind_speed_kph: float) -> float:
    """
    Convert wind speed to a continuous 0–1 risk factor
    calibrated against PAGASA thresholds.

    Revised mapping (sharper at high end):
        TD  (0–61):     0.05 – 0.20
        TS  (62–88):    0.20 – 0.40
        STS (89–117):   0.40 – 0.65
        TY  (118–184):  0.65 – 0.90
        STY (185+):     0.90 – 1.00  (saturates by ~250 kph)
    """
    if wind_speed_kph <= 0:
        return 0.0
    elif wind_speed_kph <= 61:
        return 0.05 + (wind_speed_kph / 61) * 0.15
    elif wind_speed_kph <= 88:
        return 0.20 + ((wind_speed_kph - 62) / 26) * 0.20
    elif wind_speed_kph <= 117:
        return 0.40 + ((wind_speed_kph - 89) / 28) * 0.25
    elif wind_speed_kph <= 184:
        return 0.65 + ((wind_speed_kph - 118) / 66) * 0.25
    else:
        # Saturates quickly: 250 kph → ~0.99
        return min(0.90 + ((wind_speed_kph - 185) / 65) * 0.10, 1.0)


# -----------------------------------------------------------
# 2. Rainfall Advisory Tiers (mm/hr)
# -----------------------------------------------------------
# PAGASA Color-Coded Rainfall Warning System.
# Hourly precipitation rates mapped to risk advisories.

RAINFALL_TIERS: dict[str, dict[str, Any]] = {
    "GREEN": {
        "range_mm_hr": (0, 7.5),
        "label": "Light to Moderate",
        "description": "Flooding unlikely; standard drainage can manage volume.",
    },
    "YELLOW": {
        "range_mm_hr": (7.5, 15.0),
        "label": "Heavy",
        "description": "Flooding possible in low-lying barangays. Monitor drainage.",
    },
    "ORANGE": {
        "range_mm_hr": (15.0, 30.0),
        "label": "Intense",
        "description": "Flooding expected. Initiate localized evacuations.",
    },
    "RED": {
        "range_mm_hr": (30.0, 999.0),
        "label": "Torrential",
        "description": "Severe flash flooding imminent. Streets impassable.",
    },
}


def classify_rainfall(mm_per_hour: float) -> str:
    """
    Classify hourly rainfall rate into a PAGASA advisory tier.

    Parameters
    ----------
    mm_per_hour : float
        Rainfall rate in millimeters per hour.

    Returns
    -------
    str
        PAGASA tier: 'GREEN', 'YELLOW', 'ORANGE', or 'RED'.
    """
    for tier, info in RAINFALL_TIERS.items():
        low, high = info["range_mm_hr"]
        if low <= mm_per_hour < high:
            return tier
    return "RED"


def rainfall_risk_factor(precipitation_24h_mm: float) -> float:
    """
    Convert 24-hour accumulated rainfall to a continuous 0–1
    risk factor using DIRECT 24h total thresholds.

    Previous version divided by 24 (assuming uniform hourly rate),
    which massively under-scored typhoon rainfall because real
    typhoon rain is concentrated in intense bursts.

    Revised mapping (based on PAGASA 24h rainfall warning levels):
        ≤ 50mm:        0.05 – 0.20  (Light — no flood expected)
        50–100mm:      0.20 – 0.40  (Moderate — minor flooding)
        100–200mm:     0.40 – 0.65  (Heavy — significant flooding)
        200–350mm:     0.65 – 0.85  (Intense — severe flooding)
        350–500mm:     0.85 – 0.95  (Extreme — catastrophic)
        > 500mm:       0.95 – 1.00  (Unprecedented)

    These thresholds reflect Manila's drainage capacity (~50mm/day
    without flooding) and historical typhoon rainfall totals
    (Ondoy: ~450mm, Ulysses: ~300mm, Karding: ~200mm).
    """
    if precipitation_24h_mm <= 0:
        return 0.0

    mm = precipitation_24h_mm

    if mm <= 50:
        # Light rain — drainage can handle it
        return 0.05 + (mm / 50) * 0.15
    elif mm <= 100:
        # Moderate — minor ponding in low-lying areas
        return 0.20 + ((mm - 50) / 50) * 0.20
    elif mm <= 200:
        # Heavy — significant flooding likely
        return 0.40 + ((mm - 100) / 100) * 0.25
    elif mm <= 350:
        # Intense — severe flooding (Karding-level)
        return 0.65 + ((mm - 200) / 150) * 0.20
    elif mm <= 500:
        # Extreme — catastrophic (Ondoy-level)
        return 0.85 + ((mm - 350) / 150) * 0.10
    else:
        # Unprecedented
        return min(0.95 + ((mm - 500) / 500) * 0.05, 1.0)


def storm_surge_factor(
    wind_speed_kph: float,
    coastal_distance_km: float,
) -> float:
    """
    Estimate storm surge risk based on wind speed and distance
    to coastline, calibrated against PAGASA Storm Surge Advisory.

    Storm surge is the most lethal flood mechanism for coastal
    areas during typhoons. It is driven primarily by wind speed
    and is amplified in shallow coastal waters.

    PAGASA Storm Surge Advisory levels:
        Advisory 1: Up to 1m surge (TS/STS winds)
        Advisory 2: 1–2m surge (TY winds)
        Advisory 3: 2–5m surge (STY winds)

    The factor decays exponentially with distance from coast
    (surge penetrates ~2-5km inland depending on terrain).

    Parameters
    ----------
    wind_speed_kph : float
        Sustained wind speed in km/h.
    coastal_distance_km : float
        Distance from barangay centroid to nearest coastline in km.
        Use 0.0 for waterfront barangays.

    Returns
    -------
    float
        Storm surge risk factor in [0, 1].
    """
    if wind_speed_kph < 62 or coastal_distance_km > 10.0:
        # No meaningful surge below Tropical Storm winds
        # or beyond 10km inland.
        return 0.0

    # Wind-driven surge intensity (0-1)
    if wind_speed_kph <= 117:
        # TS/STS: Advisory 1 (up to 1m)
        wind_surge = 0.2 + ((wind_speed_kph - 62) / 55) * 0.3
    elif wind_speed_kph <= 184:
        # TY: Advisory 2 (1-2m)
        wind_surge = 0.5 + ((wind_speed_kph - 118) / 66) * 0.3
    else:
        # STY: Advisory 3 (2-5m)
        wind_surge = min(0.8 + ((wind_speed_kph - 185) / 100) * 0.2, 1.0)

    # Exponential distance decay (half-life ~1.5km)
    # At 0km: factor=1.0, at 1.5km: factor≈0.5, at 5km: factor≈0.1
    distance_decay = math.exp(-0.46 * coastal_distance_km)

    return wind_surge * distance_decay


# -----------------------------------------------------------
# 3. Time-Decay Preparation Window Phases
# -----------------------------------------------------------
# Defines the operational planning phases based on time
# remaining before projected impact.

PREP_WINDOW_PHASES: dict[str, tuple[int, int]] = {
    "EMERGENCY":   (0, 48),        # < 48h: Immediate tactical response
    "SHORT_TERM":  (48, 168),      # 48h – 1 week: Logistical deployment
    "MEDIUM_TERM": (168, 720),     # 1 week – 1 month: Pre-positioning
    "LONG_TERM":   (720, 4320),    # 1 month – 6 months: Structural readiness
}

PHASE_LABELS: dict[str, str] = {
    "EMERGENCY":   "Immediate Tactical Response (< 48 hours)",
    "SHORT_TERM":  "Logistical Deployment (48h – 1 week)",
    "MEDIUM_TERM": "Pre-positioning & Readiness (1 week – 1 month)",
    "LONG_TERM":   "Structural Preparedness (1 – 6 months)",
}


def classify_prep_window(hours: int) -> str:
    """
    Classify the preparation window into a planning phase.

    Parameters
    ----------
    hours : int
        Hours remaining before projected impact.

    Returns
    -------
    str
        Phase code: 'EMERGENCY', 'SHORT_TERM', 'MEDIUM_TERM', or 'LONG_TERM'.
    """
    for phase, (low, high) in PREP_WINDOW_PHASES.items():
        if low <= hours < high:
            return phase
    if hours >= 4320:
        return "LONG_TERM"
    return "EMERGENCY"


# -----------------------------------------------------------
# 4. Severity Tier Determination
# -----------------------------------------------------------
# Combines PAGASA wind classification and rainfall tier
# into a unified severity assessment.

def determine_severity(
    wind_speed_kph: float,
    precipitation_24h_mm: float,
    red_zone_pct: float = 0.0,
) -> str:
    """
    Determine overall severity tier using PAGASA inputs.

    Uses the highest signal among wind category, rainfall tier,
    and percentage of RED-classified barangays.

    Returns
    -------
    str
        'low', 'moderate', 'high', or 'critical'.
    """
    wind_cat = classify_wind(wind_speed_kph)
    rain_tier = classify_rainfall(precipitation_24h_mm / 24.0)

    # Wind-based severity
    wind_severity = {
        "TD": 0, "TS": 1, "STS": 2, "TY": 3, "STY": 4,
    }.get(wind_cat, 0)

    # Rainfall-based severity
    rain_severity = {
        "GREEN": 0, "YELLOW": 1, "ORANGE": 2, "RED": 3,
    }.get(rain_tier, 0)

    # Red zone density severity
    zone_severity = 0
    if red_zone_pct > 0.30:
        zone_severity = 4
    elif red_zone_pct > 0.10:
        zone_severity = 3
    elif red_zone_pct > 0.02:
        zone_severity = 2

    # Take the maximum signal
    max_severity = max(wind_severity, rain_severity, zone_severity)

    if max_severity >= 4:
        return "critical"
    elif max_severity >= 3:
        return "high"
    elif max_severity >= 2:
        return "moderate"
    return "low"


# -----------------------------------------------------------
# 5. Risk Model Configuration
# -----------------------------------------------------------
# All scoring weights and thresholds in one tunable dataclass.
# Adjustable without code changes — swap in a new instance
# to recalibrate the model.

@dataclass
class RiskModelConfig:
    """
    Tunable parameters for the composite risk scoring model.

    Weights must sum to 1.0 for normalized output.
    Thresholds determine GREEN/YELLOW/RED tier boundaries.
    """
    # --- Component weights (must sum to 1.0) ---
    weight_rainfall: float = 0.30
    weight_wind: float = 0.15
    weight_elevation: float = 0.20
    weight_historical: float = 0.10
    weight_surge: float = 0.15
    weight_drainage: float = 0.10

    # --- Tier thresholds (0-1 scale) ---
    tier_red: float = 0.70
    tier_yellow: float = 0.40

    # --- Synergy boost ---
    # Amplification when BOTH rainfall AND wind are extreme.
    # Models the real-world fact that concurrent extreme rain
    # + wind is more dangerous than the sum of parts.
    synergy_multiplier: float = 0.30
    synergy_rain_threshold: float = 0.60   # rainfall_factor above this
    synergy_wind_threshold: float = 0.60   # wind_factor above this

    # --- Historical frequency ---
    historical_decay_factor: float = 200.0  # was 50; ~10km influence radius
    historical_max_penalty: float = 0.95    # was 0.9

    # --- Elevation / coastal model ---
    coastal_longitude_ref: float = 120.96   # Manila Bay coast reference lng
    coastal_proximity_scale: float = 12.0   # was 20; wider coastal influence
    river_latitude_ref: float = 14.59       # Pasig River reference lat
    river_proximity_scale: float = 10.0     # was 15; wider river influence

    def validate(self) -> None:
        """Ensure weights sum to 1.0 (within floating-point tolerance)."""
        total = (
            self.weight_rainfall + self.weight_wind +
            self.weight_elevation + self.weight_historical +
            self.weight_surge + self.weight_drainage
        )
        if abs(total - 1.0) > 0.01:
            raise ValueError(
                f"Risk model weights must sum to 1.0, got {total:.3f}"
            )


# Default configuration instance.
DEFAULT_RISK_CONFIG = RiskModelConfig()
