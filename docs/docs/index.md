# ACTA

ACTA is a context-aware decision-to-action simulation engine for Manila disaster
preparedness operations. It combines weather inputs, spatial risk scoring,
PostGIS routing data, time-decayed task generation, and Gemini-assisted action
planning into an operator dashboard for LGU response teams.

## What Operators Use It For

ACTA turns a projected hazard scenario into a reviewable response package. An
operator can configure a flood simulation, monitor the run, inspect barangay
risk zones, review AI-assisted task recommendations, export a master action plan,
and dispatch the approved plan.

The current implementation is strongest around hydrologic flood preparedness.
Other hazard profiles are visible in the UI, but they should be treated as
future expansion points unless dedicated backend models are added.

The repository is a multi-part application:

- A Flutter dashboard in `lib/`.
- A FastAPI backend in `backend/`.
- Supabase PostgreSQL/PostGIS migrations and seed scripts in `database/`.
- A small ingestion pipeline in `data_pipeline/`.
- MkDocs source documentation in `docs/docs/`.

## Runtime Flow

1. An operator signs in through the Flutter dashboard.
2. The dashboard submits simulation inputs to the FastAPI API.
3. The backend creates a `simulation_runs` record and runs the simulation in the
   background.
4. The risk pipeline calculates per-barangay flood risk scores, applies route
   cost updates, generates time-sensitive tasks, and assembles LLM context.
5. Gemini produces a structured action plan when configured. A deterministic
   template fallback is used when Gemini is unavailable.
6. Results are stored in Supabase and returned to the dashboard for review,
   export, and dispatch.

## Main Components

| Component | Location | Purpose |
| --- | --- | --- |
| Flutter frontend | `lib/` | Operator login, simulation setup, command center, action plans, PDF/export UI. |
| FastAPI backend | `backend/` | Auth proxy, simulation orchestration, routing endpoints, PDF generation, dispatch. |
| Database schema | `database/migrations/` | Supabase PostgreSQL, PostGIS, pgRouting, simulation and LLM storage tables. |
| Seed scripts | `database/` | Import Manila barangay and road geometry data. |
| Data pipeline | `data_pipeline/` | Fetch and archive hazard telemetry into Supabase. |
| Documentation | `docs/docs/` | Maintained technical documentation. |

## Documentation Layout

- **Product** explains the feature set, operator workflow, current capability
  status, and recommended improvement targets.
- **Getting Started** explains installation and local runtime commands.
- **Development** documents architecture and workflow.
- **Reference** describes structure, configuration, APIs, data, and the LLM
  pipeline.
- **Operations** contains troubleshooting guidance for common local setup issues.

Keep these docs aligned with code changes that affect setup, APIs, data
contracts, environment variables, or operator-visible behavior.
