# ACTA — Context-Aware Decision-to-Action Simulation Engine

> An AI-powered disaster preparedness simulation platform generating time-decayed, spatially-aware action plans for Manila LGU operators.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      ACTA Monorepo                          │
├──────────────┬──────────────────┬────────────────────────────┤
│  database/   │    backend/      │   frontend/ (lib/)         │
│  PostgreSQL  │    FastAPI       │   Flutter Web/Mobile       │
│  PostGIS     │    Python 3.11+  │   Riverpod + FlutterMap    │
│  pgRouting   │    Gemini AI     │   Responsive Dashboard     │
└──────────────┴──────────────────┴────────────────────────────┘
```

---

## What ACTA Does

ACTA supports a Manila LGU flood preparedness workflow:

- Monitor operational context in a Command Center with barangay risk maps,
  alerts, priority areas, and resource summaries.
- Configure hydrologic flood simulations with wind, rainfall, preparation
  window, storm track, and storm radius inputs.
- Run simulations asynchronously through FastAPI and store status/results in
  Supabase.
- Score barangays into green, yellow, and red risk zones.
- Generate time-decayed response tasks based on the remaining preparation
  window.
- Produce Gemini-assisted action plans with explainability cards and an
  auditable LLM context snapshot, with deterministic fallback output when Gemini
  is unavailable.
- Review, approve, export, and dispatch a Master Action Plan PDF.
- Query flood-aware routing and barangay boundaries through backend APIs.

Current improvement targets are documented in
`docs/docs/product/features.md`. The main gaps are live resource inventory,
accurate result centroids, fuller routing UI integration, dispatch audit history,
and either implementing or hiding non-flood hazard profiles until they have
dedicated backend models.

---

## LLM Pipeline Architecture

The LLM pipeline assembles all available basic parameters and simulation data into a structured context document, which is fed to Gemini AI with a domain-specific system prompt to produce a fully context-aware disaster response action plan.

```mermaid
flowchart TD
    A([LGU Operator\nDashboard]) -->|SimulationInput\nwind · rain · prep_window\nstorm_track · radius| B

    subgraph PIPELINE ["⚙️  Background Simulation Pipeline  (risk_pipeline.py)"]
        direction TB

        B["① GEE Risk Engine\ngee_engine.py\nCalculate per-barangay\nflood risk scores"] -->|905 risk scores\nRED · YELLOW · GREEN| C

        C["② Bulk DB Insert\nsupabase_client.py\nPersist barangay_risk_scores\n+ apply flood cost modifiers"] --> D

        D["③ Time-Decay Engine\ndecay_engine.py\nGenerate template tasks\nbased on prep_window"] -->|Sorted task list| E

        E["④ Legacy Explainability\ngemini.py\ngenerate_explainability_card\nTemplate fallback narrative"] --> F

        subgraph LLM_PIPELINE ["🤖  LLM Context Pipeline  (llm_pipeline.py)"]
            direction TB

            F["⑤ Context Assembly\nassemble_llm_context()"] 

            F --> S1["📋 Section 1\nBasic Parameters\nwind · rain · prep_window\nstorm_track · radius"]
            F --> S2["📊 Section 2\nSimulation Results\nseverity_tier · zone counts\nTop-15 risk barangays\n+ per-score breakdowns"]
            F --> S3["🏗️ Section 3\nInfrastructure Status\npumping stations\ndrainage gates\noperational / offline"]
            F --> S4["📝 Section 4\nTemplate Tasks\ndecay-engine baselines\nfor LLM refinement"]
            F --> S5["🔖 Section 5\nPipeline Metadata\nrun_id · timestamp\npipeline_version"]

            S1 & S2 & S3 & S4 & S5 --> CTX["LLMContext\n.to_context_document()\n5-section structured text"]
        end

        CTX -->|Full context document| G
    end

    subgraph GEMINI ["✨  Gemini 2.5 Flash  (gemini.py)"]
        direction TB
        SP["🧠 System Instruction\nACTA domain grounding\nManila geography\nLGU protocols\nPAGASA/NDRRMC context"] 
        G["generate_action_plan_with_context()"]
        SP --> G
        G -->|Structured JSON\nresponse_schema| H["LLMActionPlanResponse\n─────────────────────\naction_plan_tasks[]\n  priority · action\n  deadline_hours\n  responsible_unit\n  rationale\n─────────────────────\nexplainability_card\n  summary\n  risk_narrative\n  action_rationale\n  confidence_note\n─────────────────────\nrisk_assessment\n  overall_threat_level\n  primary_risks[]\n  geographic_focus\n  time_critical_factors"]
    end

    H -->|llm_action_plan JSONB\nllm_context_snapshot TEXT| I[("🗄️ Supabase PostgreSQL\nsimulation_runs table\nstatus: COMPLETED")]

    I --> J["🔌 REST API\nGET /simulation/results\nGET /simulation/llm-context\n+ audit snapshot"]

    J --> K([Flutter Dashboard\nAI Action Plan Screen\nExplainability Cards\nTask Timeline])

    subgraph FALLBACK ["🔄  Fallback  (always available)"]
        FB["_fallback_action_plan()\nConverts decay-engine tasks\nto LLMActionPlanResponse\ngenerated_by: fallback-template"]
    end

    G -.->|"Gemini unavailable\nor API error"| FB
    FB -.->|Fallback plan| H

    style PIPELINE fill:#1a1d23,stroke:#3a3f4b,color:#e0e0e0
    style LLM_PIPELINE fill:#0d1117,stroke:#00bfa6,stroke-width:2px,color:#e0e0e0
    style GEMINI fill:#1a1d23,stroke:#7c4dff,stroke-width:2px,color:#e0e0e0
    style FALLBACK fill:#1a1d23,stroke:#ff7043,stroke-dasharray:5 5,color:#e0e0e0
    style A fill:#26c6da,stroke:#00acc1,color:#000
    style K fill:#26c6da,stroke:#00acc1,color:#000
    style I fill:#2a2e36,stroke:#00bfa6,color:#e0e0e0
    style H fill:#2a2e36,stroke:#7c4dff,color:#e0e0e0
    style CTX fill:#2a2e36,stroke:#00bfa6,color:#e0e0e0
    style FB fill:#2a2e36,stroke:#ff7043,color:#e0e0e0
```

### Context Sections Fed to Gemini

| # | Section | Source | Key Data |
|---|---------|--------|---------|
| 1 | **Basic Parameters** | `SimulationInput` | wind speed, precipitation, prep window, storm track |
| 2 | **Simulation Results** | GEE engine | severity tier, zone counts, top-15 risk barangays with score breakdowns |
| 3 | **Infrastructure Status** | `infrastructure_status` table | pumping stations & drainage gates, operational/offline state |
| 4 | **Template Tasks** | `decay_engine.py` | time-decayed baseline tasks for LLM refinement |
| 5 | **Metadata** | Pipeline | run ID, pipeline version, timestamps |

### Key Files

| File | Role |
|------|------|
| `backend/app/models/llm_models.py` | `LLMContext`, `LLMActionPlanResponse` Pydantic schemas |
| `backend/app/core/gemini.py` | System instruction + `generate_action_plan_with_context()` |
| `backend/app/services/llm_pipeline.py` | 5-stage context assembly orchestrator |
| `backend/app/services/risk_pipeline.py` | Integrates LLM stage into simulation background task |
| `backend/app/routes/simulation.py` | `GET /api/v1/simulation/llm-context/{run_id}` audit endpoint |
| `database/migrations/007_llm_pipeline_columns.sql` | Adds `llm_action_plan` + `llm_context_snapshot` columns |



## Branch Strategy

| Branch | Purpose | Owner |
|---|---|---|
| `main` | Production-stable release state | Release Engineer |
| `develop` | Integration branch for daily development | All |
| `feature/spatial-db` | PostGIS extensions, migrations, GeoJSON parsing | DB Engineer |
| `feature/backend-decay` | FastAPI routing, time-decay planning service | Backend Engineer |
| `feature/frontend-dashboard` | Flutter UI, state adapters, mapping canvases | Frontend Engineer |

### Workflow

```
feature/* ──► develop ──► main
              (PR + review)  (tagged release)
```

## Commit Conventions

All commits **must** follow Conventional Commits (`type(scope): message`):

```
feat(db): add 001 spatial extensions and barangay schemas
feat(backend): implement async endpoints and proximity time decay service logic
feat(frontend): build responsive layout controls and map visualization canvas stubs
fix(backend): correct flood zone geometry intersection threshold
chore(repo): update dependencies and environment template
```

## Quick Start

### 1. Environment Setup

```bash
cp .env.example .env
# Populate .env with your actual keys
```

### 2. Database Migrations

Run migrations against your Supabase PostgreSQL instance:

```sql
-- Execute in order via Supabase SQL Editor or psql
\i database/migrations/001_extensions_and_tables.sql
\i database/migrations/002_routing_logic.sql
\i database/migrations/003_meteorological_data.sql
\i database/migrations/004_simulation_risk_tables.sql
\i database/migrations/005_dynamic_route_cost.sql
\i database/migrations/006_optimized_routing.sql
\i database/migrations/007_barangay_geojson_rpc.sql
\i database/migrations/007_llm_pipeline_columns.sql
```

> Note: the repository currently has two `007_*` migrations. Keep their
> execution order explicit until one file is renumbered.

### 3. Seed Barangay Data

```bash
# Place manila.geojson in data/raw/ (gitignored)
cd database
python seed_geojson_handler.py --file ../data/raw/manila.geojson
```

### 4. Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 5. Frontend

```bash
# From repo root (Flutter project root)
flutter pub get
flutter run -d chrome  # or target device
```

## Directory Structure

```
├── .env.example
├── .gitignore
├── README.md
├── database/
│   ├── migrations/
│   │   ├── 001_extensions_and_tables.sql
│   │   └── 002_routing_logic.sql
│   └── seed_geojson_handler.py
├── backend/
│   ├── requirements.txt
│   ├── main.py
│   └── app/
│       ├── __init__.py
│       ├── core/
│       │   ├── config.py
│       │   └── gemini.py
│       ├── models/
│       │   ├── simulation.py
│       │   └── action_plan.py
│       ├── routes/
│       │   ├── simulation.py
│       │   └── routing.py
│       └── services/
│           ├── decay_engine.py
│           └── bypass_router.py
└── lib/                          # Flutter frontend
    ├── main.dart
    ├── models/
    │   └── simulation_models.dart
    └── views/
        ├── dashboard_screen.dart
        └── widgets/
            ├── control_panel.dart
            └── explainability_card.dart
```

## Spatial Data Contract

The system expects a local `manila.geojson` file containing MultiPolygon geometries for Manila's 505 barangays. This file is **gitignored** and must be placed in `data/raw/` manually.

**Required GeoJSON properties per feature:**
- `barangay_name` (string)
- `district` (string)
- `geometry` (MultiPolygon, EPSG:4326)

## License

Proprietary — All rights reserved.
