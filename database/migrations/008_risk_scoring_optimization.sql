-- ============================================================
-- ACTA Migration 008: Risk Scoring Optimization
-- ============================================================
-- Depends on: 001_extensions_and_tables.sql, 004_simulation_risk_tables.sql
--
-- Adds:
--   1. Static exposure columns to barangays table
--   2. Materialized view for cached barangay exposure summaries
--   3. Risk model configuration table (tunable weights/thresholds)
--   4. Refresh function for the materialized view
--   5. Additional indexes for performance
-- ============================================================

-- -----------------------------------------------------------
-- 1. Add Static Exposure Columns to Barangays
-- -----------------------------------------------------------
-- These are properties that don't change between simulation
-- runs and should be precomputed once.

ALTER TABLE barangays
    ADD COLUMN IF NOT EXISTS coastal_distance_km   DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS mean_elevation_m       DOUBLE PRECISION;

COMMENT ON COLUMN barangays.coastal_distance_km IS
    'Approximate distance (km) from barangay centroid to nearest '
    'Manila Bay coastline point. Precomputed for storm surge calculations.';

COMMENT ON COLUMN barangays.mean_elevation_m IS
    'Approximate mean elevation (meters ASL) of the barangay. '
    'Populated from DEM data or manual survey.';

-- -----------------------------------------------------------
-- 2. Materialized View: Barangay Exposure Summary
-- -----------------------------------------------------------
-- Precomputes spatial properties that are expensive to calculate
-- on every simulation run. Refreshed only when barangay boundaries
-- or coastline data change (rarely).
--
-- This avoids repeated ST_Centroid, ST_AsGeoJSON, and distance
-- calculations during simulation scoring.

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_barangay_exposure_summary AS
SELECT
    b.id                                    AS barangay_id,
    b.barangay_name,
    b.district,
    b.population,

    -- Precomputed centroid
    ST_X(ST_Centroid(b.geom))               AS centroid_lng,
    ST_Y(ST_Centroid(b.geom))               AS centroid_lat,

    -- Coastal distance (km) — if not already stored, compute from centroid
    -- to Manila Bay reference longitude (120.96)
    COALESCE(
        b.coastal_distance_km,
        LEAST(
            ST_Distance(
                ST_Centroid(b.geom)::geography,
                ST_SetSRID(ST_MakePoint(120.9550, 14.6500), 4326)::geography
            ) / 1000.0,
            ST_Distance(
                ST_Centroid(b.geom)::geography,
                ST_SetSRID(ST_MakePoint(120.9600, 14.6000), 4326)::geography
            ) / 1000.0,
            ST_Distance(
                ST_Centroid(b.geom)::geography,
                ST_SetSRID(ST_MakePoint(120.9650, 14.5600), 4326)::geography
            ) / 1000.0
        )
    )                                       AS coastal_distance_km,

    -- Elevation (fallback: estimate from distance to coast)
    COALESCE(
        b.mean_elevation_m,
        -- Very rough proxy: coastal areas ~2m, inland ~8m
        2.0 + (
            LEAST(
                ST_Distance(
                    ST_Centroid(b.geom)::geography,
                    ST_SetSRID(ST_MakePoint(120.9600, 14.6000), 4326)::geography
                ) / 1000.0,
                10.0
            ) * 0.6
        )
    )                                       AS mean_elevation_m,

    -- Area in square meters (for density calculations)
    ST_Area(b.geom::geography)              AS area_sqm,

    -- Simplified GeoJSON (for API responses without full geometry)
    ST_AsGeoJSON(
        ST_SimplifyPreserveTopology(b.geom, 0.0005)
    )                                       AS geom_geojson_simplified

FROM barangays b
WHERE b.geom IS NOT NULL;

-- Unique index on the materialized view for CONCURRENTLY refresh.
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_brgy_exposure_id
    ON mv_barangay_exposure_summary (barangay_id);

CREATE INDEX IF NOT EXISTS idx_mv_brgy_exposure_district
    ON mv_barangay_exposure_summary (district);

COMMENT ON MATERIALIZED VIEW mv_barangay_exposure_summary IS
    'Cached barangay spatial properties (centroid, coastal distance, '
    'elevation, area). Refresh via refresh_barangay_exposure_summary(). '
    'Avoids repeated ST_Centroid/ST_Distance on every simulation run.';


-- -----------------------------------------------------------
-- 3. Risk Model Configuration Table
-- -----------------------------------------------------------
-- Stores tunable risk model parameters so they can be
-- adjusted via the admin UI without code deployments.

CREATE TABLE IF NOT EXISTS risk_model_config (
    id              SERIAL PRIMARY KEY,
    config_name     VARCHAR(100) NOT NULL UNIQUE DEFAULT 'default',
    is_active       BOOLEAN NOT NULL DEFAULT false,

    -- Component weights (must sum to 1.0)
    weight_rainfall     DOUBLE PRECISION NOT NULL DEFAULT 0.30,
    weight_wind         DOUBLE PRECISION NOT NULL DEFAULT 0.15,
    weight_elevation    DOUBLE PRECISION NOT NULL DEFAULT 0.20,
    weight_historical   DOUBLE PRECISION NOT NULL DEFAULT 0.10,
    weight_surge        DOUBLE PRECISION NOT NULL DEFAULT 0.15,
    weight_drainage     DOUBLE PRECISION NOT NULL DEFAULT 0.10,

    -- Tier thresholds
    tier_red            DOUBLE PRECISION NOT NULL DEFAULT 0.70,
    tier_yellow         DOUBLE PRECISION NOT NULL DEFAULT 0.40,

    -- Synergy boost parameters
    synergy_multiplier      DOUBLE PRECISION NOT NULL DEFAULT 0.30,
    synergy_rain_threshold  DOUBLE PRECISION NOT NULL DEFAULT 0.60,
    synergy_wind_threshold  DOUBLE PRECISION NOT NULL DEFAULT 0.60,

    -- Metadata
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),

    -- Constraint: weights must sum to 1.0 (within tolerance)
    CONSTRAINT chk_weights_sum CHECK (
        ABS(
            weight_rainfall + weight_wind + weight_elevation +
            weight_historical + weight_surge + weight_drainage - 1.0
        ) < 0.01
    )
);

-- Insert default configuration.
INSERT INTO risk_model_config (
    config_name, is_active, description
) VALUES (
    'default', true,
    'Default PAGASA-calibrated risk model. Weights: Rain 0.30, Wind 0.15, '
    'Elevation 0.20, Historical 0.10, Surge 0.15, Drainage 0.10. '
    'Tier thresholds: RED >= 0.70, YELLOW >= 0.40.'
) ON CONFLICT (config_name) DO NOTHING;

-- RLS for risk_model_config
ALTER TABLE risk_model_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can read risk_model_config" ON risk_model_config;
CREATE POLICY "Public can read risk_model_config"
    ON risk_model_config FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Service role can manage risk_model_config" ON risk_model_config;
CREATE POLICY "Service role can manage risk_model_config"
    ON risk_model_config FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

COMMENT ON TABLE risk_model_config IS
    'Tunable risk model parameters. Only one row should have '
    'is_active = true at a time. Modify via admin UI.';


-- -----------------------------------------------------------
-- 4. Refresh Function
-- -----------------------------------------------------------
-- Call this after updating barangay boundaries or coastline data.
-- Uses CONCURRENTLY to avoid locking the view during refresh.

CREATE OR REPLACE FUNCTION refresh_barangay_exposure_summary()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_barangay_exposure_summary;
END;
$$;

COMMENT ON FUNCTION refresh_barangay_exposure_summary IS
    'Refreshes the mv_barangay_exposure_summary materialized view '
    'using CONCURRENTLY mode (non-blocking). Call after barangay '
    'boundary updates.';


-- -----------------------------------------------------------
-- 5. Additional Performance Indexes
-- -----------------------------------------------------------

-- Composite index for fast risk score lookups per run
CREATE INDEX IF NOT EXISTS idx_risk_scores_run_total
    ON barangay_risk_scores (run_id, total_risk_score DESC);

-- Index for active config lookup
CREATE INDEX IF NOT EXISTS idx_risk_model_config_active
    ON risk_model_config (is_active) WHERE is_active = true;

-- Trigger for auto-update timestamp on risk_model_config
DROP TRIGGER IF EXISTS trg_risk_model_config_updated_at ON risk_model_config;
CREATE TRIGGER trg_risk_model_config_updated_at
    BEFORE UPDATE ON risk_model_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
