"""
ACTA — GeoJSON Seed Handler
============================
Parses a local manila.geojson file and bulk-inserts barangay
boundary features into the Supabase PostgreSQL `barangays` table.

Target Branch : feature/spatial-db
Commit        : feat(db): add geojson seed handler for manila barangay ingestion

Usage:
    python seed_geojson_handler.py --file ../data/raw/manila.geojson

Prerequisites:
    pip install psycopg2-binary python-dotenv
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
from pathlib import Path
from typing import Any

try:
    import psycopg2
    from psycopg2.extras import execute_values
except ImportError:
    print("ERROR: psycopg2 is required. Install via: pip install psycopg2-binary")
    sys.exit(1)

try:
    from dotenv import load_dotenv
except ImportError:
    print("ERROR: python-dotenv is required. Install via: pip install python-dotenv")
    sys.exit(1)

# -----------------------------------------------------------
# Configuration
# -----------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("acta.seed")

# Load environment variables from backend/.env file.
ROOT_DIR = Path(__file__).resolve().parent.parent
load_dotenv(ROOT_DIR / "backend" / ".env")

DATABASE_URL: str = os.getenv("SUPABASE_DATABASE_URL", "")

if not DATABASE_URL:
    logger.error(
        "SUPABASE_DATABASE_URL is not set. "
        "Copy .env.example to .env and populate credentials."
    )
    sys.exit(1)


# -----------------------------------------------------------
# GeoJSON Parser
# -----------------------------------------------------------

def parse_geojson(filepath: Path) -> list[dict[str, Any]]:
    """
    Parse a GeoJSON FeatureCollection file and extract
    barangay records with their MultiPolygon geometries.

    Expects each Feature to have properties:
        - barangay_name (str)
        - district (str)
    And a geometry of type MultiPolygon or Polygon.
    """
    logger.info("Reading GeoJSON from: %s", filepath)

    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)

    if data.get("type") != "FeatureCollection":
        raise ValueError(
            f"Expected a GeoJSON FeatureCollection, got: {data.get('type')}"
        )

    features = data.get("features", [])
    logger.info("Found %d features in GeoJSON file.", len(features))

    records: list[dict[str, Any]] = []

    for idx, feature in enumerate(features):
        props = feature.get("properties", {})
        geometry = feature.get("geometry", {})

        # Extract barangay name — try common property key variants.
        # The official Manila GeoJSON uses 'adm4_name' as the primary key.
        barangay_name = (
            props.get("adm4_name")
            or props.get("barangay_name")
            or props.get("NAME")
            or props.get("name")
            or props.get("BARANGAY")
            or props.get("adm4_en")
            or f"Unknown_Barangay_{idx}"
        )

        # District maps to 'adm2_name' in the official data.
        district = (
            props.get("adm2_name")
            or props.get("district")
            or props.get("DISTRICT")
            or props.get("adm3_en")
            or "Unspecified"
        )

        geom_type = geometry.get("type", "")

        # Normalize Polygon to MultiPolygon for uniform storage.
        if geom_type == "Polygon":
            geometry = {
                "type": "MultiPolygon",
                "coordinates": [geometry["coordinates"]],
            }
        elif geom_type != "MultiPolygon":
            logger.warning(
                "Skipping feature %d (%s): unsupported geometry type '%s'.",
                idx, barangay_name, geom_type,
            )
            continue

        records.append({
            "barangay_name": barangay_name.strip(),
            "district": district.strip(),
            "geom_geojson": json.dumps(geometry),
        })

    logger.info("Parsed %d valid barangay records.", len(records))
    return records


# -----------------------------------------------------------
# Database Ingestion
# -----------------------------------------------------------

def seed_barangays(records: list[dict[str, Any]]) -> None:
    """
    Bulk-insert parsed barangay records into the `barangays` table.
    Uses ST_GeomFromGeoJSON for geometry conversion.
    Performs an upsert on barangay_name to allow re-seeding.
    """
    if not records:
        logger.warning("No records to insert. Aborting.")
        return

    # Parse the DATABASE_URL for psycopg2 compatibility.
    # Supabase URLs use postgresql+asyncpg:// — strip the async driver.
    conn_url = DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")

    logger.info("Connecting to database...")
    conn = psycopg2.connect(conn_url)
    cursor = conn.cursor()

    try:
        insert_sql = """
            INSERT INTO barangays (barangay_name, district, geom)
            VALUES %s
            ON CONFLICT (barangay_name) DO UPDATE SET
                district = EXCLUDED.district,
                geom     = EXCLUDED.geom,
                updated_at = NOW()
        """

        # Prepare value tuples.
        values = [
            (
                r["barangay_name"],
                r["district"],
                f"ST_SetSRID(ST_GeomFromGeoJSON('{r['geom_geojson']}'), 4326)",
            )
            for r in records
        ]

        # Use raw SQL with mogrify for geometry function calls.
        insert_statements: list[str] = []
        for r in records:
            stmt = cursor.mogrify(
                "(%(name)s, %(district)s, ST_SetSRID(ST_GeomFromGeoJSON(%(geom)s), 4326))",
                {
                    "name": r["barangay_name"],
                    "district": r["district"],
                    "geom": r["geom_geojson"],
                },
            ).decode("utf-8")
            insert_statements.append(stmt)

        # Build and execute the bulk insert.
        full_sql = f"""
            INSERT INTO barangays (barangay_name, district, geom)
            VALUES {', '.join(insert_statements)}
            ON CONFLICT (barangay_name) DO UPDATE SET
                district   = EXCLUDED.district,
                geom       = EXCLUDED.geom,
                updated_at = NOW();
        """

        cursor.execute(full_sql)
        conn.commit()

        logger.info(
            "Successfully seeded %d barangay records into the database.",
            len(records),
        )

    except Exception as e:
        conn.rollback()
        logger.error("Database ingestion failed: %s", e)
        raise

    finally:
        cursor.close()
        conn.close()
        logger.info("Database connection closed.")


# -----------------------------------------------------------
# CLI Entry Point
# -----------------------------------------------------------

def main() -> None:
    """Parse CLI arguments and execute the seed pipeline."""
    parser = argparse.ArgumentParser(
        description="ACTA — Seed Manila barangay boundaries from GeoJSON.",
    )
    parser.add_argument(
        "--file",
        type=str,
        required=False,
        default=str(ROOT_DIR / "backend" / "data" / "raw" / "manila.geojson"),
        help="Path to the manila.geojson file (default: backend/data/raw/manila.geojson).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse and validate the GeoJSON without writing to the database.",
    )

    args = parser.parse_args()
    filepath = Path(args.file).resolve()

    if not filepath.exists():
        logger.error("GeoJSON file not found: %s", filepath)
        sys.exit(1)

    if not filepath.suffix.lower() == ".geojson":
        logger.warning("File does not have .geojson extension: %s", filepath)

    records = parse_geojson(filepath)

    if args.dry_run:
        logger.info("[DRY RUN] Parsed %d records. No database write.", len(records))
        for r in records[:5]:
            logger.info("  → %s (%s)", r["barangay_name"], r["district"])
        if len(records) > 5:
            logger.info("  ... and %d more.", len(records) - 5)
        return

    seed_barangays(records)


if __name__ == "__main__":
    main()
