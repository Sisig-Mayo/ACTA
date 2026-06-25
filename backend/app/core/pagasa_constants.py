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
"""

from __future__ import annotations

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

    Mapping:
        TD  (0–61):     0.05 – 0.20
        TS  (62–88):    0.20 – 0.40
        STS (89–117):   0.40 – 0.60
        TY  (118–184):  0.60 – 0.85
        STY (185+):     0.85 – 1.00
    """
    if wind_speed_kph <= 0:
        return 0.0
    elif wind_speed_kph <= 61:
        return 0.05 + (wind_speed_kph / 61) * 0.15
    elif wind_speed_kph <= 88:
        return 0.20 + ((wind_speed_kph - 62) / 26) * 0.20
    elif wind_speed_kph <= 117:
        return 0.40 + ((wind_speed_kph - 89) / 28) * 0.20
    elif wind_speed_kph <= 184:
        return 0.60 + ((wind_speed_kph - 118) / 66) * 0.25
    else:
        return min(0.85 + ((wind_speed_kph - 185) / 215) * 0.15, 1.0)


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
    risk factor calibrated against PAGASA advisory thresholds.

    Assumes sustained rainfall; converts 24h total to approximate
    hourly rate for PAGASA tier mapping, then produces a score.

    Mapping (24h totals → approximate hourly → factor):
        ≤ 180mm (≤7.5mm/h):    0.05 – 0.25  (GREEN)
        180–360mm (7.5–15mm/h): 0.25 – 0.50  (YELLOW)
        360–720mm (15–30mm/h):  0.50 – 0.80  (ORANGE)
        > 720mm (>30mm/h):      0.80 – 1.00  (RED)
    """
    if precipitation_24h_mm <= 0:
        return 0.0

    hourly_approx = precipitation_24h_mm / 24.0

    if hourly_approx <= 7.5:
        # GREEN tier
        return 0.05 + (hourly_approx / 7.5) * 0.20
    elif hourly_approx <= 15.0:
        # YELLOW tier
        return 0.25 + ((hourly_approx - 7.5) / 7.5) * 0.25
    elif hourly_approx <= 30.0:
        # ORANGE tier
        return 0.50 + ((hourly_approx - 15.0) / 15.0) * 0.30
    else:
        # RED tier
        return min(0.80 + ((hourly_approx - 30.0) / 30.0) * 0.20, 1.0)


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
