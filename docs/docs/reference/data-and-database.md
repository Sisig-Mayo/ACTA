# Data And Database

ACTA depends on Supabase PostgreSQL with spatial extensions and locally supplied
Manila geospatial datasets.

## Migrations

Database migrations live in `database/migrations/`.

Current files:

```text
001_extensions_and_tables.sql
002_routing_logic.sql
003_meteorological_data.sql
004_simulation_risk_tables.sql
005_dynamic_route_cost.sql
006_optimized_routing.sql
007_barangay_geojson_rpc.sql
007_llm_pipeline_columns.sql
```

Apply them in filename order, but handle the duplicate `007` prefix explicitly.
Renumber one of the two `007` files before introducing an automated migration
runner that depends on unique ordering.

## Expected Capabilities

The database is expected to support:

- PostgreSQL tables for profiles, barangays, roads, hazard events, simulation
  runs, and per-barangay risk scores.
- PostGIS geometry operations for barangay boundaries, roads, and impact zones.
- pgRouting route calculations for flood-aware pathfinding.
- Supabase REST access for bulk inserts and result reads.
- Supabase Auth user IDs joined to profile metadata.
- A `get_barangays_geojson` RPC used by the frontend map.

## Spatial Data Contract

Raw geospatial data is ignored by Git and should be placed under `data/raw/`.

Barangay GeoJSON should include one feature per Manila barangay with:

- `barangay_name` as a string.
- `district` as a string.
- MultiPolygon or Polygon geometry in EPSG:4326.

Road data should include routable line geometry compatible with the road import
script and routing migrations.

## Seeding

Run seed scripts from the `database/` directory after applying migrations:

```sh
python seed_geojson_handler.py --file ../data/raw/manila.geojson
python seed_roads_handler.py --file ../data/raw/manila_roads.geojson
```

Use a disposable or staging database first when validating a new source dataset.

## Hazard Events

The ingestion pipeline writes structured hazard-event records to the database
and archives raw JSON payloads in Supabase Storage. The current implementation
uses mock PAGASA-like telemetry and inserts into `hazard_events`.

## Simulation Storage

Simulation runs store:

- Operator input parameters.
- Preparation window.
- Status and progress.
- Severity tier.
- Risk zone counts.
- Generated task list.
- Explainability card.
- LLM action plan JSON.
- LLM context snapshot text.

Per-barangay risk scores are stored separately and queried when completed
simulation results are requested.
