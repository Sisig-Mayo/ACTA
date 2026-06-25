-- ============================================================
-- ACTA Migration 001: Spatial Extensions & Core Tables
-- ============================================================
-- Target Branch: feature/spatial-db
-- Commit: feat(db): add 001 spatial extensions and barangay schemas
-- ============================================================
-- Prerequisites: Supabase PostgreSQL instance with superuser
-- access to enable extensions.
-- ============================================================

-- -----------------------------------------------------------
-- 1. Enable Required Extensions
-- -----------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS pgrouting;

-- -----------------------------------------------------------
-- 2. Barangay Boundaries Table
-- -----------------------------------------------------------
-- Stores the 505 Manila barangay multi-polygon geometries
-- ingested from the local manila.geojson spatial asset.
-- All geometries use EPSG:4326 (WGS 84) coordinate system.
-- -----------------------------------------------------------

CREATE TABLE IF NOT EXISTS barangays (
    id              SERIAL PRIMARY KEY,
    barangay_name   VARCHAR(100) NOT NULL,
    district        VARCHAR(50)  NOT NULL,
    geom            GEOMETRY(MultiPolygon, 4326) NOT NULL,

    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Spatial index for high-performance geometric queries
-- (containment, intersection, nearest-neighbor).
CREATE INDEX IF NOT EXISTS idx_barangays_geom
    ON barangays USING GIST (geom);

-- Composite index for fast name lookups within districts.
CREATE INDEX IF NOT EXISTS idx_barangays_district_name
    ON barangays (district, barangay_name);

COMMENT ON TABLE barangays IS
    'Manila barangay administrative boundaries (505 polygons, EPSG:4326).';

-- -----------------------------------------------------------
-- 3. Infrastructure Status Table
-- -----------------------------------------------------------
-- Tracks operational state of critical flood-response
-- infrastructure nodes (pumping stations, drainage gates).
-- -----------------------------------------------------------

CREATE TABLE IF NOT EXISTS infrastructure_status (
    id              SERIAL PRIMARY KEY,
    node_name       VARCHAR(100) NOT NULL,
    node_type       VARCHAR(50)  NOT NULL
                    CHECK (node_type IN ('pumping_station', 'drainage_gate')),
    is_operational  BOOLEAN DEFAULT TRUE,
    geom            GEOMETRY(Point, 4326) NOT NULL,

    last_inspected  TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_infra_geom
    ON infrastructure_status USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_infra_type_operational
    ON infrastructure_status (node_type, is_operational);

COMMENT ON TABLE infrastructure_status IS
    'Operational status of flood-response infrastructure nodes.';

-- -----------------------------------------------------------
-- 4. Row Level Security (RLS)
-- -----------------------------------------------------------
-- Enable RLS on all tables. Policies:
--   READ:  Open to authenticated users.
--   WRITE: Restricted to service_role (backend API key).
-- -----------------------------------------------------------

-- Barangays RLS
ALTER TABLE barangays ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read barangays"
    ON barangays FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Service role can insert barangays"
    ON barangays FOR INSERT
    TO service_role
    WITH CHECK (true);

CREATE POLICY "Service role can update barangays"
    ON barangays FOR UPDATE
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role can delete barangays"
    ON barangays FOR DELETE
    TO service_role
    USING (true);

-- Infrastructure Status RLS
ALTER TABLE infrastructure_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read infrastructure"
    ON infrastructure_status FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Service role can insert infrastructure"
    ON infrastructure_status FOR INSERT
    TO service_role
    WITH CHECK (true);

CREATE POLICY "Service role can update infrastructure"
    ON infrastructure_status FOR UPDATE
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role can delete infrastructure"
    ON infrastructure_status FOR DELETE
    TO service_role
    USING (true);

-- -----------------------------------------------------------
-- 5. Auto-update Timestamp Trigger
-- -----------------------------------------------------------

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_barangays_updated_at
    BEFORE UPDATE ON barangays
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_infrastructure_updated_at
    BEFORE UPDATE ON infrastructure_status
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
