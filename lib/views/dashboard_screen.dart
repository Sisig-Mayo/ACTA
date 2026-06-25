/// ACTA Frontend — LGU Operator Dashboard Screen
/// =================================================
/// Responsive three-panel layout optimized for disaster response operators:
///   Left:   Parameter control panel (wind, rain, time-to-impact slider)
///   Center: Geospatial vector map canvas (505 Manila barangays)
///   Right:  Explainability Card + chronological task list
///
/// Target Branch : feature/frontend-dashboard
/// Commit        : feat(frontend): build responsive layout controls and map visualization canvas stubs
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/simulation_models.dart';
import 'widgets/control_panel.dart';
import 'widgets/explainability_card.dart';

// -----------------------------------------------------------
// State Providers
// -----------------------------------------------------------

/// Current simulation parameters managed by the control panel.
final simulationParamsProvider = StateProvider<SimulationInput>(
  (ref) => const SimulationInput(
    windSpeedKph: 80.0,
    precipitation24hMm: 200.0,
    preparationWindowHours: 36,
    stormTrackPoints: [
      [120.98, 14.60],
      [120.95, 14.55],
      [120.90, 14.50],
    ],
  ),
);

/// Simulation output state — null until a simulation is run.
final simulationOutputProvider = StateProvider<SimulationOutput?>((ref) => null);

/// Loading state for the simulation request.
final isLoadingProvider = StateProvider<bool>((ref) => false);

/// Error message state.
final errorMessageProvider = StateProvider<String?>((ref) => null);

// -----------------------------------------------------------
// Dashboard Screen
// -----------------------------------------------------------

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  final MapController _mapController = MapController();

  /// Execute the simulation against the backend API.
  Future<void> _runSimulation() async {
    final params = ref.read(simulationParamsProvider);
    ref.read(isLoadingProvider.notifier).state = true;
    ref.read(errorMessageProvider.notifier).state = null;

    try {
      final response = await _dio.post(
        '/api/v1/simulation/run',
        data: params.toJson(),
      );

      final output = SimulationOutput.fromJson(
        response.data as Map<String, dynamic>,
      );

      ref.read(simulationOutputProvider.notifier).state = output;
    } on DioException catch (e) {
      ref.read(errorMessageProvider.notifier).state =
          e.response?.data?['detail']?.toString() ??
              'Connection error: ${e.message}';
    } catch (e) {
      ref.read(errorMessageProvider.notifier).state = 'Unexpected error: $e';
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final output = ref.watch(simulationOutputProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final errorMsg = ref.watch(errorMessageProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive: stack vertically on narrow screens.
    final isWide = screenWidth > 1200;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.shield_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('ACTA'),
            const SizedBox(width: 8),
            Text(
              '— Decision-to-Action Engine',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (output != null)
            _SeverityBadge(severity: output.severityTier),
          const SizedBox(width: 16),
        ],
      ),
      body: isWide
          ? _buildWideLayout(output, isLoading, errorMsg)
          : _buildNarrowLayout(output, isLoading, errorMsg),
    );
  }

  /// Wide layout: three-column horizontal split.
  Widget _buildWideLayout(
    SimulationOutput? output,
    bool isLoading,
    String? errorMsg,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Control Panel
        SizedBox(
          width: 340,
          child: ControlPanel(
            onRunSimulation: _runSimulation,
            isLoading: isLoading,
          ),
        ),

        // Center: Map Canvas
        Expanded(
          flex: 3,
          child: _buildMapCanvas(output),
        ),

        // Right: Results Panel
        SizedBox(
          width: 400,
          child: _buildResultsPanel(output, isLoading, errorMsg),
        ),
      ],
    );
  }

  /// Narrow layout: vertical stack.
  Widget _buildNarrowLayout(
    SimulationOutput? output,
    bool isLoading,
    String? errorMsg,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ControlPanel(
            onRunSimulation: _runSimulation,
            isLoading: isLoading,
          ),
          SizedBox(
            height: 400,
            child: _buildMapCanvas(output),
          ),
          _buildResultsPanel(output, isLoading, errorMsg),
        ],
      ),
    );
  }

  /// Geospatial map canvas centered on Manila.
  Widget _buildMapCanvas(SimulationOutput? output) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2E36), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(14.5995, 120.9842), // Manila center
              initialZoom: 13.0,
              minZoom: 10.0,
              maxZoom: 18.0,
            ),
            children: [
              // Base tile layer — dark style.
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.acta.app',
              ),

              // Barangay boundary polygons would be rendered here
              // once backend GeoJSON endpoint is connected.
              // PolygonLayer(polygons: _buildBarangayPolygons(output)),

              // Impact markers for impacted barangays.
              if (output != null)
                MarkerLayer(
                  markers: output.impactedBarangays.map((b) {
                    return Marker(
                      point: LatLng(b.centroid[1], b.centroid[0]),
                      width: 24,
                      height: 24,
                      child: _ZoneMarker(status: b.zoneStatus),
                    );
                  }).toList(),
                ),
            ],
          ),

          // Map overlay legend.
          Positioned(
            bottom: 16,
            left: 16,
            child: _buildMapLegend(),
          ),

          // Zoom info badge.
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Manila Metropolitan Area',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Map legend showing zone color codes.
  Widget _buildMapLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Zone Status',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          _legendItem(const Color(0xFFEF5350), 'Red — Active Danger'),
          const SizedBox(height: 4),
          _legendItem(const Color(0xFFFFB74D), 'Yellow — Elevated Risk'),
          const SizedBox(height: 4),
          _legendItem(const Color(0xFF66BB6A), 'Green — No Threat'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
      ],
    );
  }

  /// Results panel with Explainability Card and task list.
  Widget _buildResultsPanel(
    SimulationOutput? output,
    bool isLoading,
    String? errorMsg,
  ) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2E36), width: 1),
      ),
      child: isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Running simulation...'),
                ],
              ),
            )
          : errorMsg != null
              ? _buildErrorState(errorMsg)
              : output == null
                  ? _buildEmptyState()
                  : _buildResultsList(output),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined, size: 48, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Configure parameters and run a simulation',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'Results will appear here',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFFF5252)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFF5252), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(SimulationOutput output) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary stats row.
        _buildStatsRow(output),
        const SizedBox(height: 16),

        // Explainability Card.
        ExplainabilityCardWidget(card: output.explainabilityCard),
        const SizedBox(height: 20),

        // Task list header.
        Row(
          children: [
            const Icon(Icons.checklist, size: 18, color: Color(0xFF00BFA6)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Action Timeline',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${output.taskList.length} tasks',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Task items.
        ...output.taskList.map((task) => _TaskTile(task: task)),
      ],
    );
  }

  Widget _buildStatsRow(SimulationOutput output) {
    return Row(
      children: [
        _StatChip(
          label: 'RED',
          value: '${output.redZoneCount}',
          color: const Color(0xFFEF5350),
        ),
        const SizedBox(width: 8),
        _StatChip(
          label: 'YELLOW',
          value: '${output.yellowZoneCount}',
          color: const Color(0xFFFFB74D),
        ),
        const SizedBox(width: 8),
        _StatChip(
          label: 'Tasks',
          value: '${output.taskList.length}',
          color: const Color(0xFF00BFA6),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------
// Supporting Widgets
// -----------------------------------------------------------

/// Colored severity badge in the app bar.
class _SeverityBadge extends StatelessWidget {
  final SeverityTier severity;

  const _SeverityBadge({required this.severity});

  Color get _color => switch (severity) {
        SeverityTier.critical => const Color(0xFFEF5350),
        SeverityTier.high => const Color(0xFFFF7043),
        SeverityTier.moderate => const Color(0xFFFFB74D),
        SeverityTier.low => const Color(0xFF66BB6A),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        severity.label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Zone status marker for the map.
class _ZoneMarker extends StatelessWidget {
  final ZoneStatus status;

  const _ZoneMarker({required this.status});

  Color get _color => switch (status) {
        ZoneStatus.red => const Color(0xFFEF5350),
        ZoneStatus.yellow => const Color(0xFFFFB74D),
        ZoneStatus.green => const Color(0xFF66BB6A),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

/// Compact stat chip.
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual task list tile.
class _TaskTile extends StatelessWidget {
  final TaskItem task;

  const _TaskTile({required this.task});

  Color get _priorityColor => switch (task.priority) {
        'CRITICAL' => const Color(0xFFEF5350),
        'HIGH' => const Color(0xFFFF7043),
        'MEDIUM' => const Color(0xFFFFB74D),
        _ => const Color(0xFF66BB6A),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D23),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: _priorityColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _priorityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.priority,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _priorityColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.schedule, size: 13, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'T-${task.deadlineHours}h',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.action,
            style: const TextStyle(fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}
