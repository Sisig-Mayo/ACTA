# System Architecture

ACTA is organized as a Flutter client, FastAPI service layer, Supabase-backed
geospatial database, and optional AI planning layer.

## Runtime Layers

```text
Flutter Dashboard
  |
  | HTTP JSON / PDF
  v
FastAPI Backend
  |
  | Supabase REST, async PostgreSQL, PostGIS/pgRouting
  v
Supabase PostgreSQL
  |
  | risk scores, simulation runs, routes, profiles
  v
Operator Results
```

The backend also calls Google Earth Engine for risk scoring and Gemini for
context-aware action planning when those integrations are configured.

## Frontend

The Flutter entry point is `lib/main.dart`.

`main()` initializes Flutter bindings and wraps the application in a Riverpod
`ProviderScope`:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ActaApp()));
}
```

`ActaApp` configures a dark Material theme and starts at `LoginScreen`. The app
currently contains screens for login, simulation setup, simulation execution,
command center views, AI action plans, master action plans, and resource
management.

The frontend uses:

- `flutter_riverpod` for state management.
- `dio` for HTTP calls.
- `flutter_map` and `latlong2` for map rendering.
- `google_fonts` for typography.
- `json_annotation` tooling for structured models.

Several frontend files currently use `http://localhost:8000` directly as the
backend base URL. Replace those constants with environment-specific
configuration before deploying beyond local development.

## Backend

The FastAPI entry point is `backend/main.py`. It registers these routers:

- `/api/v1/auth`
- `/api/v1/simulation`
- `/api/v1/routing`
- `/api/v1/barangays`

The backend owns:

- Supabase Auth registration/login proxying.
- Simulation run creation and status/result retrieval.
- Background risk pipeline execution.
- Flood-aware routing endpoints.
- Barangay GeoJSON retrieval.
- PDF generation for master action plans.
- Dispatch manifest generation.
- LLM context snapshot retrieval for audit/debug.

Configuration is loaded through `backend/app/core/config.py` from environment
variables or the repository root `.env` file.

## Database And Spatial Data

Supabase PostgreSQL is expected to provide PostGIS and pgRouting support. The
schema migrations live in `database/migrations/`.

The application expects Manila barangay geometries, road network data, hazard
events, simulation runs, barangay risk scores, and auth profile records to be
available in the database.

Raw spatial files such as GeoJSON, shapefiles, and rasters are intentionally
ignored by Git. Store them locally under `data/raw/` and import them with the
seed scripts.

## Simulation Pipeline

The simulation pipeline starts from `POST /api/v1/simulation/run`:

1. Validate operator input with `SimulationInput`.
2. Insert a `simulation_runs` row with `PENDING` status.
3. Run the background pipeline from `backend/app/services/risk_pipeline.py`.
4. Compute barangay risk scores through the GEE risk engine.
5. Persist risk scores and update route cost modifiers.
6. Generate time-decayed template tasks.
7. Assemble a five-section LLM context document.
8. Ask Gemini to refine the action plan, or use the fallback template response.
9. Store results, explainability data, LLM output, and context snapshots.

## LLM Boundary

Gemini is an enhancement layer, not the only source of action plans. The backend
contains a fallback response path so simulation results can still complete when
`GEMINI_API_KEY` is missing or the Gemini API call fails.

LLM context snapshots are stored for auditability and exposed through
`GET /api/v1/simulation/llm-context/{run_id}`.

## Platform Projects

The platform folders are Flutter runner projects:

- `android/`
- `ios/`
- `linux/`
- `macos/`
- `web/`
- `windows/`

Most product code should stay in `lib/`. Edit platform folders only for native
integration, app metadata, signing, or platform-specific behavior.
