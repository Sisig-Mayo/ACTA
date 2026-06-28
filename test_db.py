import asyncio
import asyncpg

async def test():
    pool = await asyncpg.create_pool(
        'postgresql://postgres.yzkjibqkoxdxkvrrbhqm:larpmaxxing@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres',
        min_size=1,
        max_size=1
    )
    async with pool.acquire() as conn:
        print(await conn.fetchval('SELECT 1'))
    await pool.close()

asyncio.run(test())
