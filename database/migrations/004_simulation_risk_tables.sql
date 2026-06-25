-- ============================================================
-- ACTA Migration 004: Simulation Risk Tables & Road Network
-- ============================================================
-- Depends on: 001_extensions_and_tables.sql
-- Creates tables for the simulation lifecycle, per-barangay
-- risk scores, and the standardized road network for pgRouting.
-- ============================================================

-- -----------------------------------------------------------
-- 1. Simulation Runs Table
-- -----------------------------------------------------------
-- Tracks each simulation execution with input parameters
-- and lifecycle status for async background processing.
-- -----------------------------------------------------------

CREATE TABLE IF NOT EXISTS simulation_runs (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ DEFAULT NOW(),

    -- Input parameters snapshot
    typhoon_parameters          JSONB NOT NULL,
    preparation_window_hours    INT NOT NULL CHECK (preparation_window_hours >= 0),

    -- Lifecycle tracking
    status                      VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                                CHECK (status IN (
                                    'PENDING', 'PROCESSING', 'COMPLETED',
                                    'FAILED', 'CANCELLED'
                                )),
    progress_pct                SMALLINT DEFAULT 0 CHECK (progress_pct BETWEEN 0 AND 100),
    error_message               TEXT,

    -- Cached output summaries
    severity_tier               VARCHAR(20),
    total_red_zones             INT DEFAULT 0,
    total_yellow_zones          INT DEFAULT 0,
    total_green_zones           INT DEFAULT 0,

    -- Explainability card (Gemini output)
    explainability_card         JSONB,

    -- Time-decayed task list
    task_list                   JSONB
);

CREATE INDEX IF NOT EXISTS idx_simulation_runs_status
    ON simulation_runs (status);

CREATE INDEX IF NOT EXISTS idx_simulation_runs_created
    ON simulation_runs (created_at DESC);

COMMENT ON TABLE simulation_runs IS
    'Tracks simulation execution lifecycle with typhoon input parameters and status.';

-- -----------------------------------------------------------
-- 2. Barangay Risk Scores Table
-- -----------------------------------------------------------
-- Stores per-barangay computed risk scores for each
-- simulation run. Composite unique index enables upsert
-- optimization for batch re-processing.
-- -----------------------------------------------------------

CREATE TABLE IF NOT EXISTS barangay_risk_scores (
    id                          SERIAL PRIMARY KEY,
    run_id                      UUID NOT NULL
                                REFERENCES simulation_runs(id) ON DELETE CASCADE,
    barangay_id                 INT NOT NULL
                                REFERENCES barangays(id) ON DELETE CASCADE,

    -- Individual risk components
    water_accumulation_score    FLOAT NOT NULL DEFAULT 0.0,
    elevation_factor            FLOAT NOT NULL DEFAULT 0.0,
    historical_frequency        FLOAT NOT NULL DEFAULT 0.0,

    -- Aggregated result
    total_risk_score            FLOAT NOT NULL DEFAULT 0.0,
    risk_tier                   VARCHAR(6) NOT NULL DEFAULT 'GREEN'
                                CHECK (risk_tier IN ('RED', 'YELLOW', 'GREEN')),

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Composite unique index for upsert optimization:
-- Prevents duplicate scores per barangay per run and enables
-- ON CONFLICT (run_id, barangay_id) DO UPDATE.
CREATE UNIQUE INDEX IF NOT EXISTS idx_risk_scores_run_barangay
    ON barangay_risk_scores (run_id, barangay_id);

-- Lookup by run
CREATE INDEX IF NOT EXISTS idx_risk_scores_run_id
    ON barangay_risk_scores (run_id);

-- Tier-based filtering (e.g., "show all RED zones for run X")
CREATE INDEX IF NOT EXISTS idx_risk_scores_tier
    ON barangay_risk_scores (run_id, risk_tier);

COMMENT ON TABLE barangay_risk_scores IS
    'Per-barangay flood risk scores computed during each simulation run.';

-- -----------------------------------------------------------
-- 3. Road Network Table (pgRouting)
-- -----------------------------------------------------------
-- Standardized edge table for pgRouting's Dijkstra/A*
-- algorithms. Populated from OSM or custom road datasets.
-- base_cost preserves original weights for reset after
-- flood zone cost modification.
-- -----------------------------------------------------------

CREATE TABLE IF NOT EXISTS road_network (
    id              SERIAL PRIMARY KEY,
    source          INT NOT NULL,
    target          INT NOT NULL,
    cost            DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    reverse_cost    DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    base_cost       DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    base_reverse_cost DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    geom            GEOMETRY(LineString, 4326) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_road_network_geom
    ON road_network USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_road_network_source
    ON road_network (source);

CREATE INDEX IF NOT EXISTS idx_road_network_target
    ON road_network (target);

COMMENT ON TABLE road_network IS
    'Road network edge table for pgRouting with base and dynamic flood-modified costs.';

-- -----------------------------------------------------------
-- 4. Auto-update Timestamp Trigger
-- -----------------------------------------------------------

CREATE TRIGGER IF NOT EXISTS trg_simulation_runs_updated_at
    BEFORE UPDATE ON simulation_runs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- -----------------------------------------------------------
-- 5. Row Level Security (RLS)
-- -----------------------------------------------------------

-- Simulation Runs: public read, service_role write
ALTER TABLE simulation_runs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read simulation_runs"
    ON simulation_runs FOR SELECT
    USING (true);

CREATE POLICY "Service role can insert simulation_runs"
    ON simulation_runs FOR INSERT
    TO service_role
    WITH CHECK (true);

CREATE POLICY "Service role can update simulation_runs"
    ON simulation_runs FOR UPDATE
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role can delete simulation_runs"
    ON simulation_runs FOR DELETE
    TO service_role
    USING (true);

-- Barangay Risk Scores: public read, service_role write
ALTER TABLE barangay_risk_scores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read barangay_risk_scores"
    ON barangay_risk_scores FOR SELECT
    USING (true);

CREATE POLICY "Service role can insert barangay_risk_scores"
    ON barangay_risk_scores FOR INSERT
    TO service_role
    WITH CHECK (true);

CREATE POLICY "Service role can update barangay_risk_scores"
    ON barangay_risk_scores FOR UPDATE
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role can delete barangay_risk_scores"
    ON barangay_risk_scores FOR DELETE
    TO service_role
    USING (true);

-- Road Network: public read, service_role write
ALTER TABLE road_network ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read road_network"
    ON road_network FOR SELECT
    USING (true);

CREATE POLICY "Service role can insert road_network"
    ON road_network FOR INSERT
    TO service_role
    WITH CHECK (true);

CREATE POLICY "Service role can update road_network"
    ON road_network FOR UPDATE
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role can delete road_network"
    ON road_network FOR DELETE
    TO service_role
    USING (true);
