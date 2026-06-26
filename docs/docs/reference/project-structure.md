# Project Structure

The repository combines Flutter, FastAPI, Supabase database migrations, and
documentation.

```text
ACTA/
├── android/                     # Flutter Android runner
├── ios/                         # Flutter iOS runner
├── linux/                       # Flutter Linux runner
├── macos/                       # Flutter macOS runner
├── web/                         # Flutter web runner
├── windows/                     # Flutter Windows runner
├── lib/                         # Flutter application code
│   ├── assets/
│   ├── models/
│   ├── utils/
│   └── views/
├── backend/                     # FastAPI backend
│   ├── app/
│   │   ├── core/
│   │   ├── models/
│   │   ├── routes/
│   │   └── services/
│   ├── database/
│   ├── main.py
│   └── requirements.txt
├── database/                    # Supabase/PostGIS migrations and seed scripts
│   ├── migrations/
│   ├── seed_geojson_handler.py
│   └── seed_roads_handler.py
├── data_pipeline/               # Hazard telemetry ingestion job
├── docs/
│   ├── docs/                    # MkDocs Markdown source
│   ├── site/                    # Generated MkDocs output
│   └── mkdocs.yml
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
├── .env.example
└── README.md
```

## Flutter Application

`lib/main.dart`

: Initializes `ProviderScope`, configures the ACTA dark theme, and starts at
  `LoginScreen`.

`lib/views/`

: Contains operator-facing screens such as login, command center, simulation
  setup, run status, AI action plans, master action plans, and resource
  management.

`lib/models/`

: Contains frontend state and data models for simulation, barangays, and user
  profile handling.

`lib/utils/`

: Contains utility code such as cross-platform PDF download handling.

## Backend

`backend/main.py`

: Creates the FastAPI app, configures CORS, registers routers, and exposes
  `/health`.

`backend/app/core/`

: Holds configuration, Supabase client setup, Gemini integration, and constants.

`backend/app/models/`

: Holds Pydantic request and response models for simulation and LLM data.

`backend/app/routes/`

: Defines auth, simulation, routing, and barangay endpoints.

`backend/app/services/`

: Implements routing, dispatch, PDF generation, GEE risk scoring, time decay,
  LLM context assembly, and simulation orchestration.

## Database

`database/migrations/`

: SQL migrations for extensions, spatial tables, routing logic, hazard events,
  simulation risk tables, route cost updates, barangay GeoJSON RPC, and LLM
  result storage.

`database/seed_geojson_handler.py`

: Imports Manila barangay GeoJSON data.

`database/seed_roads_handler.py`

: Imports road network data for routing.

## Data Pipeline

`data_pipeline/ingestor.py`

: Fetches telemetry, archives raw JSON into Supabase Storage, and inserts a
  structured hazard event record.

## Documentation

`docs/mkdocs.yml`

: Configures MkDocs navigation, theme, Markdown extensions, and custom CSS.

`docs/docs/`

: Contains the Markdown source pages for the technical documentation.

`docs/site/`

: Contains generated static HTML. Treat it as build output and regenerate it
  from `docs/docs/` when publishing.
