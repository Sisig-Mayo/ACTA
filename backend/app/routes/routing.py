"""
ACTA Backend — Routing Endpoints
===================================
Asynchronous FastAPI router for geographic routing operations,
including safe-route computation and barangay boundary retrieval.

Target Branch : feature/backend-decay
Commit        : feat(backend): implement async endpoints and proximity time decay service logic
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel, Field

from app.services.bypass_router import (
    calculate_safe_route,
    get_all_barangay_boundaries,
    get_impacted_barangays,
)

logger = logging.getLogger("acta.routes.routing")

router = APIRouter()


# -----------------------------------------------------------
# Request/Response Models
# -----------------------------------------------------------

class SafeRouteRequest(BaseModel):
    """Request payload for safe route calculation."""

    start_lng: float = Field(..., ge=-180, le=180, description="Origin longitude.")
    start_lat: float = Field(..., ge=-90, le=90, description="Origin latitude.")
    end_lng: float = Field(..., ge=-180, le=180, description="Destination longitude.")
    end_lat: float = Field(..., ge=-90, le=90, description="Destination latitude.")
    flood_zone_wkt: str = Field(
        ...,
        description="WKT geometry string representing active flood zones.",
        examples=["POLYGON((120.95 14.55, 120.98 14.55, 120.98 14.58, 120.95 14.58, 120.95 14.55))"],
    )


class RouteWaypoint(BaseModel):
    """A single waypoint in the computed route."""

    path_seq: int
    node_id: int
    edge_id: int
    cost: float
    agg_cost: float
    longitude: float
    latitude: float


class SafeRouteResponse(BaseModel):
    """Response containing the computed safe route."""

    waypoints: list[RouteWaypoint]
    total_cost: float
    waypoint_count: int


# -----------------------------------------------------------
# POST /api/v1/routing/safe-route
# -----------------------------------------------------------

@router.post(
    "/safe-route",
    response_model=SafeRouteResponse,
    status_code=status.HTTP_200_OK,
    summary="Compute Flood-Aware Safe Route",
    description=(
        "Calculate an optimal route between two points that avoids "
        "flood zones by assigning infinite traversal costs to "
        "intersecting road segments."
    ),
)
async def compute_safe_route(payload: SafeRouteRequest) -> SafeRouteResponse:
    """Compute a flood-aware safe route using pgRouting."""
    logger.info(
        "Safe route requested: (%.4f, %.4f) → (%.4f, %.4f)",
        payload.start_lng, payload.start_lat,
        payload.end_lng, payload.end_lat,
    )

    try:
        waypoints = await calculate_safe_route(
            start_lng=payload.start_lng,
            start_lat=payload.start_lat,
            end_lng=payload.end_lng,
            end_lat=payload.end_lat,
            flood_zone_wkt=payload.flood_zone_wkt,
        )

        total_cost = waypoints[-1]["agg_cost"] if waypoints else 0

        return SafeRouteResponse(
            waypoints=[RouteWaypoint(**wp) for wp in waypoints],
            total_cost=total_cost,
            waypoint_count=len(waypoints),
        )

    except Exception as e:
        logger.error("Safe route computation failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Routing engine error: {str(e)}",
        )


# -----------------------------------------------------------
# GET /api/v1/routing/barangays
# -----------------------------------------------------------

@router.get(
    "/barangays",
    status_code=status.HTTP_200_OK,
    summary="Retrieve All Barangay Boundaries",
    description=(
        "Fetch all 505 Manila barangay boundaries as GeoJSON features "
        "for frontend map rendering."
    ),
)
async def get_barangays() -> dict[str, Any]:
    """Return all barangay boundaries as a GeoJSON FeatureCollection."""
    try:
        features = await get_all_barangay_boundaries()

        return {
            "type": "FeatureCollection",
            "features": features,
            "metadata": {
                "total_barangays": len(features),
                "crs": "EPSG:4326",
            },
        }

    except Exception as e:
        logger.error("Barangay boundaries retrieval failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database query error: {str(e)}",
        )


# -----------------------------------------------------------
# POST /api/v1/routing/impacted
# -----------------------------------------------------------

class ImpactQueryRequest(BaseModel):
    """Request to identify barangays impacted by a flood zone."""

    flood_zone_wkt: str = Field(
        ...,
        description="WKT geometry of the flood zone.",
    )


@router.post(
    "/impacted",
    status_code=status.HTTP_200_OK,
    summary="Identify Impacted Barangays",
    description=(
        "Query barangays intersecting a flood zone geometry and "
        "return coverage percentages for each."
    ),
)
async def find_impacted_barangays(payload: ImpactQueryRequest) -> dict[str, Any]:
    """Find barangays impacted by a given flood zone."""
    try:
        barangays = await get_impacted_barangays(payload.flood_zone_wkt)

        return {
            "impacted_barangays": barangays,
            "total_impacted": len(barangays),
        }

    except Exception as e:
        logger.error("Impact query failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Impact analysis error: {str(e)}",
        )
