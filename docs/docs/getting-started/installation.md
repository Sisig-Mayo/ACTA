# Installation

ACTA requires Flutter, Python, and a Supabase PostgreSQL project with the
extensions and tables defined by the repository migrations.

## Requirements

- Flutter SDK compatible with Dart `^3.12.2`.
- Python 3.11 or newer for the backend.
- Supabase project with PostgreSQL, PostGIS, and pgRouting support.
- Google Gemini API key if AI-generated action plans should run.
- Google Earth Engine credentials if GEE-backed risk scoring should run.
- Platform toolchains for any Flutter target you plan to build.

Check Flutter locally:

```sh
flutter doctor
flutter devices
```

## Environment File

Create a local `.env` from the checked-in example:

```sh
cp .env.example .env
```

Fill in the Supabase and Google values required for the services you want to
run. The backend reads `.env` from the repository root.

Never commit `.env`; it is intentionally ignored.

## Frontend Dependencies

From the repository root:

```sh
flutter pub get
```

The Flutter app uses Riverpod, Dio, Flutter Map, Google Fonts, intl, and JSON
generation tooling in addition to the Flutter SDK.

## Backend Dependencies

From the repository root:

```sh
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

On Windows, activate the virtual environment with:

```bat
.venv\Scripts\activate
```

## Data Pipeline Dependencies

The ingestion pipeline has its own requirements file:

```sh
cd data_pipeline
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Database Migrations

Apply the SQL files in `database/migrations/` to the Supabase PostgreSQL
database in filename order.

!!! warning "Duplicate migration number"
    The repository currently contains both `007_barangay_geojson_rpc.sql` and
    `007_llm_pipeline_columns.sql`. Keep their execution order explicit in your
    migration process until one of them is renumbered.

## Spatial Seed Data

Raw geospatial files are not committed. Place local source files under
`data/raw/` and run the relevant seed scripts:

```sh
cd database
python seed_geojson_handler.py --file ../data/raw/manila.geojson
python seed_roads_handler.py --file ../data/raw/manila_roads.geojson
```

Confirm the expected file names and geometry fields before running imports in a
shared database.

## Documentation Tools

MkDocs builds the technical documentation:

```sh
mkdocs serve -f docs/mkdocs.yml
mkdocs build -f docs/mkdocs.yml
```

Documentation source lives under `docs/docs/`.
