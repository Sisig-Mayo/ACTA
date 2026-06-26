import psycopg2
import os
from dotenv import load_dotenv

load_dotenv('backend/.env')
conn = psycopg2.connect(os.getenv('SUPABASE_DATABASE_URL'))
conn.autocommit = True
cur = conn.cursor()

try:
    cur.execute("SELECT pgr_createTopology('road_network', 0.00001, 'geom', 'id', 'source', 'target')")
    print(cur.fetchone())
    print("Notices:", conn.notices)
except Exception as e:
    print(f"Error: {e}")
