-- ============================================================
-- ACTA Migration 006: Optimized pgRouting Safe-Route
-- ============================================================
-- Replaces calculate_safe_route to use the pre-computed dynamic
-- costs on the road_network table instead of executing inline
-- spatial intersections.
-- ============================================================

-- -----------------------------------------------------------
-- 1. Vertices Table (if missing)
-- -----------------------------------------------------------
-- pgRouting requires a vertices table to map geometric points
-- to node IDs. This table is typically populated by pgr_createTopology.
CREATE TABLE IF NOT EXISTS road_network_vertices_pgr (
    id BIGSERIAL PRIMARY KEY,
    cnt INTEGER,
    chk INTEGER,
    ein INTEGER,
    eout INTEGER,
    the_geom GEOMETRY(Point, 4326)
);

CREATE INDEX IF NOT EXISTS idx_road_network_vertices_pgr_the_geom
    ON road_network_vertices_pgr USING GIST(the_geom);

-- -----------------------------------------------------------
-- 2. Optimized calculate_safe_route
-- -----------------------------------------------------------
DROP FUNCTION IF EXISTS calculate_safe_route(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, GEOMETRY);

CREATE OR REPLACE FUNCTION calculate_safe_route(
    start_lng           DOUBLE PRECISION,
    start_lat           DOUBLE PRECISION,
    end_lng             DOUBLE PRECISION,
    end_lat             DOUBLE PRECISION
)
RETURNS TABLE (
    path_seq    INTEGER,
    node_id     BIGINT,
    edge_id     BIGINT,
    cost        DOUBLE PRECISION,
    agg_cost    DOUBLE PRECISION,
    longitude   DOUBLE PRECISION,
    latitude    DOUBLE PRECISION
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_start_vertex BIGINT;
    v_end_vertex   BIGINT;
BEGIN
    -- Resolve nearest road network vertices
    SELECT id INTO v_start_vertex
    FROM road_network_vertices_pgr
    ORDER BY the_geom <-> ST_SetSRID(ST_MakePoint(start_lng, start_lat), 4326)
    LIMIT 1;

    SELECT id INTO v_end_vertex
    FROM road_network_vertices_pgr
    ORDER BY the_geom <-> ST_SetSRID(ST_MakePoint(end_lng, end_lat), 4326)
    LIMIT 1;

    IF v_start_vertex IS NULL OR v_end_vertex IS NULL THEN
        RAISE EXCEPTION 'Could not resolve start or end vertex from coordinates. Ensure road_network_vertices_pgr is populated.';
    END IF;

    -- Execute pgRouting Dijkstra with O(E) plain index read
    -- since costs are pre-computed by apply_flood_cost_modifiers()
    RETURN QUERY
    SELECT
        r.seq::INTEGER          AS path_seq,
        r.node::BIGINT          AS node_id,
        r.edge::BIGINT          AS edge_id,
        r.cost                  AS cost,
        r.agg_cost              AS agg_cost,
        ST_X(v.the_geom)        AS longitude,
        ST_Y(v.the_geom)        AS latitude
    FROM pgr_dijkstra(
        'SELECT id, source, target, cost, reverse_cost FROM road_network',
        v_start_vertex,
        v_end_vertex,
        directed := false
    ) AS r
    LEFT JOIN road_network_vertices_pgr AS v ON r.node = v.id
    ORDER BY r.seq;
END;
$$;

COMMENT ON FUNCTION calculate_safe_route IS
    'Calculates an optimal safe route between two points using pre-computed dynamic road network costs. Drops O(ExV) ST_Intersects overhead.';
