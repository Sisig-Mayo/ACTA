/// ACTA Frontend — Run Simulation Screen
/// ========================================
/// Displays the 4-step simulation progress stepper, a simulated
/// flood inundation map, simulation summary, and model progress.
/// Renders as content inside AppShell (no Scaffold).
///
/// Target Branch : feat/dashboard
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/simulation_state.dart';
import 'app_shell.dart';

// -----------------------------------------------------------
// Progress step index for animated model progress
// -----------------------------------------------------------

const _kManilaCtr = LatLng(14.5928, 120.9762);

const _modelSteps = [
  'Input Validation',
  'Hydrologic Modelling',
  'Inundation Mapping',
  'Risk Scoring',
  'Output Generation',
];

// Inundation depth circles (simulated flood depth overlay)
final _inundationCircles = [
  // > 2.0 m — deep red
  CircleMarker(point: const LatLng(14.6155, 120.9674), radius: 1400, color: const Color(0x88DC2626), borderColor: Colors.transparent, borderStrokeWidth: 0, useRadiusInMeter: true),
  // 1.0–2.0 m — red-orange
  CircleMarker(point: const LatLng(14.6050, 120.9810), radius: 1600, color: const Color(0x88F97316), borderColor: Colors.transparent, borderStrokeWidth: 0, useRadiusInMeter: true),
  // 0.5–1.0 m — amber
  CircleMarker(point: const LatLng(14.5980, 121.0000), radius: 1800, color: const Color(0x88F59E0B), borderColor: Colors.transparent, borderStrokeWidth: 0, useRadiusInMeter: true),
  // 0.2–0.5 m — yellow
  CircleMarker(point: const LatLng(14.5853, 121.0050), radius: 1500, color: const Color(0x88EAB308), borderColor: Colors.transparent, borderStrokeWidth: 0, useRadiusInMeter: true),
  // < 0.2 m — light blue
  CircleMarker(point: const LatLng(14.5660, 120.9863), radius: 2000, color: const Color(0x880EA5E9), borderColor: Colors.transparent, borderStrokeWidth: 0, useRadiusInMeter: true),
];

// -----------------------------------------------------------
// Run Simulation Content
// -----------------------------------------------------------

class RunSimulationContent extends ConsumerStatefulWidget {
  const RunSimulationContent({super.key});

  @override
  ConsumerState<RunSimulationContent> createState() =>
      _RunSimulationContentState();
}

class _RunSimulationContentState
    extends ConsumerState<RunSimulationContent> {
  Timer? _stepTimer;
  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    _startProgress();
  }

  void _startProgress() {
    _stepTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_stepIndex < _modelSteps.length - 1) {
          _stepIndex++;
        } else {
          t.cancel();
          // If the API has already returned, navigate to results
          final state = ref.read(simulationRunStateProvider);
          if (state == SimulationRunState.completed ||
              state == SimulationRunState.error) {
            _goToResults();
          }
        }
      });
    });
  }

  void _goToResults() {
    ref.read(runSimulationActiveProvider.notifier).state = false;
    ref.read(shellIndexProvider.notifier).state = 2;
  }

  void _cancelSimulation() {
    _stepTimer?.cancel();
    ref.read(simulationRunStateProvider.notifier).state =
        SimulationRunState.idle;
    ref.read(runSimulationActiveProvider.notifier).state = false;
    ref.read(shellIndexProvider.notifier).state = 1;
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runState = ref.watch(simulationRunStateProvider);
    final snapshot = ref.watch(simulationInputSnapshotProvider);

    // Auto-navigate once complete and steps done
    if (runState == SimulationRunState.completed &&
        _stepIndex >= _modelSteps.length - 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToResults());
    }

    return Column(
      children: [
        PageHeader(
          title: 'Run Simulation',
          subtitle: 'Simulation › Run Simulation',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Stepper
                _StepperBar(currentStep: 1),
                const SizedBox(height: 20),

                // Main content: map + right panels
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Map
                    Expanded(
                      flex: 3,
                      child: _MapCard(stepIndex: _stepIndex),
                    ),
                    const SizedBox(width: 16),
                    // Right panels
                    SizedBox(
                      width: 260,
                      child: Column(
                        children: [
                          _SimSummaryCard(snapshot: snapshot),
                          const SizedBox(height: 12),
                          _ModelProgressCard(stepIndex: _stepIndex),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // What happens next banner
                _WhatNextBanner(onCancel: _cancelSimulation),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------
// Stepper Bar
// -----------------------------------------------------------

class _StepperBar extends StatelessWidget {
  final int currentStep;

  const _StepperBar({required this.currentStep});

  static const _steps = [
    ('Configure', 'Parameters set'),
    ('Run Simulation', 'In progress'),
    ('Review Results', 'Pending'),
    ('AI Action Plan', 'Pending'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: _steps.asMap().entries.map((e) {
          final i = e.key;
          final step = e.value;
          final isDone = i < currentStep;
          final isActive = i == currentStep;
          final isPending = i > currentStep;

          Widget badge;
          if (isDone) {
            badge = Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                  color: Color(0xFF16A34A), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            );
          } else if (isActive) {
            badge = Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF16A34A), width: 2),
              ),
              child: Center(
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            );
          } else {
            badge = Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: Center(
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            );
          }

          return Expanded(
            child: Row(
              children: [
                Row(
                  children: [
                    badge,
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.$1,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isPending
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF111827))),
                        Text(step.$2,
                            style: TextStyle(
                                fontSize: 10,
                                color: isActive
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF9CA3AF))),
                      ],
                    ),
                  ],
                ),
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: const Color(0xFFE5E7EB),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// -----------------------------------------------------------
// Map Card
// -----------------------------------------------------------

class _MapCard extends StatelessWidget {
  final int stepIndex;
  const _MapCard({required this.stepIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text('Simulated Flood Inundation Map (24 Hours)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827))),
          ),
          SizedBox(
            height: 380,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  child: FlutterMap(
                    options: const MapOptions(
                      initialCenter: _kManilaCtr,
                      initialZoom: 12,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.acta.app',
                      ),
                      CircleLayer(circles: _inundationCircles),
                    ],
                  ),
                ),
                // Depth Legend
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Flood Depth (m)',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151))),
                        const SizedBox(height: 6),
                        _depthItem(const Color(0xFFDC2626), '> 2.0 m'),
                        _depthItem(const Color(0xFFF97316), '1.0 – 2.0 m'),
                        _depthItem(const Color(0xFFF59E0B), '0.5 – 1.0 m'),
                        _depthItem(const Color(0xFFEAB308), '0.2 – 0.5 m'),
                        _depthItem(const Color(0xFF0EA5E9), '< 0.2 m'),
                        _depthItem(const Color(0xFFE5E7EB), 'No Data'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 13, color: Color(0xFF9CA3AF)),
                SizedBox(width: 6),
                Text(
                  'This map shows simulated flood depth based on the parameters provided.',
                  style:
                      TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _depthItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10, height: 10,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF374151))),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Simulation Summary Card
// -----------------------------------------------------------

class _SimSummaryCard extends StatelessWidget {
  final Map<String, dynamic> snapshot;
  const _SimSummaryCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    String get(String key, String fallback) =>
        snapshot[key]?.toString() ?? fallback;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Simulation Summary',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 10),
          _row(Icons.flood_outlined, 'Profile',
              get('profile', 'Hydrologic Flood')),
          _row(Icons.water_drop_outlined, 'Rainfall Volume',
              '${get('rainfall_mm', '120')} mm'),
          _row(Icons.air, 'Wind Speed',
              '${get('wind_kph', '65')} km/h'),
          _row(Icons.location_city_outlined, 'Affected District(s)',
              get('affected_districts', 'All Districts (NCR)')),
          _row(Icons.water_outlined, 'Pumping Stations',
              get('pumping_status', '3 Offline')),
          _row(Icons.directions_boat_outlined, 'Rescue Assets',
              get('rescue_assets', '12 Boats')),
          const Divider(height: 16, color: Color(0xFFE5E7EB)),
          _row(Icons.access_time, 'Start Time',
              _nowLabel()),
        ],
      ),
    );
  }

  String _nowLabel() {
    final now = DateTime.now();
    return '${_month(now.month)} ${now.day}, ${now.year}  ${_time(now)}';
  }

  String _month(int m) =>
      ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];

  String _time(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final min = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$min $ampm';
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF6B7280))),
          ),
          Flexible(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827)),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Model Progress Card
// -----------------------------------------------------------

class _ModelProgressCard extends StatelessWidget {
  final int stepIndex;
  const _ModelProgressCard({required this.stepIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Model Progress',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 10),
          ..._modelSteps.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            final isDone = i < stepIndex;
            final isActive = i == stepIndex;
            return _progressRow(s, isDone, isActive);
          }),
        ],
      ),
    );
  }

  Widget _progressRow(String label, bool isDone, bool isActive) {
    final color = isDone
        ? const Color(0xFF16A34A)
        : isActive
            ? const Color(0xFF0EA5E9)
            : const Color(0xFF9CA3AF);

    final statusText = isDone
        ? 'Completed'
        : isActive
            ? 'In progress ...'
            : 'Pending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isDone
                ? Icons.check_circle_outline
                : isActive
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF374151)))),
          Text(statusText,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// What Happens Next Banner
// -----------------------------------------------------------

class _WhatNextBanner extends StatelessWidget {
  final VoidCallback onCancel;
  const _WhatNextBanner({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline,
                color: Color(0xFF0EA5E9), size: 18),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What happens next?',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
                SizedBox(height: 2),
                Text(
                  'Once the simulation is complete, ACTA can generate an AI-prioritized action plan',
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 14, color: Color(0xFFDC2626)),
            label: const Text('Cancel Simulation',
                style: TextStyle(color: Color(0xFFDC2626))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}
