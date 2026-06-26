import asyncio
import os
import sys

from dotenv import load_dotenv

sys.path.insert(0, os.getcwd())
load_dotenv(".env")

async def run():
    from app.services.bypass_router import _get_pool
    pool = await _get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'barangays'")
        for row in rows:
            print(dict(row))

if __name__ == "__main__":
    asyncio.run(run())
