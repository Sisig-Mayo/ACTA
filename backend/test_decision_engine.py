import asyncio
import os
import sys

from dotenv import load_dotenv

sys.path.insert(0, os.getcwd())
load_dotenv(".env")

from app.models.simulation import SimulationInput
from app.services.risk_pipeline import run_simulation_pipeline
from app.core.supabase_client import get_supabase_client
import uuid

async def run_test():
    run_id = str(uuid.uuid4())
    print(f"Starting test simulation run: {run_id}")
    
    # Create the run in supabase to avoid errors in update_simulation_status
    client = get_supabase_client()
    if client:
        payload = {
            "id": run_id,
            "preparation_window_hours": 36,
            "status": "PENDING",
            "typhoon_parameters": {}
        }
        client.table("simulation_runs").insert(payload).execute()
    
    input_data = SimulationInput(
        wind_speed_kph=150.0,
        precipitation_24h_mm=300.0,
        preparation_window_hours=36,
        storm_track_points=[[120.98, 14.60], [120.95, 14.55]],
        storm_radius_km=50.0
    )
    
    await run_simulation_pipeline(run_id, input_data)
    
    print("\n--- RESULTS ---")
    if client:
        res = client.table("simulation_runs").select("*").eq("id", run_id).execute()
        if res.data:
            record = res.data[0]
            print(f"Status: {record.get('status')}")
            
            card = record.get("explainability_card", {})
            print(f"\nExplainability Card Rationale:\n{card.get('action_rationale')}")
            
            tasks = record.get("task_list", [])
            print(f"\nGenerated Dynamic Tasks ({len(tasks)}):")
            for t in tasks:
                print(f"- [{t.get('priority')}] {t.get('action')} (T-{t.get('deadline_hours')}h)")
        else:
            print("Failed to retrieve from Supabase.")

if __name__ == "__main__":
    asyncio.run(run_test())
