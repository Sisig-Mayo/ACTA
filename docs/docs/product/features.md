# Features And Operator Value

ACTA helps Manila LGU operators move from a hazard scenario to an actionable
response plan. It is designed around flood preparedness workflows: understand
which barangays are at risk, see how much time remains, generate prioritized
tasks, review AI-assisted reasoning, and export or dispatch a master action
plan.

## What ACTA Does

| Capability | What operators can do | Current implementation |
| --- | --- | --- |
| Command Center | Review Manila flood risk, operational indicators, alerts, and priority areas from a single dashboard. | Implemented in Flutter with barangay map rendering and baseline/static operational data. |
| Simulation Setup | Configure a hazard scenario with wind speed, 24-hour rainfall, preparation window, storm track, and storm radius. | Implemented for hydrologic flood simulations. Earthquake and virus outbreak are selectable profiles but do not yet have dedicated backend risk models. |
| Async Simulation Runs | Submit a scenario and monitor progress while the backend computes risk and action data. | Implemented through `POST /api/v1/simulation/run`, status polling, and stored `simulation_runs` records. |
| Barangay Risk Scoring | Classify impacted barangays into green, yellow, and red zones. | Implemented through the risk pipeline and `barangay_risk_scores`; UI currently maps stored risk scores into impact rows. |
| Time-Decayed Tasks | Generate task deadlines based on the remaining preparation window. | Implemented through the decay engine and included in simulation results. |
| AI Action Planning | Turn simulation inputs, risk scores, infrastructure state, and template tasks into a structured action plan. | Implemented with Gemini when configured, with a deterministic fallback when the LLM is unavailable. |
| Explainability Cards | Show why the plan was generated and what the main risk drivers are. | Implemented in backend response models and frontend cards. |
| Master Action Plan | Review, approve, export, and dispatch a response plan. | PDF generation and dispatch endpoints exist; frontend supports export/approval flows with local fallback behavior. |
| Resource Management | View response assets by type, layer, status, and location. | Implemented as a static dashboard view; it is not yet backed by a live resource inventory API. |
| Flood-Aware Routing | Compute a route that avoids high-cost or flooded road segments. | Backend API and pgRouting service exist; full operator workflow integration is still an improvement area. |
| LLM Audit Snapshot | Inspect the exact structured context sent to the LLM for a completed run. | Implemented through `GET /api/v1/simulation/llm-context/{run_id}`. |

## Primary Workflow

1. The operator opens the Command Center to review current risk context.
2. The operator starts a hydrologic flood simulation and enters hazard
   parameters.
3. ACTA stores the run, computes barangay-level risk, updates route costs, and
   creates time-sensitive response tasks.
4. The AI pipeline assembles an auditable context document and generates an
   action plan when Gemini is configured.
5. The operator reviews the AI Action Plan, including rationale and priority
   distribution.
6. The operator finalizes the Master Action Plan, exports a PDF, and dispatches
   the plan through the backend dispatch hook.

## What Makes The System Useful

- **Spatial grounding:** decisions are tied to Manila barangay boundaries,
  flood risk tiers, route costs, and resource locations rather than generic
  text output.
- **Time awareness:** action deadlines change with the preparation window, so a
  6-hour scenario produces different operational urgency than a 72-hour
  scenario.
- **Auditable AI:** the LLM receives a structured context snapshot that can be
  retrieved after the run, making generated plans easier to inspect and debug.
- **Operational handoff:** outputs are shaped for operator review, PDF export,
  approval, and dispatch instead of stopping at a model response.
- **Fallback behavior:** deterministic templates keep the workflow usable when
  Gemini is not configured or fails.

## Current Gaps And Improvement Targets

| Area | Gap | Recommended next action |
| --- | --- | --- |
| Live resources | Resource management uses static frontend data. | Add a `resources` table, CRUD API, and frontend provider so map markers and tables reflect real inventory. |
| Multi-hazard support | Earthquake and virus outbreak profiles are visible in the UI but the backend risk model is flood-oriented. | Either hide disabled profiles or implement separate backend models, schemas, and explainability prompts for each hazard. |
| Result geography | Simulation results currently return a placeholder centroid for impacted barangays. | Join stored barangay centroids in `GET /simulation/results/{run_id}` so maps and exports can locate each affected area accurately. |
| Routing workflow | Safe-route APIs exist but are not yet a complete operator flow. | Add frontend route selection, display route geometry, and connect route cost updates to the active simulation run. |
| Dispatch auditability | Dispatch returns a manifest, but long-term tracking is not yet explicit in docs or UI. | Store dispatch events with recipient, timestamp, status, and plan version for audit and incident review. |
| Settings and account recovery | Settings and password reset entry points are present but not implemented as complete workflows. | Add implemented screens or disable controls until the workflows exist. |
| Real telemetry | The data pipeline can ingest hazard data, but operator-facing freshness and source status are not prominent. | Surface last-ingested timestamps and data source health in the Command Center. |

## Near-Term Product Priorities

The highest-value next step is to make the existing flood workflow more real-time
and auditable before expanding to more hazards. Prioritize live resource data,
accurate barangay centroids, route visualization, and dispatch history. These
changes improve the current operational loop without introducing a second hazard
model or a broader data contract.
