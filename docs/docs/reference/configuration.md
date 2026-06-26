# Configuration

This page summarizes the important project configuration files and environment
variables.

## Environment Variables

The backend reads environment variables from the repository root `.env` file or
from the process environment.

| Variable | Required | Purpose |
| --- | --- | --- |
| `PROJECT_NAME` | No | FastAPI service name. Defaults to `ACTA`. |
| `DEBUG` | No | Enables debug-oriented behavior where code checks it. |
| `LOG_LEVEL` | No | Logging level value. |
| `SUPABASE_URL` | Yes | Supabase project URL used for Auth, REST, and Storage calls. |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | Service role key used by backend server-side operations. |
| `SUPABASE_DATABASE_URL` | Yes | PostgreSQL connection string for async database access. |
| `GEMINI_API_KEY` | Optional | Enables Gemini action-plan generation. Fallback output is used when missing. |
| `GEE_SERVICE_ACCOUNT_FILE` | Optional | Path to Google Earth Engine service account credentials. |
| `GOOGLE_MAPS_API_KEY` | Optional | Reserved for Google Maps integrations. |
| `CORS_ORIGINS` | No | Comma-separated browser origins allowed by the backend. |
| `REDIS_URL` | Optional | Reserved for caching integrations. |

Use `.env.example` as the safe template for local `.env` files.

## Flutter Package

`pubspec.yaml` defines the Flutter package:

```yaml
name: acta
description: "ACTA: Context-Aware Decision-to-Action Simulation Engine — Flutter Dashboard"
publish_to: 'none'
version: 0.1.0+1
```

The SDK constraint is:

```yaml
environment:
  sdk: ^3.12.2
```

Runtime dependencies include:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  dio: ^5.7.0
  google_fonts: ^6.2.1
  intl: ^0.19.0
  json_annotation: ^4.9.0
```

Development dependencies include Flutter tests, Flutter lints, build runner,
JSON serialization, and Riverpod code generation.

The app enables Material support and includes assets from `lib/assets/`.

## Backend Package

`backend/requirements.txt` defines Python dependencies for:

- FastAPI and Uvicorn.
- SQLAlchemy asyncio, asyncpg, and GeoAlchemy.
- Pydantic settings and validation.
- Supabase REST/Auth/Storage access.
- Google Gemini.
- Google Earth Engine.
- HTTP clients.
- GeoJSON and Shapely utilities.
- PDF generation.
- Redis client support.

The backend expects Python 3.11 or newer.

## CORS

`CORS_ORIGINS` is a comma-separated list. The backend also allows localhost and
`127.0.0.1` origins through a regex for local development.

Example:

```env
CORS_ORIGINS=http://localhost:3000,http://localhost:8080,http://localhost:5173
```

## Documentation Site

`docs/mkdocs.yml` configures:

- Site metadata.
- ReadTheDocs theme.
- Custom CSS.
- Navigation.
- Markdown admonitions.
- Permalinked table of contents headings.

Run the docs locally with:

```sh
mkdocs serve -f docs/mkdocs.yml
```

Build the static site with:

```sh
mkdocs build -f docs/mkdocs.yml
```
