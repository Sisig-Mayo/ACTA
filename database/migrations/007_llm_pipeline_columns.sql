-- ============================================================
-- ACTA Migration 007: LLM Pipeline Columns
-- ============================================================
-- Depends on: 004_simulation_risk_tables.sql
-- Adds two new columns to simulation_runs to store the
-- LLM context pipeline outputs:
--   llm_action_plan      — Full LLMActionPlanResponse (JSONB)
--   llm_context_snapshot — Structured context text sent to LLM (TEXT)
-- ============================================================

-- -----------------------------------------------------------
-- 1. Add LLM Pipeline Columns to simulation_runs
-- -----------------------------------------------------------

ALTER TABLE simulation_runs
    ADD COLUMN IF NOT EXISTS llm_action_plan       JSONB,
    ADD COLUMN IF NOT EXISTS llm_context_snapshot  TEXT;

COMMENT ON COLUMN simulation_runs.llm_action_plan IS
    'AI-generated action plan (LLMActionPlanResponse) produced by the '
    'Gemini LLM context pipeline. Contains action_plan_tasks, '
    'explainability_card, and risk_assessment. NULL if pipeline failed.';

COMMENT ON COLUMN simulation_runs.llm_context_snapshot IS
    'Raw structured context document assembled from basic parameters '
    'and simulation data, sent to the LLM for action plan generation. '
    'Stored for audit, reproducibility, and debugging purposes.';

-- -----------------------------------------------------------
-- 2. Index for quick LLM plan presence checks
-- -----------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_simulation_runs_llm_plan
    ON simulation_runs ((llm_action_plan IS NOT NULL));

-- -----------------------------------------------------------
-- Verification query (run manually to confirm)
-- -----------------------------------------------------------
-- SELECT
--     id,
--     status,
--     llm_action_plan IS NOT NULL AS has_llm_plan,
--     llm_context_snapshot IS NOT NULL AS has_context_snapshot
-- FROM simulation_runs
-- ORDER BY created_at DESC
-- LIMIT 5;
