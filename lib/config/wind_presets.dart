/// ACTA — Wind Signal Presets (TCWS)
/// ====================================
/// Tropical Cyclone Wind Signal configuration constants.
/// Each signal maps to a specific sustained wind speed used
/// by the simulation engine.
///
/// These presets are independent of rainfall — wind and rainfall
/// are selected separately to reflect how PAGASA issues forecasts.
library;

import 'package:flutter/material.dart';

/// A single TCWS wind signal preset.
class WindPreset {
  /// Display label, e.g. "Signal 1".
  final String label;

  /// Signal number (1–5).
  final int signal;

  /// Sustained wind speed in km/h for this signal.
  final double windSpeedKph;

  /// Short description of the wind condition.
  final String description;

  /// Icon to display in the selector UI.
  final IconData icon;

  const WindPreset({
    required this.label,
    required this.signal,
    required this.windSpeedKph,
    required this.description,
    required this.icon,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WindPreset &&
          runtimeType == other.runtimeType &&
          signal == other.signal;

  @override
  int get hashCode => signal.hashCode;
}

/// All available TCWS presets, ordered Signal 1 → 5.
const List<WindPreset> windPresets = [
  WindPreset(
    label: 'Signal 1',
    signal: 1,
    windSpeedKph: 50,
    description: 'Winds 30–60 km/h — Minimal damage expected',
    icon: Icons.air,
  ),
  WindPreset(
    label: 'Signal 2',
    signal: 2,
    windSpeedKph: 75,
    description: 'Winds 61–120 km/h — Minor structural damage',
    icon: Icons.air,
  ),
  WindPreset(
    label: 'Signal 3',
    signal: 3,
    windSpeedKph: 103,
    description: 'Winds 121–170 km/h — Moderate to heavy damage',
    icon: Icons.storm,
  ),
  WindPreset(
    label: 'Signal 4',
    signal: 4,
    windSpeedKph: 151,
    description: 'Winds 171–220 km/h — Severe structural damage',
    icon: Icons.storm,
  ),
  WindPreset(
    label: 'Signal 5',
    signal: 5,
    windSpeedKph: 200,
    description: 'Winds > 220 km/h — Catastrophic destruction',
    icon: Icons.thunderstorm,
  ),
];

/// Default wind preset: Signal 1 (50 km/h).
final WindPreset defaultWindPreset = windPresets[0];
