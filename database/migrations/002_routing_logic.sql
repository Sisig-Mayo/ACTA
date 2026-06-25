-- ============================================================
-- ACTA Migration 002: pgRouting Safe-Route Cost Modifier
-- ============================================================
-- Target Branch: feature/spatial-db
-- Commit: feat(db): add 002 pgrouting safe-route cost modifier function
-- ============================================================
-- Depends on: 001_extensions_and_tables.sql (postgis, pgrouting)
-- Assumes: A standard road network topology table `ways` exists
-- with columns: id, source, target, cost, reverse_cost, the_geom.
-- ============================================================

-- -----------------------------------------------------------
-- 1. Safe Route Calculation Function
-- -----------------------------------------------------------
-- Computes shortest path between two geographic coordinates
-- while assigning INFINITE cost to road segments that intersect
-- a provided flood zone geometry (simulated Red Zones with
-- flood depths exceeding 0.3m).
--
-- Parameters:
--   start_lng, start_lat : Origin point (WGS 84)
--   end_lng, end_lat     : Destination point (WGS 84)
--   flood_zone_geometry  : MultiPolygon/Polygon of active flood zones
--
-- Returns: Ordered sequence of route coordinates (path_seq, lng, lat).
-- -----------------------------------------------------------

CREATE OR REPLACE FUNCTION calculate_safe_route(
    start_lng           DOUBLE PRECISION,
    start_lat           DOUBLE PRECISION,
    end_lng             DOUBLE PRECISION,
    end_lat             DOUBLE PRECISION,
    flood_zone_geometry GEOMETRY
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
    -- -------------------------------------------------------
    -- Step 1: Resolve nearest road network vertices to the
    -- given start and end geographic coordinates.
    -- -------------------------------------------------------

    SELECT id INTO v_start_vertex
    FROM ways_vertices_pgr
    ORDER BY the_geom <-> ST_SetSRID(ST_MakePoint(start_lng, start_lat), 4326)
    LIMIT 1;

    SELECT id INTO v_end_vertex
    FROM ways_vertices_pgr
    ORDER BY the_geom <-> ST_SetSRID(ST_MakePoint(end_lng, end_lat), 4326)
    LIMIT 1;

    -- Guard: Ensure both vertices were resolved.
    IF v_start_vertex IS NULL OR v_end_vertex IS NULL THEN
        RAISE EXCEPTION 'Could not resolve start or end vertex from provided coordinates. '
                         'Ensure the road network topology (ways_vertices_pgr) is populated.';
    END IF;

    -- -------------------------------------------------------
    -- Step 2: Execute pgRouting Dijkstra with dynamic cost
    -- modification. Edges intersecting the flood zone receive
    -- an effectively infinite traversal cost (999999), forcing
    -- the algorithm to route around hazardous areas.
    -- -------------------------------------------------------

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
        -- Dynamic edge SQL with conditional flood-zone cost modifier
        FORMAT(
            'SELECT
                id,
                source,
                target,
                CASE
                    WHEN ST_Intersects(the_geom, %L::GEOMETRY)
                    THEN 999999.0   -- Infinite cost: flood zone intersection
                    ELSE cost       -- Normal traversal cost
                END AS cost,
                CASE
                    WHEN ST_Intersects(the_geom, %L::GEOMETRY)
                    THEN 999999.0
                    ELSE reverse_cost
                END AS reverse_cost
             FROM ways',
            ST_AsText(flood_zone_geometry),
            ST_AsText(flood_zone_geometry)
        ),
        v_start_vertex,
        v_end_vertex,
        directed := false
    ) AS r
    LEFT JOIN ways_vertices_pgr AS v ON r.node = v.id
    ORDER BY r.seq;
END;
$$;

COMMENT ON FUNCTION calculate_safe_route IS
    'Calculates an optimal safe route between two points, dynamically avoiding '
    'flood zone geometries by applying infinite traversal costs to intersecting '
    'road segments. Uses pgRouting Dijkstra shortest path algorithm.';

-- -----------------------------------------------------------
-- 2. Helper: Identify Barangays Within a Flood Zone
-- -----------------------------------------------------------
-- Returns barangays whose boundaries intersect or are contained
-- within a given flood geometry, along with coverage percentage.
-- -----------------------------------------------------------

CREATE OR REPLACE FUNCTION get_impacted_barangays(
    flood_geometry GEOMETRY
)
RETURNS TABLE (
    barangay_id     INTEGER,
    barangay_name   VARCHAR(100),
    district        VARCHAR(50),
    coverage_pct    DOUBLE PRECISION,
    centroid_lng    DOUBLE PRECISION,
    centroid_lat    DOUBLE PRECISION
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.id                                            AS barangay_id,
        b.barangay_name                                 AS barangay_name,
        b.district                                      AS district,
        ROUND(
            (ST_Area(ST_Intersection(b.geom, flood_geometry)) /
             NULLIF(ST_Area(b.geom), 0)) * 100, 2
        )::DOUBLE PRECISION                             AS coverage_pct,
        ST_X(ST_Centroid(b.geom))                       AS centroid_lng,
        ST_Y(ST_Centroid(b.geom))                       AS centroid_lat
    FROM barangays AS b
    WHERE ST_Intersects(b.geom, flood_geometry)
    ORDER BY coverage_pct DESC;
END;
$$;

COMMENT ON FUNCTION get_impacted_barangays IS
    'Identifies barangays intersecting a flood zone geometry and computes '
    'the percentage of each barangay area affected.';
