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
```

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
