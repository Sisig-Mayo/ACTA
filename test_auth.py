import asyncio
import httpx

async def test():
    async with httpx.AsyncClient() as client:
        r = await client.post('https://yzkjibqkoxdxkvrrbhqm.supabase.co/auth/v1/token?grant_type=password', headers={'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl6a2ppYnFrb3hkeGt2cnJiaHFtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjM5OTUxMSwiZXhwIjoyMDk3OTc1NTExfQ.2V5b7jyYsfyeM1p1b2-Zgty9dyb6dNkT-eYRMiM-iwY'}, json={'email': 'test@test.com', 'password': 'password'})
        print(r.status_code, r.text)

asyncio.run(test())
