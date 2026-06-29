/// ACTA — Rainfall Intensity Presets
/// ====================================
/// 24-hour rainfall intensity configuration constants.
/// Each preset maps to a specific accumulated rainfall value
/// used by the simulation engine.
///
/// These presets are independent of TCWS wind signals — wind and
/// rainfall are selected separately to reflect how PAGASA issues
/// the Heavy Rainfall Outlook independently of wind signals.
library;

import 'package:flutter/material.dart';

/// A single rainfall intensity preset.
class RainfallPreset {
  /// Display label, e.g. "Heavy".
  final String label;

  /// 24-hour accumulated rainfall in millimeters.
  final double rainfallMm;

  /// Short description of the rainfall condition.
  final String description;

  /// Icon to display in the selector UI.
  final IconData icon;

  const RainfallPreset({
    required this.label,
    required this.rainfallMm,
    required this.description,
    required this.icon,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RainfallPreset &&
          runtimeType == other.runtimeType &&
          label == other.label;

  @override
  int get hashCode => label.hashCode;
}

/// All available rainfall intensity presets.
const List<RainfallPreset> rainfallPresets = [
  RainfallPreset(
    label: 'Light',
    rainfallMm: 25,
    description: 'Up to 25 mm — Minimal flood risk',
    icon: Icons.grain,
  ),
  RainfallPreset(
    label: 'Heavy',
    rainfallMm: 75,
    description: 'Up to 75 mm — Moderate flood risk in low areas',
    icon: Icons.water_drop,
  ),
  RainfallPreset(
    label: 'Intense',
    rainfallMm: 150,
    description: 'Up to 150 mm — Significant flooding likely',
    icon: Icons.water_drop_outlined,
  ),
  RainfallPreset(
    label: 'Torrential',
    rainfallMm: 250,
    description: 'Up to 250 mm — Widespread severe flooding',
    icon: Icons.flood,
  ),
];

/// Default rainfall preset: Heavy (75 mm).
final RainfallPreset defaultRainfallPreset = rainfallPresets[1];
