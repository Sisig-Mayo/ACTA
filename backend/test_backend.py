import httpx
import asyncio
import json

async def test_backend():
    print("Testing Backend API Endpoints...")
    async with httpx.AsyncClient(base_url="http://127.0.0.1:8000", timeout=10.0) as client:
        try:
            # Test 1: Health Check
            print("1. Testing /health endpoint...")
            resp = await client.get("/health")
            resp.raise_for_status()
            print(f"Health check passed: {resp.json()}")

            # Test 2: Run Simulation
            print("\n2. Testing /api/v1/simulation/run endpoint...")
            payload = {
                "wind_speed_kph": 150.5,
                "precipitation_24h_mm": 350.0,
                "preparation_window_hours": 36,
                "storm_track_points": [[120.98, 14.60], [120.95, 14.55], [120.90, 14.50]]
            }
            sim_resp = await client.post("/api/v1/simulation/run", json=payload)
            sim_resp.raise_for_status()
            sim_data = sim_resp.json()
            print(f"Simulation completed with severity: {sim_data['severity_tier']}")
            print(f"Tasks generated: {len(sim_data['task_list'])}")
            print(f"GEE rendering data: {sim_data['metadata'].get('gee_rendering')}")

            # Test 3: Export PDF
            print("\n3. Testing /api/v1/simulation/export-pdf endpoint...")
            pdf_resp = await client.post("/api/v1/simulation/export-pdf", json=sim_data)
            pdf_resp.raise_for_status()
            print(f"PDF generated successfully, size: {len(pdf_resp.content)} bytes")
            with open("ACTA_Action_Plan.pdf", "wb") as f:
                f.write(pdf_resp.content)
            print("Saved to ACTA_Action_Plan.pdf")

            # Test 4: Dispatch Plan
            print("\n4. Testing /api/v1/simulation/dispatch endpoint...")
            dispatch_resp = await client.post("/api/v1/simulation/dispatch", json=sim_data)
            dispatch_resp.raise_for_status()
            print(f"Dispatch completed: {dispatch_resp.json()}")

            print("\nAll backend tests passed successfully!")
            
        except Exception as e:
            print(f"\nError during testing: {e}")

if __name__ == "__main__":
    asyncio.run(test_backend())
