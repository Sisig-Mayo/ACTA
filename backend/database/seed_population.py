"""
Script to add the 'population' column to the 'barangays' table and seed it
from the population.csv file provided in the root directory.
"""

import csv
import logging
import os
import sys
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("acta.seed_population")

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
load_dotenv(ROOT_DIR / "backend" / ".env")

DATABASE_URL: str = os.getenv("SUPABASE_DATABASE_URL", "")
CSV_PATH = ROOT_DIR / "population.csv"

def seed_population():
    if not DATABASE_URL:
        logger.error("SUPABASE_DATABASE_URL is not set.")
        sys.exit(1)

    if not CSV_PATH.exists():
        logger.error(f"population.csv not found at {CSV_PATH}")
        sys.exit(1)

    logger.info("Connecting to database...")
    try:
        conn = psycopg2.connect(DATABASE_URL)
        conn.autocommit = False
        cursor = conn.cursor()

        logger.info("Adding 'population' column to 'barangays' if it doesn't exist...")
        cursor.execute("""
            ALTER TABLE barangays 
            ADD COLUMN IF NOT EXISTS population INTEGER DEFAULT 0;
        """)

        logger.info("Reading population.csv and preparing updates...")
        updates = []
        with open(CSV_PATH, mode='r', encoding='utf-8') as f:
            reader = csv.reader(f)
            # The CSV might not have a header, let's assume columns based on sample:
            # e.g., PH133900000, Barangay 652, PH133913004, , U, 39
            for row in reader:
                if len(row) < 6:
                    continue
                barangay_name = row[1].strip()
                try:
                    population = int(row[5].strip())
                    updates.append((population, barangay_name))
                except ValueError:
                    logger.warning(f"Skipping row with invalid population: {row}")

        logger.info(f"Loaded {len(updates)} records from CSV. Updating database...")

        from psycopg2.extras import execute_values
        
        # We need to update existing rows based on barangay_name.
        # execute_values is for insert, but we can do an UPDATE ... FROM ...
        # Or just a simple loop with executemany
        
        update_query = """
            UPDATE barangays
            SET population = data.population
            FROM (VALUES %s) AS data (population, barangay_name)
            WHERE barangays.barangay_name = data.barangay_name;
        """
        
        # The values need to be cast correctly in PostgreSQL
        update_query_cast = """
            UPDATE barangays
            SET population = data.population
            FROM (VALUES %s) AS data (population_int, barangay_name_str)
            WHERE barangays.barangay_name = data.barangay_name_str;
        """
        
        # Actually it's easier to use executemany for updates if we only have <1000 records
        cursor.executemany(
            "UPDATE barangays SET population = %s WHERE barangay_name = %s",
            updates
        )

        logger.info(f"Database updated. Committing changes...")
        conn.commit()
        cursor.close()
        conn.close()
        logger.info("Population data seeded successfully!")

    except Exception as e:
        logger.error(f"Database operation failed: {e}")
        if 'conn' in locals() and conn:
            conn.rollback()
            conn.close()
        sys.exit(1)

if __name__ == "__main__":
    seed_population()
