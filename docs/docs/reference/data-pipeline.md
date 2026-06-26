# Data Pipeline

The data pipeline lives in `data_pipeline/` and currently provides a small
hazard telemetry ingestion script.

## Ingestor

`data_pipeline/ingestor.py` performs three steps:

1. Fetch a telemetry payload.
2. Archive the raw JSON payload into Supabase Storage.
3. Insert a structured hazard event row into Supabase PostgreSQL.

The current implementation uses mock PAGASA-like typhoon telemetry. Replace
`fetch_mock_telemetry()` with a real source integration when production
telemetry is available.

## Dependencies

Install dependencies from the pipeline directory:

```sh
cd data_pipeline
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Environment

The script reads:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

These may come from a local `.env` file or process environment.

## Dry Run

Use dry-run mode to print the generated telemetry payload without writing to
Supabase:

```sh
python ingestor.py --dry-run
```

## Live Run

Run without `--dry-run` to upload raw JSON and insert a database record:

```sh
python ingestor.py
```

The Supabase Storage bucket `raw-hazard-data` is assumed to exist. Create it in
Supabase before running live ingestion.

## CI

The repository contains `.github/workflows/data_pipeline.yml`. Keep this
workflow aligned with any changes to script arguments, environment variables, or
dependency installation.
