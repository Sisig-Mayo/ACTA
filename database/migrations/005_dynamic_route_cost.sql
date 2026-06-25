-- ============================================================
-- ACTA Migration 005: Dynamic Route Cost Modifiers
-- ============================================================
-- Depends on: 004_simulation_risk_tables.sql
-- Provides SQL functions to dynamically modify road network
-- traversal costs based on simulation flood zone results,
-- making flooded roads impassable to pgRouting algorithms.
-- ============================================================

-- -----------------------------------------------------------
-- 1. Apply Flood Cost Modifiers
-- -----------------------------------------------------------
-- For a given simulation run, unions all RED-tier barangay
-- geometries into a flood zone and sets road segments
-- intersecting that zone to infinite cost (999999.0).
--
-- This is the core "Dynamic Route Weighting" mechanism:
-- pgRouting's Dijkstra will route AROUND flooded areas.
-- -----------------------------------------------------------

CREATE OR REPLACE FUNCTION apply_flood_cost_modifiers(
    p_run_id UUID
)
RETURNS TABLE (
    roads_modified  INT,
    red_barangays   INT,
    flood_area_sqm  DOUBLE PRECISION
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_flood_zone    GEOMETRY;
    v_red_count     INT;
    v_modified      INT;
    v_area          DOUBLE PRECISION;
BEGIN
    -- Step 1: Reset all road costs to base values first.
    UPDATE road_network
    SET cost = base_cost,
        reverse_cost = base_reverse_cost;

    -- Step 2: Build a unified flood zone geometry from all
    -- RED-tier barangays in this simulation run.
    SELECT
        ST_Union(b.geom),
        COUNT(*)
    INTO v_flood_zone, v_red_count
    FROM barangay_risk_scores AS rs
    JOIN barangays AS b ON rs.barangay_id = b.id
    WHERE rs.run_id = p_run_id
      AND rs.risk_tier = 'RED';

    -- Guard: No RED zones means no cost modification needed.
    IF v_flood_zone IS NULL OR v_red_count = 0 THEN
        RETURN QUERY SELECT 0::INT, 0::INT, 0.0::DOUBLE PRECISION;
        RETURN;
    END IF;

    -- Step 3: Set infinite traversal cost on all road segments
    -- intersecting the flood zone. Uses the GIST spatial index
    -- on road_network.geom for O(log n) intersection checks.
    UPDATE road_network
    SET cost = 999999.0,
        reverse_cost = 999999.0
    WHERE ST_Intersects(geom, v_flood_zone);

    GET DIAGNOSTICS v_modified = ROW_COUNT;

    -- Calculate approximate flood zone area.
    v_area := ST_Area(v_flood_zone::geography);

    RETURN QUERY SELECT v_modified, v_red_count, v_area;
END;
$$;

COMMENT ON FUNCTION apply_flood_cost_modifiers IS
    'Applies infinite traversal costs to road segments intersecting RED-tier '
    'barangay flood zones for a given simulation run. Returns count of '
    'modified roads, red barangays, and approximate flood area in sq meters.';

-- -----------------------------------------------------------
-- 2. Reset Road Costs
-- -----------------------------------------------------------
-- Restores all road segment costs to their original base
-- values. Call before applying new simulation results or
-- when clearing a simulation run.
-- -----------------------------------------------------------

CREATE OR REPLACE FUNCTION reset_road_costs()
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    UPDATE road_network
    SET cost = base_cost,
        reverse_cost = base_reverse_cost
    WHERE cost != base_cost
       OR reverse_cost != base_reverse_cost;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

COMMENT ON FUNCTION reset_road_costs IS
    'Resets all road network costs to their original base values. '
    'Returns the number of roads that were restored.';

-- -----------------------------------------------------------
-- 3. Get Flood Zone Geometry for a Simulation Run
-- -----------------------------------------------------------
-- Convenience function that returns the unified flood zone
-- MultiPolygon for a given run_id. Used by the safe-route
-- endpoint to pass flood geometry to calculate_safe_route().
-- -----------------------------------------------------------

CREATE OR REPLACE FUNCTION get_flood_zone_for_run(
    p_run_id UUID
)
RETURNS GEOMETRY
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_flood_zone GEOMETRY;
BEGIN
    SELECT ST_Union(b.geom)
    INTO v_flood_zone
    FROM barangay_risk_scores AS rs
    JOIN barangays AS b ON rs.barangay_id = b.id
    WHERE rs.run_id = p_run_id
      AND rs.risk_tier = 'RED';

    RETURN COALESCE(v_flood_zone, ST_GeomFromText('GEOMETRYCOLLECTION EMPTY', 4326));
END;
$$;

COMMENT ON FUNCTION get_flood_zone_for_run IS
    'Returns the unified RED-tier barangay flood zone geometry for a simulation run. '
    'Used as input to the safe-route calculation function.';
