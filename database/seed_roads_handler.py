"""
ACTA Database — Synthetic Road Network Seeder
===================================
Generates a dense grid of synthetic road data for Manila,
inserts it into the `road_network` table, and automatically builds
the pgRouting topology (`road_network_vertices_pgr`).

This bypasses Overpass API blocks and allows the routing engine to be tested.
"""

import logging
import math
import os
import sys
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("acta.seed_roads")

# Load environment variables from backend/.env file.
ROOT_DIR = Path(__file__).resolve().parent.parent
load_dotenv(ROOT_DIR / "backend" / ".env")

DATABASE_URL: str = os.getenv("SUPABASE_DATABASE_URL", "")


def haversine_distance(lon1: float, lat1: float, lon2: float, lat2: float) -> float:
    """Calculate the great circle distance between two points in meters."""
    R = 6371000  # Radius of earth in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2.0) ** 2 + \
        math.cos(phi1) * math.cos(phi2) * \
        math.sin(delta_lambda / 2.0) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return R * c


def generate_synthetic_roads() -> list[dict]:
    """Generates a dense grid of roads over the Manila bounding box."""
    logger.info("Generating synthetic road grid for Manila (avoiding Overpass API limits)...")
    
    # Manila Bounding Box
    min_lon, max_lon = 120.85, 121.10
    min_lat, max_lat = 14.50, 14.70
    
    grid_size = 50  # 50x50 grid
    lon_step = (max_lon - min_lon) / grid_size
    lat_step = (max_lat - min_lat) / grid_size
    
    ways = []
    
    # Generate horizontal roads
    for i in range(grid_size + 1):
        lat = min_lat + (i * lat_step)
        for j in range(grid_size):
            lon1 = min_lon + (j * lon_step)
            lon2 = min_lon + ((j + 1) * lon_step)
            ways.append({
                "nodes": [
                    {"lon": lon1, "lat": lat},
                    {"lon": lon2, "lat": lat}
                ]
            })
            
    # Generate vertical roads
    for j in range(grid_size + 1):
        lon = min_lon + (j * lon_step)
        for i in range(grid_size):
            lat1 = min_lat + (i * lat_step)
            lat2 = min_lat + ((i + 1) * lat_step)
            ways.append({
                "nodes": [
                    {"lon": lon, "lat": lat1},
                    {"lon": lon, "lat": lat2}
                ]
            })
            
    return ways


def seed_road_network(ways: list[dict]):
    """Insert synthetic road network into PostgreSQL."""
    if not DATABASE_URL:
        logger.error("SUPABASE_DATABASE_URL is not set in backend/.env")
        sys.exit(1)

    logger.info(f"Generated {len(ways)} synthetic road segments.")

    try:
        # Use psycopg2 to connect directly to the database
        logger.info("Connecting to database...")
        conn = psycopg2.connect(DATABASE_URL)
        conn.autocommit = False
        cursor = conn.cursor()

        logger.info("Dropping NOT NULL constraints on source and target for pgRouting...")
        cursor.execute("ALTER TABLE road_network ALTER COLUMN source DROP NOT NULL;")
        cursor.execute("ALTER TABLE road_network ALTER COLUMN target DROP NOT NULL;")

        logger.info("Clearing existing road network data...")
        cursor.execute("TRUNCATE TABLE road_network RESTART IDENTITY CASCADE;")
        cursor.execute("DROP TABLE IF EXISTS road_network_vertices_pgr CASCADE;")

        logger.info("Inserting road segments into road_network...")
        
        from psycopg2.extras import execute_values
        
        insert_count = 0
        values = []
        for way in ways:
            n1 = way["nodes"][0]
            n2 = way["nodes"][1]
            
            linestring_wkt = f"LINESTRING({n1['lon']} {n1['lat']}, {n2['lon']} {n2['lat']})"
            
            # Calculate physical length for base cost
            length_m = haversine_distance(n1["lon"], n1["lat"], n2["lon"], n2["lat"])
            base_cost = length_m
            base_reverse_cost = length_m

            # Insert None (NULL) for source and target so pgr_createTopology will process them
            values.append((None, None, base_cost, base_reverse_cost, base_cost, base_reverse_cost, linestring_wkt))
            insert_count += 1

        execute_values(
            cursor,
            """
            INSERT INTO road_network (
                source, target, cost, reverse_cost, base_cost, base_reverse_cost, geom
            ) VALUES %s
            """,
            values,
            template="(%s, %s, %s, %s, %s, %s, ST_GeomFromText(%s, 4326))"
        )

        logger.info(f"Successfully inserted {insert_count} synthetic road segments.")

        logger.info("Building pgRouting topology (pgr_createTopology)... this may take a few seconds.")
        cursor.execute(
            """
            SELECT pgr_createTopology(
                'road_network',
                0.00001,
                'geom',
                'id',
                'source',
                'target'
            );
            """
        )
        result = cursor.fetchone()[0]
        if result == 'FAIL':
            raise Exception("pgr_createTopology returned FAIL. Check database notices.")
        logger.info("Topology built successfully!")

        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info("Road network seeding complete!")

    except Exception as e:
        logger.error(f"Database operation failed: {e}")
        if 'conn' in locals() and conn:
            conn.rollback()
            conn.close()
        sys.exit(1)


def main():
    logger.info("Starting Road Network Seeder...")
    ways = generate_synthetic_roads()
    seed_road_network(ways)


if __name__ == "__main__":
    main()
