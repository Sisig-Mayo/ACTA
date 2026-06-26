/// ACTA Frontend — Shared Simulation State
/// ==========================================
/// Providers shared across SimulationSetup, RunSimulation,
/// and AiActionPlan screens to coordinate the simulation
/// lifecycle without circular imports.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'simulation_models.dart';

// -----------------------------------------------------------
// Enums
// -----------------------------------------------------------

enum SimulationRunState { idle, running, completed, error }

enum SimProfile { hydrologicFlood, earthquake, virusOutbreak }

extension SimProfileLabel on SimProfile {
  String get label => switch (this) {
        SimProfile.hydrologicFlood => 'Hydrologic Flood',
        SimProfile.earthquake => 'Earthquake',
        SimProfile.virusOutbreak => 'Virus Outbreak',
      };
}

// -----------------------------------------------------------
// Providers
// -----------------------------------------------------------

/// Currently selected simulation profile.
final simProfileProvider =
    StateProvider<SimProfile>((ref) => SimProfile.hydrologicFlood);

/// Simulation run lifecycle state.
final simulationRunStateProvider =
    StateProvider<SimulationRunState>((ref) => SimulationRunState.idle);

/// The result of the last completed simulation.
final simulationResultProvider =
    StateProvider<SimulationOutput?>((ref) => null);

/// Error message from the last failed simulation.
final simulationErrorProvider = StateProvider<String?>((ref) => null);

/// Raw simulation input parameters (for display in Run screen summary).
final simulationInputSnapshotProvider =
    StateProvider<Map<String, dynamic>>((ref) => {});

/// The run_id returned by the backend for the current simulation.
final simulationRunIdProvider = StateProvider<String?>((ref) => null);

/// Real-time progress percentage (0–100) from backend polling.
final simulationProgressProvider = StateProvider<int>((ref) => 0);
