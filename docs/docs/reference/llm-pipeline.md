# LLM Pipeline

The LLM pipeline turns operator inputs and computed simulation data into a
structured context document for Gemini. The output is stored with the simulation
run and returned to the frontend as part of the action-plan experience.

## Source Files

| File | Purpose |
| --- | --- |
| `backend/app/models/llm_models.py` | Pydantic models for context sections and LLM responses. |
| `backend/app/services/llm_pipeline.py` | Assembles the context document. |
| `backend/app/core/gemini.py` | Gemini client, system instruction, response schema, fallback response. |
| `backend/app/services/risk_pipeline.py` | Calls the LLM stage as part of the full simulation pipeline. |
| `backend/app/routes/simulation.py` | Exposes `/llm-context/{run_id}` for audit/debug. |

## Context Sections

The context document contains five sections:

| Section | Content |
| --- | --- |
| Basic parameters | Wind speed, precipitation, preparation window, storm track, storm radius. |
| Simulation results | Severity tier, zone counts, top-risk barangays, red-zone list. |
| Infrastructure status | Pumping stations and drainage gates when available. |
| Template action tasks | Time-decayed baseline tasks generated before LLM refinement. |
| Pipeline metadata | Run ID, timestamps, and pipeline version metadata. |

## Output Shape

Gemini is expected to return:

- `action_plan_tasks`: prioritized tasks with deadline, category, responsible
  unit, and rationale.
- `explainability_card`: summary, risk narrative, action rationale, and
  confidence note.
- `risk_assessment`: threat level, primary risks, geographic focus, and
  time-critical factors.

The result is stored in `simulation_runs.llm_action_plan`.

## Fallback Behavior

Gemini is optional. If `GEMINI_API_KEY` is empty or the Gemini call fails, the
backend converts decay-engine tasks into a structured fallback response. This
keeps the simulation path usable without AI output.

The `generated_by` field in the stored LLM action plan indicates whether output
came from Gemini or the fallback template path.

## Audit Endpoint

After a run is complete:

```text
GET /api/v1/simulation/llm-context/{run_id}
```

The response includes:

- Whether the LLM pipeline executed.
- The generator identifier.
- Total AI tasks.
- The stored LLM action plan.
- The exact context snapshot text.
- Summary counts from the simulation.

Use this endpoint when reviewing prompt grounding, debugging unexpected action
plans, or building audit reports.
