# API Reference

The FastAPI backend runs from `backend/main.py` and exposes interactive OpenAPI
documentation at `/docs` and `/redoc` when the service is running.

Local base URL:

```text
http://localhost:8000
```

## Health

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/health` | Returns basic service health, name, and version. |

## Authentication

Base path: `/api/v1/auth`

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/register` | Create a Supabase Auth user and profile metadata. |
| `POST` | `/login` | Exchange email/password for Supabase access and refresh tokens. |
| `GET` | `/me` | Resolve the current user from a Bearer token. |

Register request:

```json
{
  "email": "operator@example.gov.ph",
  "password": "change-me",
  "first_name": "Maria",
  "last_name": "Santos"
}
```

Login request:

```json
{
  "email": "operator@example.gov.ph",
  "password": "change-me"
}
```

`GET /me` requires:

```text
Authorization: Bearer <access_token>
```

## Simulation

Base path: `/api/v1/simulation`

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/run` | Create a simulation run and start background processing. |
| `GET` | `/status/{run_id}` | Return status, progress percentage, and error message if present. |
| `GET` | `/results/{run_id}` | Return completed simulation output. |
| `POST` | `/export-pdf` | Generate a master action plan PDF from simulation output. |
| `POST` | `/dispatch` | Execute or prepare a dispatch manifest from an action plan payload. |
| `GET` | `/llm-context/{run_id}` | Return stored LLM action plan and context snapshot for audit/debug. |

Simulation request:

```json
{
  "wind_speed_kph": 120.5,
  "precipitation_24h_mm": 350.0,
  "preparation_window_hours": 36,
  "storm_track_points": [
    [120.98, 14.60],
    [120.95, 14.55],
    [120.90, 14.50]
  ],
  "storm_radius_km": 100.0
}
```

Accepted response:

```json
{
  "run_id": "uuid",
  "status": "PENDING",
  "message": "Simulation accepted and processing in the background."
}
```

Results are available only after the run status is `COMPLETED`; otherwise the
results endpoint returns a `400` response.

## Routing

Base path: `/api/v1/routing`

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/safe-route` | Compute a flood-aware route between two coordinates. |
| `GET` | `/barangays` | Return all Manila barangay boundaries as GeoJSON. |
| `POST` | `/impacted` | Return barangays intersecting a supplied flood-zone WKT geometry. |

Safe-route request:

```json
{
  "start_lng": 120.9842,
  "start_lat": 14.5995,
  "end_lng": 120.9730,
  "end_lat": 14.6042
}
```

Impact query request:

```json
{
  "flood_zone_wkt": "POLYGON((120.98 14.59,120.99 14.59,120.99 14.60,120.98 14.60,120.98 14.59))"
}
```

## Barangays

Base path: `/api/v1/barangays`

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/geojson` | Return Manila barangays as a GeoJSON FeatureCollection from the database RPC. |

This endpoint depends on the `get_barangays_geojson` database function from the
barangay GeoJSON RPC migration.

## Error Handling

Common error responses:

- `400`: Simulation results or LLM context requested before the run completes.
- `401`: Missing or invalid auth token.
- `404`: Simulation run not found.
- `500`: Database, routing, PDF generation, or dispatch failure.
- `503`: Supabase Auth API unavailable.
