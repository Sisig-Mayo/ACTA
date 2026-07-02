import 'simulation_models.dart';

SimulationOutput buildDemoSimulationOutput() {
  return SimulationOutput(
    severityTier: SeverityTier.high,
    preparationWindowHours: 24,
    impactedBarangays: const [
      BarangayImpact(
        barangayName: 'Tondo',
        district: 'District I',
        zoneStatus: ZoneStatus.red,
        coveragePct: 72,
        centroid: [120.966, 14.617],
      ),
      BarangayImpact(
        barangayName: 'Sampaloc',
        district: 'District IV',
        zoneStatus: ZoneStatus.yellow,
        coveragePct: 48,
        centroid: [120.995, 14.603],
      ),
      BarangayImpact(
        barangayName: 'Pandacan',
        district: 'District VI',
        zoneStatus: ZoneStatus.yellow,
        coveragePct: 44,
        centroid: [121.006, 14.590],
      ),
      BarangayImpact(
        barangayName: 'Paco',
        district: 'District V',
        zoneStatus: ZoneStatus.yellow,
        coveragePct: 39,
        centroid: [120.996, 14.580],
      ),
      BarangayImpact(
        barangayName: 'Malate',
        district: 'District V',
        zoneStatus: ZoneStatus.green,
        coveragePct: 18,
        centroid: [120.989, 14.571],
      ),
    ],
    taskList: const [
      TaskItem(
        priority: 'HIGH',
        action:
            'Pre-position rescue boats and medical triage teams near Tondo evacuation corridors.',
        deadlineHours: 4,
        category: 'Resource Deployment',
      ),
      TaskItem(
        priority: 'HIGH',
        action:
            'Activate backup evacuation centers for low-lying barangays with limited shelter capacity.',
        deadlineHours: 6,
        category: 'Evacuation',
      ),
      TaskItem(
        priority: 'MEDIUM',
        action:
            'Dispatch drainage inspection teams to Sampaloc, Pandacan, and Paco pumping catchments.',
        deadlineHours: 8,
        category: 'Infrastructure',
      ),
      TaskItem(
        priority: 'MEDIUM',
        action:
            'Issue targeted SMS advisories for households inside red and yellow risk zones.',
        deadlineHours: 12,
        category: 'Public Communication',
      ),
    ],
    explainabilityCard: const ExplainabilityCard(
      summary:
          'ACTA identified a high flood preparedness scenario concentrated around Tondo and river-adjacent districts.',
      riskNarrative:
          'Projected rainfall and drainage constraints increase flood exposure in dense residential areas, while evacuation access remains the key operational constraint.',
      actionRationale:
          'The plan prioritizes early resource staging, shelter readiness, drainage response, and targeted public advisories before conditions degrade.',
      confidenceNote:
          'Demo scenario uses representative Manila risk assumptions for prototype walkthroughs when the live API is unavailable.',
    ),
    metadata: const {
      'run_id': 'demo-run',
      'source': 'demo',
      'confidence': 'prototype',
    },
  );
}
