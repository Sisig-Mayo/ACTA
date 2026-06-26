"""
ACTA Data Pipeline — Ingestion Scraper
======================================
Scheduled cron job script that fetches meteorological telemetry,
archives the raw JSON to Supabase Storage, and inserts a 
structured record into Supabase PostgreSQL.

Usage:
    python ingestor.py [--dry-run]
"""

import argparse
import json
import logging
import os
import sys
import uuid
from datetime import datetime, timezone

import requests
from dotenv import load_dotenv
from supabase import create_client, Client

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("acta.pipeline.ingestor")


def fetch_mock_telemetry() -> dict:
    """Simulate fetching from a public API (e.g., PAGASA / OpenWeather)."""
    logger.info("Fetching telemetry data from meteorological source...")
    
    # In a real scenario, use requests.get("https://api.weather.gov/...")
    mock_payload = {
        "source": "MOCK_PAGASA_FEED",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event": {
            "type": "TYPHOON",
            "name": "Karding-MVP",
            "severity": "CRITICAL",
            "metrics": {
                "wind_speed_kph": 185.0,
                "precipitation_24h_mm": 400.0,
                "pressure_hpa": 920.0
            },
            "bounding_box": [
                [120.90, 14.50], [121.05, 14.70]
            ]
        }
    }
    return mock_payload


def process_pipeline(dry_run: bool = False):
    """Main ingestion pipeline."""
    load_dotenv()
    
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    
    if not dry_run and (not supabase_url or not supabase_key):
        logger.error("Missing Supabase credentials in environment. Aborting.")
        sys.exit(1)
        
    # 1. Fetch Data
    raw_data = fetch_mock_telemetry()
    payload_id = str(uuid.uuid4())
    filename = f"telemetry_{payload_id}.json"
    
    logger.info(f"Generated telemetry payload ID: {payload_id}")
    
    if dry_run:
        logger.info("DRY RUN ENABLED. Skipping Supabase upload.")
        logger.info(json.dumps(raw_data, indent=2))
        return

    # Initialize Supabase Client
    supabase: Client = create_client(supabase_url, supabase_key)
    bucket_name = "raw-hazard-data"

    # 2. Upload to Storage (Archival)
    try:
        logger.info(f"Uploading raw payload to Supabase Storage: {bucket_name}/{filename}")
        
        # Ensure bucket exists or fail gracefully
        # In MVP, we assume the bucket is created manually by the operator.
        res = supabase.storage.from_(bucket_name).upload(
            file=filename,
            path=json.dumps(raw_data).encode("utf-8"),
            file_options={"content-type": "application/json"}
        )
        storage_url = supabase.storage.from_(bucket_name).get_public_url(filename)
        logger.info(f"Successfully uploaded. Public URL: {storage_url}")
    except Exception as e:
        logger.error(f"Failed to upload to Supabase Storage: {e}")
        # Depending on strictness, we might sys.exit(1) here. For MVP, we continue to DB insertion.
        storage_url = None

    # 3. Insert Structured Record to PostgreSQL
    try:
        logger.info("Inserting structured record into 'hazard_events' PostgreSQL table...")
        metrics = raw_data["event"]["metrics"]
        
        db_payload = {
            "hazard_type": raw_data["event"]["type"],
            "severity_label": raw_data["event"]["severity"],
            "wind_speed_kph": metrics["wind_speed_kph"],
            "precipitation_24h_mm": metrics["precipitation_24h_mm"],
            "raw_storage_url": storage_url
        }
        
        db_res = supabase.table("hazard_events").insert(db_payload).execute()
        logger.info(f"Successfully inserted DB record: {db_res.data}")
    except Exception as e:
        logger.error(f"Failed to insert record into Supabase PostgreSQL: {e}")
        sys.exit(1)

    logger.info("Data Pipeline ingestion cycle completed successfully.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ACTA Data Pipeline Ingestor")
    parser.add_argument("--dry-run", action="store_true", help="Run without pushing to Supabase")
    args = parser.parse_args()
    
    process_pipeline(dry_run=args.dry_run)
