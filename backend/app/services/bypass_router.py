"""
ACTA Backend — Bypass Router Service
======================================
Interfaces with the PostGIS/pgRouting database to compute
flood-aware safe routes, bypassing hazardous zones using the
`calculate_safe_route()` database function.

Target Branch : feature/backend-decay
Commit        : feat(backend): implement async endpoints and proximity time decay service logic
"""

from __future__ import annotations

import logging
from typing import Any

import asyncpg

from app.core.config import settings

logger = logging.getLogger("acta.bypass_router")


# -----------------------------------------------------------
# Database Connection Pool
# -----------------------------------------------------------

_pool: asyncpg.Pool | None = None


async def _get_pool() -> asyncpg.Pool:
    """Lazily initialize and return the async connection pool."""
    global _pool
    if _pool is None:
        db_url = settings.SUPABASE_DATABASE_URL.replace(
            "postgresql+asyncpg://", "postgresql://"
        )
        _pool = await asyncpg.create_pool(
            dsn=db_url,
            min_size=2,
            max_size=10,
            command_timeout=30,
            statement_cache_size=0,
        )
        logger.info("Database connection pool initialized.")
    return _pool


async def close_pool() -> None:
    """Gracefully close the connection pool."""
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None
        logger.info("Database connection pool closed.")


# -----------------------------------------------------------
# Safe Route Calculation
# -----------------------------------------------------------

async def calculate_safe_route(
    start_lng: float,
    start_lat: float,
    end_lng: float,
    end_lat: float,
) -> list[dict[str, Any]]:
    """
    Compute a flood-aware safe route between two geographic points.

    Delegates to the PostGIS/pgRouting `calculate_safe_route()`
    database function, which assigns infinite traversal costs to
    road segments intersecting flood zones.

    Parameters
    ----------
    start_lng, start_lat : float
        Origin coordinates (WGS 84).
    Returns
    -------
    list[dict]
        Ordered list of route waypoints with sequence, coordinates, and cost.
    """
    pool = await _get_pool()

    query = """
        SELECT
            path_seq,
            node_id,
            edge_id,
            cost,
            agg_cost,
            longitude,
            latitude
        FROM calculate_safe_route(
            $1::DOUBLE PRECISION,
            $2::DOUBLE PRECISION,
            $3::DOUBLE PRECISION,
            $4::DOUBLE PRECISION
        )
        ORDER BY path_seq;
    """

    try:
        async with pool.acquire() as conn:
            rows = await conn.fetch(
                query, start_lng, start_lat, end_lng, end_lat
            )

        route = [
            {
                "path_seq": row["path_seq"],
                "node_id": row["node_id"],
                "edge_id": row["edge_id"],
                "cost": row["cost"],
                "agg_cost": row["agg_cost"],
                "longitude": row["longitude"],
                "latitude": row["latitude"],
            }
            for row in rows
        ]

        logger.info(
            "Safe route computed: %d waypoints, total cost: %.2f",
            len(route),
            route[-1]["agg_cost"] if route else 0,
        )
        return route

    except Exception as e:
        logger.error("Safe route calculation failed: %s", e)
        raise


# -----------------------------------------------------------
# Impacted Barangays Query
# -----------------------------------------------------------

async def get_impacted_barangays(
    flood_zone_wkt: str,
) -> list[dict[str, Any]]:
    """
    Query barangays impacted by a flood zone geometry.

    Parameters
    ----------
    flood_zone_wkt : str
        WKT representation of the flood zone.

    Returns
    -------
    list[dict]
        Barangays intersecting the flood zone with coverage percentages.
    """
    pool = await _get_pool()

    query = """
        SELECT
            barangay_id,
            barangay_name,
            district,
            coverage_pct,
            centroid_lng,
            centroid_lat
        FROM get_impacted_barangays(ST_GeomFromText($1, 4326))
        ORDER BY coverage_pct DESC;
    """

    try:
        async with pool.acquire() as conn:
            rows = await conn.fetch(query, flood_zone_wkt)

        barangays = [
            {
                "barangay_id": row["barangay_id"],
                "barangay_name": row["barangay_name"],
                "district": row["district"],
                "coverage_pct": float(row["coverage_pct"]),
                "centroid": [row["centroid_lng"], row["centroid_lat"]],
            }
            for row in rows
        ]

        logger.info("Found %d impacted barangays.", len(barangays))
        return barangays

    except Exception as e:
        logger.error("Impacted barangays query failed: %s", e)
        raise


# -----------------------------------------------------------
# Fetch All Barangay Boundaries (for map rendering)
# -----------------------------------------------------------

async def get_all_barangay_boundaries() -> list[dict[str, Any]]:
    """
    Retrieve all barangay boundaries as GeoJSON features
    for frontend map rendering.

    Returns
    -------
    list[dict]
        GeoJSON-compatible feature list with geometry and properties.
    """
    pool = await _get_pool()

    query = """
        SELECT
            id,
            barangay_name,
            district,
            ST_AsGeoJSON(geom)::json AS geometry
        FROM barangays
        ORDER BY district, barangay_name;
    """

    try:
        async with pool.acquire() as conn:
            rows = await conn.fetch(query)

        features = [
            {
                "type": "Feature",
                "properties": {
                    "id": row["id"],
                    "barangay_name": row["barangay_name"],
                    "district": row["district"],
                },
                "geometry": row["geometry"],
            }
            for row in rows
        ]

        logger.info("Retrieved %d barangay boundaries.", len(features))
        return features

    except Exception as e:
        logger.error("Barangay boundaries query failed: %s", e)
        raise
