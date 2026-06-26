# Troubleshooting

This page lists common local setup problems and the first checks to make.

## Backend Does Not Start

Check that the backend virtual environment is active and dependencies are
installed:

```sh
cd backend
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

If settings fail to load, confirm `.env` exists at the repository root and uses
the variable names from `.env.example`.

## `/health` Works But API Calls Fail

Check Supabase configuration:

- `SUPABASE_URL` is the project URL.
- `SUPABASE_SERVICE_ROLE_KEY` is a service role key, not an anon key.
- `SUPABASE_DATABASE_URL` is reachable from your machine.
- Database migrations have been applied.

## Auth Fails

Registration and login proxy to Supabase Auth. Check:

- Supabase project URL and service role key.
- Network access to Supabase.
- The `profiles` table and related auth/profile trigger or fallback insert path.
- Password rules configured in Supabase.

## Simulation Never Completes

Check backend logs for the background pipeline. Common causes:

- Missing Supabase credentials.
- Missing required database tables or columns.
- Missing barangay seed data.
- Google Earth Engine credentials not configured.
- Gemini error, though this should fall back to template output.

Use:

```text
GET /api/v1/simulation/status/{run_id}
```

to inspect `status`, `progress_pct`, and `error_message`.

## Results Return `400`

`GET /api/v1/simulation/results/{run_id}` only works after the run status is
`COMPLETED`. Poll the status endpoint first.

## Barangay Map Is Empty

Check:

- Barangay GeoJSON seed data has been imported.
- The `get_barangays_geojson` RPC migration has been applied.
- `GET /api/v1/barangays/geojson` returns a GeoJSON FeatureCollection.
- Browser requests are reaching the backend at `http://localhost:8000`.

## Frontend Cannot Reach Backend

The Flutter code currently uses `http://localhost:8000` in multiple files. That
works for Chrome and desktop apps running on the same machine as the backend.

For Android emulators, iOS simulators, physical devices, or deployed builds,
configure a reachable backend URL for that target.

## Gemini Output Is Missing

If `GEMINI_API_KEY` is empty or Gemini returns an error, ACTA uses fallback
template action-plan output. Check the `generated_by` field through:

```text
GET /api/v1/simulation/llm-context/{run_id}
```

## Data Pipeline Upload Fails

Check:

- `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
- Supabase Storage bucket `raw-hazard-data` exists.
- The `hazard_events` table exists.
- Live mode is being used only when credentials are configured.

Use dry-run mode first:

```sh
cd data_pipeline
python ingestor.py --dry-run
```
