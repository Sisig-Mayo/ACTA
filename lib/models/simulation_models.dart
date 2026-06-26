/// ACTA Frontend — Simulation Data Models
/// ==========================================
/// Dart data classes mirroring the backend Pydantic schemas.
/// Used for JSON deserialization and state management across
/// the Flutter dashboard.
///
/// Target Branch : feature/frontend-dashboard
/// Commit        : feat(frontend): add simulation data models
library;

// -----------------------------------------------------------
// Enums
// -----------------------------------------------------------

/// Threat severity classification tiers.
enum SeverityTier {
  low,
  moderate,
  high,
  critical;

  /// Parse from JSON string value.
  static SeverityTier fromJson(String value) {
    return SeverityTier.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => SeverityTier.moderate,
    );
  }

  /// Display-friendly label.
  String get label => name[0].toUpperCase() + name.substring(1);
}

/// Barangay risk zone designations.
enum ZoneStatus {
  green,
  yellow,
  red;

  static ZoneStatus fromJson(String value) {
    return ZoneStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ZoneStatus.green,
    );
  }
}

// -----------------------------------------------------------
// Simulation Input
// -----------------------------------------------------------

/// Parameters sent to the backend simulation endpoint.
class SimulationInput {
  final double windSpeedKph;
  final double precipitation24hMm;
  final int preparationWindowHours;
  final List<List<double>> stormTrackPoints;

  const SimulationInput({
    required this.windSpeedKph,
    required this.precipitation24hMm,
    required this.preparationWindowHours,
    required this.stormTrackPoints,
  });

  Map<String, dynamic> toJson() => {
        'wind_speed_kph': windSpeedKph,
        'precipitation_24h_mm': precipitation24hMm,
        'preparation_window_hours': preparationWindowHours,
        'storm_track_points': stormTrackPoints,
      };
}

// -----------------------------------------------------------
// Response Models
// -----------------------------------------------------------

/// Impact assessment for a single barangay.
class BarangayImpact {
  final String barangayName;
  final String district;
  final ZoneStatus zoneStatus;
  final double coveragePct;
  final List<double> centroid;

  const BarangayImpact({
    required this.barangayName,
    required this.district,
    required this.zoneStatus,
    required this.coveragePct,
    required this.centroid,
  });

  factory BarangayImpact.fromJson(Map<String, dynamic> json) {
    return BarangayImpact(
      barangayName: json['barangay_name'] as String,
      district: json['district'] as String,
      zoneStatus: ZoneStatus.fromJson(json['zone_status'] as String),
      coveragePct: (json['coverage_pct'] as num).toDouble(),
      centroid: (json['centroid'] as List).map((e) => (e as num).toDouble()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'barangay_name': barangayName,
        'district': district,
        'zone_status': zoneStatus.name.toUpperCase(),
        'coverage_pct': coveragePct,
        'centroid': centroid,
      };
}

/// A single time-decayed action item.
class TaskItem {
  final String priority;
  final String action;
  final int deadlineHours;
  final String category;

  const TaskItem({
    required this.priority,
    required this.action,
    required this.deadlineHours,
    required this.category,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      priority: json['priority'] as String,
      action: json['action'] as String,
      deadlineHours: json['deadline_hours'] as int,
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'priority': priority,
        'action': action,
        'deadline_hours': deadlineHours,
        'category': category,
      };
}

/// Gemini-generated plain-language explanation.
class ExplainabilityCard {
  final String summary;
  final String riskNarrative;
  final String actionRationale;
  final String confidenceNote;

  const ExplainabilityCard({
    required this.summary,
    required this.riskNarrative,
    required this.actionRationale,
    required this.confidenceNote,
  });

  factory ExplainabilityCard.fromJson(Map<String, dynamic> json) {
    return ExplainabilityCard(
      summary: json['summary'] as String,
      riskNarrative: json['risk_narrative'] as String,
      actionRationale: json['action_rationale'] as String,
      confidenceNote: json['confidence_note'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'risk_narrative': riskNarrative,
        'action_rationale': actionRationale,
        'confidence_note': confidenceNote,
      };
}

/// Complete simulation response from the backend.
class SimulationOutput {
  final SeverityTier severityTier;
  final int preparationWindowHours;
  final List<BarangayImpact> impactedBarangays;
  final List<TaskItem> taskList;
  final ExplainabilityCard explainabilityCard;
  final Map<String, dynamic> metadata;

  const SimulationOutput({
    required this.severityTier,
    required this.preparationWindowHours,
    required this.impactedBarangays,
    required this.taskList,
    required this.explainabilityCard,
    required this.metadata,
  });

  factory SimulationOutput.fromJson(Map<String, dynamic> json) {
    return SimulationOutput(
      severityTier: SeverityTier.fromJson(json['severity_tier'] as String),
      preparationWindowHours: json['preparation_window_hours'] as int,
      impactedBarangays: (json['impacted_barangays'] as List)
          .map((e) => BarangayImpact.fromJson(e as Map<String, dynamic>))
          .toList(),
      taskList: (json['task_list'] as List)
          .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      explainabilityCard: ExplainabilityCard.fromJson(
        json['explainability_card'] as Map<String, dynamic>,
      ),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'severity_tier': severityTier.name.toUpperCase(),
        'preparation_window_hours': preparationWindowHours,
        'impacted_barangays': impactedBarangays.map((e) => e.toJson()).toList(),
        'task_list': taskList.map((e) => e.toJson()).toList(),
        'explainability_card': explainabilityCard.toJson(),
        'metadata': metadata,
      };

  /// Count of RED-zone barangays.
  int get redZoneCount =>
      impactedBarangays.where((b) => b.zoneStatus == ZoneStatus.red).length;

  /// Count of YELLOW-zone barangays.
  int get yellowZoneCount =>
      impactedBarangays.where((b) => b.zoneStatus == ZoneStatus.yellow).length;
}
