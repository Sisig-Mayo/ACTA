"""
ACTA Backend — Google Earth Engine (GEE) Service
==================================================
Handles initialization and interaction with the Google Earth Engine API
to dynamically render projected hazard boundaries across Manila's barangays.

Target Branch : feature/backend-decay
Commit        : feat(backend): integrate google earth engine for boundary rendering
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

from app.core.config import settings

logger = logging.getLogger("acta.gee_engine")

# Lazy initialization flag
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

    # For the MVP, we expect a service account JSON file.
    key_file = settings.GEE_SERVICE_ACCOUNT_FILE
    if not key_file:
        logger.warning("GEE_SERVICE_ACCOUNT_FILE not set. GEE integration disabled.")
        return

    key_path = Path(key_file)
    if not key_path.is_absolute():
        # Resolve relative to project root
        key_path = Path(__file__).resolve().parent.parent.parent.parent / key_path

    if not key_path.exists():
        logger.warning("GEE key file not found at %s. GEE integration disabled.", key_path)
        return

    try:
        # Authenticate using the service account
        credentials = ee.ServiceAccountCredentials('', str(key_path))
        ee.Initialize(credentials)
        _is_initialized = True
        logger.info("Google Earth Engine initialized successfully.")
    except Exception as e:
        logger.error("Failed to initialize Google Earth Engine: %s", e)


async def simulate_hazard_boundaries(
    wind_speed_kph: float,
    precipitation_24h_mm: float,
    storm_track_points: list[list[float]],
) -> dict[str, Any]:
    """
    Dynamically render projected hazard boundaries.

    In a full production scenario, this function translates the meteorological
    parameters into GEE filters (e.g., retrieving Sentinel-1 SAR imagery
    for flood mapping or running a custom Hydrologic Model).
    
    For this MVP architecture, it simulates the GEE interaction and returns
    a representative geo-spatial coverage mapping.

    Returns
    -------
    dict
        A mapping of simulated flood boundary geometries or Map IDs
        that the frontend can render over the Google Maps interface.
    """
    _initialize_gee()

    if not _is_initialized:
        logger.info("Using fallback mock data for GEE hazard boundaries.")
        return _mock_hazard_boundaries(wind_speed_kph, precipitation_24h_mm)

    try:
        import ee

        # ---------------------------------------------------------
        # Example GEE Implementation Logic (Hydrologic Flood Proxy)
        # ---------------------------------------------------------
        # 1. Define Manila Region of Interest
        manila_roi = ee.Geometry.Polygon([
            [[120.94, 14.54], [120.94, 14.64], [121.02, 14.64], [121.02, 14.54]]
        ])

        # 2. In a real scenario, you'd pull a DEM and use the precipitation 
        #    parameter to calculate a water accumulation mask, or pull 
        #    Sentinel-1 data. Here, we create a simplified proxy layer.
        
        # Example: Elevation-based flood proxy
        dem = ee.Image('MERIT/DEM/v1_0_3').clip(manila_roi)
        
        # Determine rough elevation threshold based on rain intensity
        threshold = 3.0 if precipitation_24h_mm > 300 else 1.5
        flood_mask = dem.lt(threshold)

        # 3. Get Map ID for the frontend to render tiles directly
        map_id_dict = flood_mask.updateMask(flood_mask).getMapId({
            'min': 0, 'max': 1, 'palette': ['red']
        })

        return {
            "source": "earth_engine",
            "tile_url": map_id_dict['tile_fetcher'].url_format,
            "threshold_applied": threshold
        }

    except Exception as e:
        logger.error("GEE boundary simulation failed: %s", e)
        return _mock_hazard_boundaries(wind_speed_kph, precipitation_24h_mm)


def _mock_hazard_boundaries(wind: float, rain: float) -> dict[str, Any]:
    """Fallback generator for hazard boundaries when GEE is not available."""
    # This would typically return GeoJSON MultiPolygons covering
    # low-elevation Manila areas. For now, it returns dummy metrics.
    return {
        "source": "mock_fallback",
        "mock_severity": "High" if rain > 200 else "Moderate",
        "tile_url": None,
        "message": "GEE authentication required for live raster tiles."
    }
