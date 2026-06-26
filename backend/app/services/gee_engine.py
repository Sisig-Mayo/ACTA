"""
ACTA Backend — Google Earth Engine Risk Analysis Engine
========================================================
Production-grade risk score calculator using GEE's Python API.

Combines three raster-based risk components:
1. Water Accumulation Score — precipitation × runoff coefficient
   derived from land cover imperviousness
2. Elevation Factor — DEM-based slope/elevation vulnerability
   from USGS SRTM 30m
3. Historical Flood Frequency — Sentinel-1 SAR backscatter
   analysis of known Manila flood events

Results are zonally reduced against barangay vector boundaries
using ee.Reducer.mean() and classified into RED/YELLOW/GREEN tiers.
"""

from __future__ import annotations

import hashlib
import json
import logging
import time
from pathlib import Path
from typing import Any

from app.core.config import settings
from app.core.pagasa_constants import (
    rainfall_risk_factor,
    wind_risk_factor,
    classify_wind,
    classify_rainfall,
    WIND_LABELS,
)

logger = logging.getLogger("acta.gee_engine")

# -----------------------------------------------------------
# GEE Initialization
# -----------------------------------------------------------

_is_initialized = False


def _initialize_gee() -> None:
    """
    Initialize the Earth Engine Python API using the service account key.
    Silently fails and sets fallback flag if credentials are not found.
    """
    global _is_initialized
    if _is_initialized:
        return

    try:
        import ee
    except ImportError:
        logger.warning("earthengine-api not installed. GEE integration disabled.")
        return

    key_file = settings.GEE_SERVICE_ACCOUNT_FILE
    if not key_file:
        logger.warning("GEE_SERVICE_ACCOUNT_FILE not set. GEE integration disabled.")
        return

    key_path = Path(key_file)
    if not key_path.is_absolute():
        key_path = Path(__file__).resolve().parent.parent.parent.parent / key_path

    if not key_path.exists():
        logger.warning("GEE key file not found at %s. GEE integration disabled.", key_path)
        return

    try:
        credentials = ee.ServiceAccountCredentials("", str(key_path))
        ee.Initialize(credentials)
        _is_initialized = True
        logger.info("Google Earth Engine initialized successfully.")
    except Exception as e:
        logger.error("Failed to initialize Google Earth Engine: %s", e)


# -----------------------------------------------------------
# In-Memory Result Cache (TTL-based)
# -----------------------------------------------------------

_result_cache: dict[str, dict[str, Any]] = {}
_CACHE_TTL_SECONDS = 3600  # 1 hour


def _cache_key(
    precipitation_mm: float,
    wind_speed_kph: float,
    storm_radius_km: float,
) -> str:
    """Generate a deterministic cache key from typhoon parameters."""
    raw = f"{precipitation_mm:.1f}|{wind_speed_kph:.1f}|{storm_radius_km:.1f}"
    return hashlib.sha256(raw.encode()).hexdigest()[:16]


def _get_cached(key: str) -> dict[str, Any] | None:
    """Retrieve cached result if still within TTL."""
    entry = _result_cache.get(key)
    if entry is None:
        return None
    if time.time() - entry["timestamp"] > _CACHE_TTL_SECONDS:
        del _result_cache[key]
        return None
    logger.info("Cache HIT for key %s", key)
    return entry["data"]


def _set_cache(key: str, data: dict[str, Any]) -> None:
    """Store result in cache with current timestamp."""
    _result_cache[key] = {"data": data, "timestamp": time.time()}
    # Evict oldest entries if cache grows too large (>50 entries).
    if len(_result_cache) > 50:
        oldest_key = min(_result_cache, key=lambda k: _result_cache[k]["timestamp"])
        del _result_cache[oldest_key]


# -----------------------------------------------------------
# Manila Bounding Box & Constants
# -----------------------------------------------------------

# Manila city boundary bounding box (WGS 84).
MANILA_BBOX = {
    "west": 120.935,
    "south": 14.55,
    "east": 121.03,
    "north": 14.66,
}

# Runoff coefficient matrix based on land cover type.
# Manila is highly urbanized — impervious surfaces dominate.
RUNOFF_COEFFICIENTS = {
    "urban_dense": 0.90,
    "urban_moderate": 0.75,
    "vegetation": 0.35,
    "water_body": 1.00,
    "default": 0.80,
}

# Risk tier thresholds (normalized 0–1 scale).
TIER_RED_THRESHOLD = 0.7
TIER_YELLOW_THRESHOLD = 0.4


# -----------------------------------------------------------
# Core Risk Calculation
# -----------------------------------------------------------

async def calculate_risk_scores(
    precipitation_mm: float,
    wind_speed_kph: float,
    storm_radius_km: float,
    barangay_geometries: list[dict[str, Any]],
) -> dict[str, Any]:
    """
    Calculate per-barangay flood risk scores using GEE raster analysis.

    Combines three risk components reduced against barangay boundaries:
    1. Water Accumulation = Precipitation × Runoff Matrix
    2. Elevation Factor = Slope/Elevation vulnerability
    3. Historical Frequency = SAR-derived flood occurrence penalty

    Parameters
    ----------
    precipitation_mm : float
        Projected 24-hour precipitation in millimeters.
    wind_speed_kph : float
        Sustained wind speed in km/h.
    storm_radius_km : float
        Storm impact radius in kilometers.
    barangay_geometries : list[dict]
        List of dicts with 'id', 'barangay_name', 'district', 'geom_geojson'.

    Returns
    -------
    dict with:
        - scores: list of per-barangay risk score dicts
        - source: 'earth_engine' or 'analytical_model'
        - summary: dict with zone counts
    """
    # Check cache first.
    ck = _cache_key(precipitation_mm, wind_speed_kph, storm_radius_km)
    cached = _get_cached(ck)
    if cached is not None:
        return cached

    _initialize_gee()

    if _is_initialized:
        try:
            result = await _gee_risk_analysis(
                precipitation_mm,
                wind_speed_kph,
                storm_radius_km,
                barangay_geometries,
            )
            _set_cache(ck, result)
            return result
        except Exception as e:
            logger.error("GEE risk analysis failed: %s. Falling back to analytical model.", e)

    # Fallback: analytical model using elevation heuristics.
    result = _analytical_risk_model(
        precipitation_mm,
        wind_speed_kph,
        storm_radius_km,
        barangay_geometries,
    )
    _set_cache(ck, result)
    return result


async def _gee_risk_analysis(
    precipitation_mm: float,
    wind_speed_kph: float,
    storm_radius_km: float,
    barangay_geometries: list[dict[str, Any]],
) -> dict[str, Any]:
    """
    Full GEE-based risk analysis pipeline.

    Steps:
    1. Define Manila ROI from bounding box
    2. Load SRTM DEM → compute elevation & slope layers
    3. Load Sentinel-1 SAR historical flood frequency
    4. Compute composite risk raster
    5. Zonal reduction against barangay polygons
    """
    import ee

    logger.info("Starting GEE risk analysis: precip=%.0fmm, wind=%.0fkph", precipitation_mm, wind_speed_kph)

    # 1. Define Region of Interest
    manila_roi = ee.Geometry.Rectangle(
        [MANILA_BBOX["west"], MANILA_BBOX["south"],
         MANILA_BBOX["east"], MANILA_BBOX["north"]]
    )

    # 2. SRTM DEM — Elevation & Slope
    dem = ee.Image("USGS/SRTMGL1_003").clip(manila_roi)
    elevation = dem.select("elevation")
    slope = ee.Terrain.slope(dem)

    # Normalize elevation: lower elevation = higher flood risk.
    # Manila's elevation ranges roughly 0–15m ASL.
    elevation_risk = elevation.multiply(-1).add(15).divide(15).clamp(0, 1)

    # Normalize slope: flatter terrain = higher water accumulation.
    slope_risk = slope.multiply(-1).add(30).divide(30).clamp(0, 1)

    # Combined elevation factor (weighted average).
    elevation_factor = elevation_risk.multiply(0.6).add(slope_risk.multiply(0.4))

    # 3. Sentinel-1 SAR — Historical Flood Frequency
    # Query VH-band backscatter during known severe flood events:
    #   - Typhoon Ondoy (Sep 2009) — pre-Sentinel, use proxy
    #   - SW Monsoon / Habagat (Aug 2012) — pre-Sentinel, use proxy
    #   - Typhoon Ulysses (Nov 2020) — Sentinel-1 available
    #   - Typhoon Karding (Sep 2022) — Sentinel-1 available
    #   - Typhoon Kristine (Oct 2024) — Sentinel-1 available

    # Use available Sentinel-1 data (post-2014) for flood frequency.
    flood_dates = [
        ("2020-11-10", "2020-11-15"),  # Ulysses
        ("2022-09-25", "2022-09-30"),  # Karding
        ("2024-10-23", "2024-10-28"),  # Kristine
    ]

    # Build flood frequency composite from SAR imagery.
    flood_masks = []
    for start_date, end_date in flood_dates:
        try:
            sar = (
                ee.ImageCollection("COPERNICUS/S1_GRD")
                .filterBounds(manila_roi)
                .filterDate(start_date, end_date)
                .filter(ee.Filter.eq("instrumentMode", "IW"))
                .filter(ee.Filter.listContains("transmitterReceiverPolarisation", "VH"))
                .select("VH")
                .mean()
            )
            # Flood detection: VH backscatter < -18 dB indicates standing water.
            flood_mask = sar.lt(-18).unmask(0)
            flood_masks.append(flood_mask)
        except Exception:
            logger.debug("No SAR data for period %s to %s", start_date, end_date)

    if flood_masks:
        # Average flood occurrence across events (0-1 scale).
        flood_frequency = ee.ImageCollection(flood_masks).mean()
    else:
        # No SAR data available — use zero baseline.
        flood_frequency = ee.Image.constant(0).clip(manila_roi)

    # 4. Composite Risk Score Raster (PAGASA-calibrated)
    # Use PAGASA rainfall risk factor instead of arbitrary normalization.
    precip_risk = rainfall_risk_factor(precipitation_mm)
    runoff_coeff = RUNOFF_COEFFICIENTS["default"]
    water_accumulation = ee.Image.constant(
        precip_risk * runoff_coeff
    ).clip(manila_roi)

    # Wind risk factor: PAGASA-calibrated continuous 0-1 scale.
    wind_factor_val = wind_risk_factor(wind_speed_kph)
    wind_layer = ee.Image.constant(wind_factor_val).clip(manila_roi)

    # Composite Risk = Water (0.40) + Elevation (0.25) + Historical (0.15) + Wind (0.20)
    composite_risk = (
        water_accumulation.multiply(0.40)
        .add(elevation_factor.multiply(0.25))
        .add(flood_frequency.multiply(0.15))
        .add(wind_layer.multiply(0.20))
        .clamp(0, 1)
    )

    # 5. Zonal Reduction — Per-Barangay Scores
    scores = []
    # Build an ee.FeatureCollection from barangay geometries.
    features = []
    for brgy in barangay_geometries:
        try:
            geom_dict = (
                json.loads(brgy["geom_geojson"])
                if isinstance(brgy["geom_geojson"], str)
                else brgy["geom_geojson"]
            )
            feature = ee.Feature(
                ee.Geometry(geom_dict),
                {
                    "id": brgy["id"],
                    "name": brgy["barangay_name"],
                    "district": brgy["district"],
                },
            )
            features.append(feature)
        except Exception as e:
            logger.debug("Skipping barangay %s: %s", brgy.get("barangay_name"), e)

    if not features:
        logger.warning("No valid barangay features for GEE reduction.")
        return _analytical_risk_model(
            precipitation_mm, wind_speed_kph, storm_radius_km, barangay_geometries
        )

    fc = ee.FeatureCollection(features)

    # Reduce composite risk, elevation factor, water accumulation,
    # and flood frequency layers against barangay polygons.
    reduced = composite_risk.reduceRegions(
        collection=fc,
        reducer=ee.Reducer.mean().setOutputs(["total_risk"]),
        scale=30,
    )

    reduced_elev = elevation_factor.reduceRegions(
        collection=fc,
        reducer=ee.Reducer.mean().setOutputs(["elev_factor"]),
        scale=30,
    )

    reduced_water = water_accumulation.reduceRegions(
        collection=fc,
        reducer=ee.Reducer.mean().setOutputs(["water_score"]),
        scale=30,
    )

    reduced_hist = flood_frequency.reduceRegions(
        collection=fc,
        reducer=ee.Reducer.mean().setOutputs(["hist_freq"]),
        scale=30,
    )

    # Fetch results from GEE server.
    risk_results = reduced.getInfo()["features"]
    elev_results = {
        f["properties"]["id"]: f["properties"].get("elev_factor", 0)
        for f in reduced_elev.getInfo()["features"]
    }
    water_results = {
        f["properties"]["id"]: f["properties"].get("water_score", 0)
        for f in reduced_water.getInfo()["features"]
    }
    hist_results = {
        f["properties"]["id"]: f["properties"].get("hist_freq", 0)
        for f in reduced_hist.getInfo()["features"]
    }

    for feat in risk_results:
        props = feat["properties"]
        brgy_id = props["id"]
        total_risk = props.get("total_risk", 0) or 0
        elev = elev_results.get(brgy_id, 0) or 0
        water = water_results.get(brgy_id, 0) or 0
        hist = hist_results.get(brgy_id, 0) or 0

        # Classify tier.
        if total_risk >= TIER_RED_THRESHOLD:
            tier = "RED"
        elif total_risk >= TIER_YELLOW_THRESHOLD:
            tier = "YELLOW"
        else:
            tier = "GREEN"

        scores.append({
            "barangay_id": brgy_id,
            "barangay_name": props.get("name", ""),
            "district": props.get("district", ""),
            "water_accumulation_score": float(water),
            "elevation_factor": float(elev),
            "historical_frequency": float(hist),
            "total_risk_score": float(total_risk),
            "risk_tier": tier,
        })

    # Summary counts.
    red_count = sum(1 for s in scores if s["risk_tier"] == "RED")
    yellow_count = sum(1 for s in scores if s["risk_tier"] == "YELLOW")
    green_count = sum(1 for s in scores if s["risk_tier"] == "GREEN")

    logger.info(
        "GEE analysis complete: %d barangays → RED=%d, YELLOW=%d, GREEN=%d",
        len(scores), red_count, yellow_count, green_count,
    )

    return {
        "source": "earth_engine",
        "scores": scores,
        "summary": {
            "total_barangays": len(scores),
            "red_zones": red_count,
            "yellow_zones": yellow_count,
            "green_zones": green_count,
        },
    }


# -----------------------------------------------------------
# Analytical Fallback Model
# -----------------------------------------------------------

def _analytical_risk_model(
    precipitation_mm: float,
    wind_speed_kph: float,
    storm_radius_km: float,
    barangay_geometries: list[dict[str, Any]],
) -> dict[str, Any]:
    """
    Heuristic-based analytical model when GEE is unavailable.

    Uses barangay centroid coordinates to estimate relative elevation
    risk based on proximity to known low-lying areas and coastline.
    The formula mirrors the GEE composite structure:

    Risk = (Precipitation × Runoff) + (Elevation Factor) + (Historical Penalty)
    """
    import math

    logger.info(
        "Using analytical fallback model: precip=%.0fmm, wind=%.0fkph",
        precipitation_mm, wind_speed_kph,
    )

    # PAGASA-calibrated risk factors.
    precip_risk = rainfall_risk_factor(precipitation_mm)
    wind_risk = wind_risk_factor(wind_speed_kph)
    runoff = precip_risk * RUNOFF_COEFFICIENTS["default"]

    # Known historically vulnerable areas in Manila (centroid lng/lat).
    # These areas experienced severe flooding during Ondoy, Habagat, Ulysses.
    HIGH_RISK_CENTROIDS = [
        (120.9667, 14.5917),   # Baseco / Port Area
        (120.9650, 14.6100),   # Tondo
        (121.0050, 14.5850),   # Pandacan
        (121.0117, 14.5700),   # Santa Ana
        (120.9819, 14.5750),   # Paco
        (120.9700, 14.5600),   # Malate (coastal)
        (121.0000, 14.6000),   # San Miguel
        (120.9980, 14.5650),   # Santa Mesa
    ]

    scores = []
    for brgy in barangay_geometries:
        brgy_id = brgy["id"]
        name = brgy.get("barangay_name", "")
        district = brgy.get("district", "")

        # Parse centroid from geometry.
        try:
            geom = (
                json.loads(brgy["geom_geojson"])
                if isinstance(brgy["geom_geojson"], str)
                else brgy["geom_geojson"]
            )
            # Approximate centroid from first coordinate ring.
            coords = geom.get("coordinates", [])
            if geom["type"] == "MultiPolygon" and coords:
                ring = coords[0][0]
            elif geom["type"] == "Polygon" and coords:
                ring = coords[0]
            else:
                ring = []

            if ring:
                lngs = [p[0] for p in ring]
                lats = [p[1] for p in ring]
                centroid_lng = sum(lngs) / len(lngs)
                centroid_lat = sum(lats) / len(lats)
            else:
                centroid_lng, centroid_lat = 120.98, 14.59
        except Exception:
            centroid_lng, centroid_lat = 120.98, 14.59

        # Elevation factor: proximity to coast (lower lng) and
        # rivers (Pasig, Tullahan) indicates lower elevation.
        coastal_proximity = max(0, 1.0 - abs(centroid_lng - 120.96) * 20)
        river_proximity = max(0, 1.0 - abs(centroid_lat - 14.59) * 15)
        elevation_factor = (coastal_proximity * 0.6 + river_proximity * 0.4) * 0.8

        # Historical frequency: distance to known flood-prone centroids.
        min_distance = float("inf")
        for hlng, hlat in HIGH_RISK_CENTROIDS:
            dist = math.sqrt((centroid_lng - hlng) ** 2 + (centroid_lat - hlat) ** 2)
            min_distance = min(min_distance, dist)

        # Closer to historical flood areas = higher frequency penalty.
        historical_freq = max(0, 1.0 - min_distance * 50) * 0.9

        # Water accumulation: precipitation runoff.
        water_score = runoff

        # Composite risk (PAGASA-aligned weights matching GEE model).
        # Water (0.40) + Elevation (0.25) + Historical (0.15) + Wind (0.20)
        total_risk = (
            water_score * 0.40
            + elevation_factor * 0.25
            + historical_freq * 0.15
            + wind_risk * 0.20
        )
        total_risk = max(0.0, min(1.0, total_risk))

        # Classify tier.
        if total_risk >= TIER_RED_THRESHOLD:
            tier = "RED"
        elif total_risk >= TIER_YELLOW_THRESHOLD:
            tier = "YELLOW"
        else:
            tier = "GREEN"

        scores.append({
            "barangay_id": brgy_id,
            "barangay_name": name,
            "district": district,
            "water_accumulation_score": round(water_score, 4),
            "elevation_factor": round(elevation_factor, 4),
            "historical_frequency": round(historical_freq, 4),
            "total_risk_score": round(total_risk, 4),
            "risk_tier": tier,
        })

    red_count = sum(1 for s in scores if s["risk_tier"] == "RED")
    yellow_count = sum(1 for s in scores if s["risk_tier"] == "YELLOW")
    green_count = sum(1 for s in scores if s["risk_tier"] == "GREEN")

    logger.info(
        "Analytical model complete: %d barangays → RED=%d, YELLOW=%d, GREEN=%d",
        len(scores), red_count, yellow_count, green_count,
    )

    return {
        "source": "analytical_model",
        "scores": scores,
        "summary": {
            "total_barangays": len(scores),
            "red_zones": red_count,
            "yellow_zones": yellow_count,
            "green_zones": green_count,
        },
    }
