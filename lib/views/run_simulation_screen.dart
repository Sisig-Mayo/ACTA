/// ACTA Frontend — Run Simulation Screen
/// ========================================
/// Displays the 4-step simulation progress stepper with REAL
/// backend polling, a dynamic barangay flood map, simulation
/// summary, and model progress.
/// Renders as content inside AppShell (no Scaffold).
///
/// Target Branch : feat/dashboard
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/simulation_models.dart';
import '../models/simulation_state.dart';
import '../models/barangay_provider.dart';
import 'app_shell.dart';

// -----------------------------------------------------------
// Constants
// -----------------------------------------------------------

const _kManilaCtr = LatLng(14.5928, 120.9762);

const _modelSteps = [
  'Input Validation',
  'Hydrologic Modelling',
  'Inundation Mapping',
  'Risk Scoring',
  'Output Generation',
];

/// Maps progress_pct (0–100) to step index (0–4).
int _progressToStep(int pct) {
  if (pct < 20) return 0;
  if (pct < 50) return 1;
  if (pct < 70) return 2;
  if (pct < 90) return 3;
  return 4;
}

const _progressAnimationDuration = Duration(milliseconds: 900);
const _progressAnimationCurve = Curves.easeInOutCubic;

// -----------------------------------------------------------
// Run Simulation Content
// -----------------------------------------------------------

class RunSimulationContent extends ConsumerStatefulWidget {
  const RunSimulationContent({super.key});

  @override
  ConsumerState<RunSimulationContent> createState() =>
      _RunSimulationContentState();
}

class _RunSimulationContentState extends ConsumerState<RunSimulationContent> {
  Timer? _pollTimer;
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://acta-production.up.railway.app',
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    // Poll every 2 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollStatus();
    });
    // Also poll immediately
    _pollStatus();
  }

  Future<void> _pollStatus() async {
    final runId = ref.read(simulationRunIdProvider);
    if (runId == null) return;

    try {
      final response = await _dio.get('/api/v1/simulation/status/$runId');
      if (!mounted) return;

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String;
      final progressPct = (data['progress_pct'] as num?)?.toInt() ?? 0;

      ref.read(simulationProgressProvider.notifier).state = progressPct;

      if (status == 'COMPLETED') {
        _pollTimer?.cancel();
        // Fetch full results
        await _fetchResults(runId);
      } else if (status == 'FAILED') {
        _pollTimer?.cancel();
        ref.read(simulationErrorProvider.notifier).state =
            data['error_message']?.toString() ?? 'Simulation failed';
        ref.read(simulationRunStateProvider.notifier).state =
            SimulationRunState.error;
      }
    } catch (e) {
      print('Polling error: $e');
      // Silently retry on next poll cycle
    }
  }

  Future<void> _fetchResults(String runId) async {
    try {
      final response = await _dio.get('/api/v1/simulation/results/$runId');
      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        ref.read(simulationResultProvider.notifier).state =
            SimulationOutput.fromJson(response.data as Map<String, dynamic>);
      }
      ref.read(simulationRunStateProvider.notifier).state =
          SimulationRunState.completed;
    } catch (e) {
      ref.read(simulationErrorProvider.notifier).state =
          'Failed to fetch results: $e';
      ref.read(simulationRunStateProvider.notifier).state =
          SimulationRunState.error;
    }
  }

  void _goToResults() {
    ref.read(runSimulationActiveProvider.notifier).state = false;
    ref.read(shellIndexProvider.notifier).state = 2;
  }

  void _cancelSimulation() {
    _pollTimer?.cancel();
    ref.read(simulationRunStateProvider.notifier).state =
        SimulationRunState.idle;
    ref.read(runSimulationActiveProvider.notifier).state = false;
    ref.read(shellIndexProvider.notifier).state = 1;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runState = ref.watch(simulationRunStateProvider);
    final snapshot = ref.watch(simulationInputSnapshotProvider);
    final progressPct = ref.watch(simulationProgressProvider);
    final stepIndex = _progressToStep(progressPct);
    final barangaysAsync = ref.watch(barangayPolygonsProvider);
    final simResult = ref.watch(simulationResultProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Auto-navigate once complete
    if (runState == SimulationRunState.completed) {
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
                // Main content: map + right panels (stacked on mobile)
                if (isMobile) ...[
                  _MapCard(
                    progressPct: progressPct,
                    barangaysAsync: barangaysAsync,
                    simResult: simResult,
                  ),
                  const SizedBox(height: 16),
                  _SimSummaryCard(snapshot: snapshot),
                  const SizedBox(height: 12),
                  _ModelProgressCard(
                    stepIndex: stepIndex,
                    progressPct: progressPct,
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Map
                      Expanded(
                        flex: 3,
                        child: _MapCard(
                          progressPct: progressPct,
                          barangaysAsync: barangaysAsync,
                          simResult: simResult,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right panels
                      SizedBox(
                        width: 260,
                        child: Column(
                          children: [
                            _SimSummaryCard(snapshot: snapshot),
                            const SizedBox(height: 12),
                            _ModelProgressCard(
                              stepIndex: stepIndex,
                              progressPct: progressPct,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Error banner
                if (runState == SimulationRunState.error)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E3A8A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFF1E3A8A),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ref.watch(simulationErrorProvider) ??
                                'An error occurred',
                            style: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

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
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Row(
              children: _steps.asMap().entries.map((e) {
                final i = e.key;
                final isDone = i < currentStep;
                final isActive = i == currentStep;

                Widget badge;
                if (isDone) {
                  badge = Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1D4ED8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  );
                } else if (isActive) {
                  badge = Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1D4ED8),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                } else {
                  badge = Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: Row(
                    children: [
                      badge,
                      if (i < _steps.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            color: isDone
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Text(
              'Step ${currentStep + 1} of 4: ${_steps[currentStep].$1} — ${_steps[currentStep].$2}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

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
                color: Color(0xFF1D4ED8),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            );
          } else if (isActive) {
            badge = Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1D4ED8), width: 2),
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                        Text(
                          step.$1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isPending
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          step.$2,
                          style: TextStyle(
                            fontSize: 10,
                            color: isActive
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
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
  final int progressPct;
  final AsyncValue<List<BarangayPolygon>> barangaysAsync;
  final SimulationOutput? simResult;

  const _MapCard({
    required this.progressPct,
    required this.barangaysAsync,
    this.simResult,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, String>? riskMap;
    if (simResult != null) {
      riskMap = {};
      for (final b in simResult!.impactedBarangays) {
        riskMap[b.barangayName] = b.zoneStatus.name;
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Text(
                  'Simulated Flood Inundation Map',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: progressPct.toDouble()),
                  duration: _progressAnimationDuration,
                  curve: _progressAnimationCurve,
                  builder: (context, animatedPct, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${animatedPct.round()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0EA5E9),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progressPct / 100.0),
                duration: _progressAnimationDuration,
                curve: _progressAnimationCurve,
                builder: (context, animatedValue, _) {
                  return LinearProgressIndicator(
                    value: animatedValue.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressPct >= 100
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF0EA5E9),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 380,
            child: ClipRRect(
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
                  barangaysAsync.when(
                    data: (barangays) => PolygonLayer(
                      polygons: buildBarangayMapPolygons(
                        barangays,
                        riskMap: riskMap,
                      ),
                    ),
                    loading: () => const PolygonLayer(polygons: <Polygon>[]),
                    error: (_, __) => const PolygonLayer(polygons: <Polygon>[]),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 13,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 6),
                Text(
                  simResult == null
                      ? 'Barangay polygons will be colored once simulation completes.'
                      : 'Map updated with simulation risk layers.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
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
          const Text(
            'Simulation Summary',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          _row(
            Icons.flood_outlined,
            'Profile',
            get('profile', 'Hydrologic Flood'),
          ),
          _row(
            Icons.water_drop_outlined,
            'Rainfall Volume',
            '${get('rainfall_mm', '120')} mm',
          ),
          _row(Icons.air, 'Wind Speed', '${get('wind_kph', '65')} km/h'),
          _row(Icons.location_city_outlined, 'Coverage', 'All 897 Barangays'),
          const Divider(height: 16, color: Color(0xFFE5E7EB)),
          _row(Icons.access_time, 'Start Time', _nowLabel()),
        ],
      ),
    );
  }

  String _nowLabel() {
    final now = DateTime.now();
    return '${_month(now.month)} ${now.day}, ${now.year}  ${_time(now)}';
  }

  String _month(int m) => [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];

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
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.right,
            ),
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
  final int progressPct;
  const _ModelProgressCard({
    required this.stepIndex,
    required this.progressPct,
  });

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
          Row(
            children: [
              const Text(
                'Model Progress',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progressPct.toDouble()),
                duration: _progressAnimationDuration,
                curve: _progressAnimationCurve,
                builder: (context, animatedPct, _) {
                  return Text(
                    '${animatedPct.round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0EA5E9),
                    ),
                  );
                },
              ),
            ],
          ),
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
        ? const Color(0xFF1D4ED8)
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
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
            ),
          ),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
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
            child: const Icon(
              Icons.info_outline,
              color: Color(0xFF0EA5E9),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What happens next?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Once the simulation is complete, ACTA can generate an AI-prioritized action plan',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 14, color: Color(0xFFDC2626)),
            label: const Text(
              'Cancel Simulation',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}
