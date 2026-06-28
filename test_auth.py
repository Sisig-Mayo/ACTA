import asyncio
import httpx

async def test():
    async with httpx.AsyncClient() as client:
        r = await client.post('https://acta-production.up.railway.app/api/v1/auth/login', json={'email': 'test@test.com', 'password': 'password'})
        print(r.status_code, r.text)

asyncio.run(test())
