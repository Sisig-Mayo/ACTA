"""
ACTA Backend — Barangays Router
=================================
Serves barangay GeoJSON data from the PostGIS database
for the Flutter frontend map rendering.
"""

from __future__ import annotations

import json
import logging

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import JSONResponse

from app.core.supabase_client import get_supabase_client

logger = logging.getLogger("acta.routes.barangays")

router = APIRouter()


@router.get(
    "/geojson",
    status_code=status.HTTP_200_OK,
    summary="Get Barangay GeoJSON",
    description="Returns all Manila barangays as a GeoJSON FeatureCollection with polygon geometries.",
)
async def get_barangays_geojson() -> JSONResponse:
    """
    Query the barangays table and return a GeoJSON FeatureCollection.
    Each feature includes barangay_name, district, and the polygon geometry.
    """
    client = get_supabase_client()
    if client is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database connection not configured.",
        )

    try:
        # Use RPC to call a PostGIS query that returns GeoJSON
        # We query through Supabase's PostgREST but need raw SQL for ST_AsGeoJSON
        # So we'll use an RPC function or direct query
        
        # First try: use Supabase client to get basic data, then build GeoJSON
        # We need the geometry as GeoJSON, so we'll use an RPC call
        res = client.rpc(
            "get_barangays_geojson",
            {}
        ).execute()

        if res.data:
            return JSONResponse(
                content=res.data,
                headers={"Cache-Control": "public, max-age=3600"},
            )
        
        # Fallback: return empty collection
        return JSONResponse(
            content={
                "type": "FeatureCollection",
                "features": [],
            }
        )

    except Exception as e:
        logger.error("Failed to fetch barangay GeoJSON: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch barangay data: {str(e)}",
        )
