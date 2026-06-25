-- ACTA Migration 003: Meteorological Data
-- Creates the structured table for the data pipeline to push hazard events.
-- Target Branch: feature/data-pipeline

-- 1. Hazard Events Table
CREATE TABLE IF NOT EXISTS hazard_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    hazard_type VARCHAR(50) NOT NULL, -- e.g., 'TYPHOON', 'FLOOD', 'EARTHQUAKE'
    severity_label VARCHAR(50),
    wind_speed_kph NUMERIC,
    precipitation_24h_mm NUMERIC,
    raw_storage_url TEXT, -- Link to the raw JSON payload in Supabase Storage
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for time-series queries
CREATE INDEX IF NOT EXISTS idx_hazard_events_timestamp ON hazard_events(event_timestamp DESC);

-- 2. Row Level Security (RLS)
ALTER TABLE hazard_events ENABLE ROW LEVEL SECURITY;

-- Allow public read access (for the backend to consume)
CREATE POLICY "Allow public read on hazard_events"
    ON hazard_events FOR SELECT
    USING (true);

-- Allow insert ONLY from Service Role (Data Pipeline)
CREATE POLICY "Allow service role insert on hazard_events"
    ON hazard_events FOR INSERT
    WITH CHECK (auth.role() = 'service_role');
