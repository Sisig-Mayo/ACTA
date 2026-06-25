/// ACTA Frontend — AI Action Plan Screen
/// ========================================
/// Displays the Gemini AI-generated priority action map,
/// overall plan summary, and AI narrative summary.
/// Renders as content inside AppShell (no Scaffold).
///
/// Target Branch : feat/dashboard
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/simulation_models.dart';
import '../models/simulation_state.dart';
import 'app_shell.dart';

// -----------------------------------------------------------
// Local providers
// -----------------------------------------------------------

/// Whether the plan has been approved.
final planApprovedProvider = StateProvider<bool>((ref) => false);

/// PDF export loading state.
final exportLoadingProvider = StateProvider<bool>((ref) => false);

const _kManilaCtr = LatLng(14.5928, 120.9762);

// Priority action circles for the map
final _actionCircles = [
  // Critical priority — deep red
  CircleMarker(point: const LatLng(14.6155, 120.9674), radius: 1600, color: const Color(0xAADC2626), borderColor: Colors.transparent, borderStrokeWidth: 0, useRadiusInMeter: true),
  CircleMarker(point: const LatLng(14.6050, 120.9750), radius: 1200, color: const Color(0xAADC2626), borderColor: Colors.transparent, borderStrokeWidth: 0, useRadiusInMeter: true),
  // High priority — orange
  CircleMarker(point: const LatLng(14.5980, 121.0000), radius: 1800, color: const Color(0xAAF97316), borderColor: Colors.transparent, borderStrokeWidth: 0, useRadiusInMeter: true),
  CircleMarker(point: const LatLng(14.6000, 120.9800), radius: 1400, color: const Color(0xAAF97316), borderColor: Colors.transparent, borderStrokeWidth: 0, useRadiusInMeter: true),
  // Moderate priority — amber
  CircleMarker(point: const LatLng(14.5853, 121.0050), radius: 1600, color: const Color(0xAAF59E0B), borderColor: Colors.transparent, borderStrokeWidth: 0, useRadiusInMeter: true),
  CircleMarker(point: const LatLng(14.5920, 120.9900), radius: 1400, color: const Color(0xAAF59E0B), borderColor: Colors.transparent, borderStrokeWidth: 0, useRadiusInMeter: true),
  // Low priority — green
  CircleMarker(point: const LatLng(14.5660, 120.9863), radius: 2000, color: const Color(0xAA16A34A), borderColor: Colors.transparent, borderStrokeWidth: 0, useRadiusInMeter: true),
  CircleMarker(point: const LatLng(14.5750, 121.0100), radius: 1500, color: const Color(0xAA16A34A), borderColor: Colors.transparent, borderStrokeWidth: 0, useRadiusInMeter: true),
];

// Evacuation center markers
final _evacMarkers = [
  const LatLng(14.6050, 120.9600),
  const LatLng(14.5920, 121.0020),
  const LatLng(14.5750, 120.9880),
  const LatLng(14.5620, 121.0050),
  const LatLng(14.6210, 120.9940),
];

// Pumping station markers
final _pumpMarkers = [
  const LatLng(14.6100, 120.9720),
  const LatLng(14.5970, 120.9870),
  const LatLng(14.5850, 121.0010),
];

// -----------------------------------------------------------
// AI Action Plan Content
// -----------------------------------------------------------

class AiActionPlanContent extends ConsumerWidget {
  const AiActionPlanContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(simulationResultProvider);

    return Column(
      children: [
        PageHeader(
          title: 'AI Action Plan',
          subtitle:
              'AI-generated, prioritized actions based on the simulation results',
          actions: [
            ElevatedButton.icon(
              onPressed: result != null
                  ? () => ref
                      .read(shellIndexProvider.notifier)
                      .state = 4
                  : null,
              icon: const Icon(Icons.article_outlined, size: 15),
              label: const Text('Generate Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
        Expanded(
          child: result == null
              ? _EmptyState()
              : _ActionPlanBody(result: result),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------
// Empty State
// -----------------------------------------------------------

class _EmptyState extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_outlined,
                size: 48, color: Color(0xFF16A34A)),
          ),
          const SizedBox(height: 20),
          const Text('No Action Plan Generated',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 6),
          const Text(
            'Run a simulation to generate an AI-powered action plan',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                ref.read(shellIndexProvider.notifier).state = 1,
            icon: const Icon(Icons.science_outlined, size: 18),
            label: const Text('Go to Simulation Setup'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Action Plan Body
// -----------------------------------------------------------

class _ActionPlanBody extends ConsumerWidget {
  final SimulationOutput result;
  const _ActionPlanBody({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Simulation Completed Banner
          _CompletedBanner(onViewResults: () {}),
          const SizedBox(height: 16),

          // Map + Summary row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority Action Map
              Expanded(
                flex: 3,
                child: _PriorityActionMap(result: result),
              ),
              const SizedBox(width: 16),
              // Overall Plan Summary
              SizedBox(
                width: 260,
                child: _PlanSummaryCard(result: result),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // AI Summary
          _AiSummaryCard(result: result),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Completed Banner
// -----------------------------------------------------------

class _CompletedBanner extends StatelessWidget {
  final VoidCallback onViewResults;
  const _CompletedBanner({required this.onViewResults});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final label =
        'Manila Flash Flood Simulation | ${months[now.month - 1]} ${now.day}, ${now.year}  '
        '${now.hour > 12 ? now.hour - 12 : now.hour}:${now.minute.toString().padLeft(2, '0')} '
        '${now.hour >= 12 ? 'PM' : 'AM'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Simulation Completed',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15803D))),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF4ADE80))),
            ],
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onViewResults,
            icon: const Icon(Icons.open_in_new,
                size: 13, color: Color(0xFF16A34A)),
            label: const Text('View Simulation Results',
                style: TextStyle(
                    color: Color(0xFF16A34A), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Priority Action Map
// -----------------------------------------------------------

class _PriorityActionMap extends StatefulWidget {
  final SimulationOutput result;
  const _PriorityActionMap({required this.result});

  @override
  State<_PriorityActionMap> createState() => _PriorityActionMapState();
}

class _PriorityActionMapState extends State<_PriorityActionMap> {
  final Map<String, bool> _layers = {
    'Barangay Boundary': true,
    'Major Roads': true,
    'Rivers / Esteros': true,
    'Evacuation Centers': true,
    'Pumping Stations': true,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text('Priority Action Map',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827))),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'AI-prioritized action areas based on flood impact and risk.',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
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
                      CircleLayer(circles: _actionCircles),
                      if (_layers['Evacuation Centers']!)
                        MarkerLayer(
                          markers: _evacMarkers
                              .map((ll) => Marker(
                                    point: ll,
                                    width: 24,
                                    height: 24,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                          color: Color(0xFF6D28D9),
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.home,
                                          size: 13, color: Colors.white),
                                    ),
                                  ))
                              .toList(),
                        ),
                      if (_layers['Pumping Stations']!)
                        MarkerLayer(
                          markers: _pumpMarkers
                              .map((ll) => Marker(
                                    point: ll,
                                    width: 24,
                                    height: 24,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                          color: Color(0xFF0EA5E9),
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.water_drop,
                                          size: 12, color: Colors.white),
                                    ),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
                // Priority legend + layers panel
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Action Priority',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151))),
                        const SizedBox(height: 5),
                        _legItem(const Color(0xFFDC2626), 'Critical Priority'),
                        _legItem(const Color(0xFFF97316), 'High Priority'),
                        _legItem(const Color(0xFFF59E0B), 'Moderate Priority'),
                        _legItem(const Color(0xFF16A34A), 'Low Priority'),
                        const SizedBox(height: 8),
                        const Text('Map Layers',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151))),
                        const SizedBox(height: 4),
                        ..._layers.keys.map((k) => _layerRow(k)),
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
                Icon(Icons.info_outline, size: 12, color: Color(0xFF9CA3AF)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Red areas indicate barangays that require immediate attention and resource deployment.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legItem(Color c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF374151))),
      ]),
    );
  }

  Widget _layerRow(String key) {
    return InkWell(
      onTap: () => setState(() => _layers[key] = !_layers[key]!),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: Checkbox(
                value: _layers[key],
                onChanged: (v) => setState(() => _layers[key] = v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 5),
            Text(key, style: const TextStyle(fontSize: 10, color: Color(0xFF374151))),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// Plan Summary Card
// -----------------------------------------------------------

class _PlanSummaryCard extends ConsumerWidget {
  final SimulationOutput result;
  const _PlanSummaryCard({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalTasks = result.taskList.length;
    final highPriority =
        result.taskList.where((t) => t.priority == 'HIGH').length;
    final moderatePriority =
        result.taskList.where((t) => t.priority == 'MEDIUM').length;
    final lowPriority =
        result.taskList.where((t) => t.priority == 'LOW').length;
    final isApproved = ref.watch(planApprovedProvider);
    final isExporting = ref.watch(exportLoadingProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overall Plan Summary',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 10),

          _summaryRow('Total Recommended Actions', '$totalTasks', null),
          _summaryRow('High Priority Actions', '$highPriority',
              const Color(0xFFDC2626)),
          _summaryRow('Moderate Priority Actions', '$moderatePriority',
              const Color(0xFFF59E0B)),
          _summaryRow('Low Priority Actions', '$lowPriority',
              const Color(0xFF16A34A)),
          const Divider(height: 16, color: Color(0xFFE5E7EB)),
          _summaryRow(
              'Estimate Resources Needed', '₱ 18.6 M', null),
          _summaryRow(
              'Estimate People Reached', '670,420', null),

          const SizedBox(height: 16),

          // Approve button
          SizedBox(
            width: double.infinity,
            child: isApproved
                ? OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(planApprovedProvider.notifier).state =
                            false,
                    icon: const Icon(Icons.check_circle,
                        size: 15, color: Color(0xFF16A34A)),
                    label: const Text('Plan Approved ✓',
                        style: TextStyle(color: Color(0xFF16A34A))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF16A34A)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(planApprovedProvider.notifier).state =
                            true,
                    icon: const Icon(Icons.thumb_up_outlined, size: 15),
                    label: const Text('Approve Plan'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A)),
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isExporting
                  ? null
                  : () {
                      // TODO: Export PDF via /api/v1/simulation/export-pdf
                    },
              icon: isExporting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined, size: 15),
              label: Text(isExporting ? 'Generating...' : 'Export PDF'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280)))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? const Color(0xFF111827))),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// AI Summary Card
// -----------------------------------------------------------

class _AiSummaryCard extends StatelessWidget {
  final SimulationOutput result;
  const _AiSummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final criticalCount = result.taskList
        .where((t) => t.priority == 'CRITICAL' || t.priority == 'HIGH')
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF0EA5E9)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text('AI Summary',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827))),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Narrative text
              Expanded(
                flex: 2,
                child: Text(
                  result.explainabilityCard.summary.isNotEmpty
                      ? result.explainabilityCard.summary
                      : 'Based on the simulation, ${result.impactedBarangays.length} barangays are at high to critical risk of flood impact. Immediate actions on evacuation, pumping operations, and traffic management will significantly reduce potential impact on the population.',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                      height: 1.6),
                ),
              ),
              const SizedBox(width: 20),

              // Stat chips
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _statChip(
                    Icons.people_outline,
                    '623,410',
                    'Population at Risk',
                    const Color(0xFFDC2626),
                    const Color(0xFFFEF2F2),
                  ),
                  const SizedBox(width: 12),
                  _statChip(
                    Icons.location_city_outlined,
                    '$criticalCount',
                    'High/Critical\nBarangays',
                    const Color(0xFFF59E0B),
                    const Color(0xFFFFFBEB),
                  ),
                  const SizedBox(width: 12),
                  _statChip(
                    Icons.verified_outlined,
                    '92%',
                    'Potential Impact\nReduction',
                    const Color(0xFF16A34A),
                    const Color(0xFFF0FDF4),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(
      IconData icon, String value, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF6B7280)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Shared card decoration
// -----------------------------------------------------------

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(10),
  border: Border.all(color: const Color(0xFFE5E7EB)),
  boxShadow: [
    BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 4,
        offset: const Offset(0, 1)),
  ],
);
