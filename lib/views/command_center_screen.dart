/// ACTA Frontend — Command Center Screen
/// ========================================
/// Real-time operational overview: baseline flood risk map,
/// operational stats, and priority risk area table.
/// Renders as content inside AppShell (no Scaffold).
///
/// Target Branch : feat/dashboard
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'app_shell.dart';
import '../models/barangay_provider.dart';
import '../models/simulation_state.dart';
import '../models/simulation_models.dart';

// -----------------------------------------------------------
// Static Baseline Data
// -----------------------------------------------------------

const _kManilaCtr = LatLng(14.5928, 120.9762);

const _priorityAreas = [
  _RiskArea('Tondo', 'High Risk', Color(0xFF1E3A8A), 'Coastal flooding, dense population'),
  _RiskArea('Sampaloc', 'Moderate Risk', Color(0xFF2563EB), 'Drainage overflow history'),
  _RiskArea('Pandacan', 'Moderate Risk', Color(0xFF2563EB), 'River proximity'),
  _RiskArea('Paco', 'Moderate Risk', Color(0xFF2563EB), 'Low-lying roads'),
  _RiskArea('Malate', 'Low Risk', Color(0xFF0EA5E9), 'Shelter access nearby'),
];

class _RiskArea {
  final String name;
  final String riskLabel;
  final Color riskColor;
  final String keyFactors;
  const _RiskArea(this.name, this.riskLabel, this.riskColor, this.keyFactors);
}



// Evacuation center markers (house icon approximation)
final _evacMarkers = [
  const LatLng(14.6050, 120.9600),
  const LatLng(14.5920, 121.0000),
  const LatLng(14.5750, 120.9900),
  const LatLng(14.5660, 121.0100),
  const LatLng(14.6200, 120.9950),
];

// Pumping station markers
final _pumpMarkers = [
  const LatLng(14.6100, 120.9700),
  const LatLng(14.5980, 120.9870),
  const LatLng(14.5870, 121.0020),
];

// -----------------------------------------------------------
// Command Center Content
// -----------------------------------------------------------

class CommandCenterContent extends ConsumerStatefulWidget {
  const CommandCenterContent({super.key});

  @override
  ConsumerState<CommandCenterContent> createState() =>
      _CommandCenterContentState();
}

class _CommandCenterContentState
    extends ConsumerState<CommandCenterContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        PageHeader(
          title: 'Command Center',
          subtitle: 'Real-time operational view for Manila responses',
          actions: [
            OutlinedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('Refresh'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(shellIndexProvider.notifier).state = 1;
              },
              icon: const Icon(Icons.science_outlined, size: 15),
              label: const Text('Run Simulation'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(shellIndexProvider.notifier).state = 4;
              },
              icon: const Icon(Icons.article_outlined, size: 15),
              label: const Text('Generate Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),

        // Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Risk Map'),
              Tab(text: 'Alerts'),
              Tab(text: 'Resources'),
            ],
          ),
        ),

        // Tab Body
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(),
              _RiskMapTab(),
              _AlertsTab(),
              _ResourcesOverviewTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------
// Overview Tab
// -----------------------------------------------------------

class _OverviewTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barangaysAsync = ref.watch(barangayPolygonsProvider);
    final simResult = ref.watch(simulationResultProvider);

    // Build risk map from simulation results if available
    Map<String, String>? riskMap;
    if (simResult != null) {
      riskMap = {};
      for (final b in simResult.impactedBarangays) {
        riskMap[b.barangayName] = b.zoneStatus.name;
      }
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Map Card
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 18, color: Color(0xFF374151)),
                      SizedBox(width: 8),
                      Text(
                        'Manila Barangay Flood Risk Map',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 320,
                  child: _buildBarangayMap(barangaysAsync, riskMap),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          // Bottom two cards side-by-side on desktop, stacked on mobile
          if (isMobile) ...[
            _OperationalBaselineCard(),
            const SizedBox(height: 16),
            _PriorityRiskAreasCard(),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _OperationalBaselineCard()),
                const SizedBox(width: 16),
                Expanded(child: _PriorityRiskAreasCard()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBarangayMap(
    AsyncValue<List<BarangayPolygon>> barangaysAsync,
    Map<String, String>? riskMap,
  ) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(10),
        bottomRight: Radius.circular(10),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: _kManilaCtr,
              initialZoom: 12.5,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.acta.app',
              ),
              // Barangay polygons
              barangaysAsync.when(
                data: (barangays) => PolygonLayer(
                  polygons: buildBarangayMapPolygons(barangays, riskMap: riskMap),
                ),
                loading: () => const PolygonLayer(polygons: <Polygon>[]),
                error: (_, __) => const PolygonLayer(polygons: <Polygon>[]),
              ),
              MarkerLayer(
                markers: [
                  ..._evacMarkers.map((ll) => Marker(
                        point: ll,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Color(0xFF6D28D9), shape: BoxShape.circle),
                          child: const Icon(Icons.home,
                              size: 13, color: Colors.white),
                        ),
                      )),
                  ..._pumpMarkers.map((ll) => Marker(
                        point: ll,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Color(0xFF0EA5E9), shape: BoxShape.circle),
                          child: const Icon(Icons.water_drop,
                              size: 12, color: Colors.white),
                        ),
                      )),
                ],
              ),
            ],
          ),
          // Legend
          Positioned(
            bottom: 12,
            left: 12,
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
                  _legendItem(const Color(0xFF1E3A8A), 'High Risk (Dark Blue)'),
                  const SizedBox(height: 4),
                  _legendItem(const Color(0xFF2563EB), 'Moderate Risk (Blue)'),
                  const SizedBox(height: 4),
                  _legendItem(const Color(0xFF0EA5E9), 'Low Risk (Light Blue)'),
                  const SizedBox(height: 4),
                  _legendItem(const Color(0xFF38BDF8), 'Baseline'),
                ],
              ),
            ),
          ),
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
      ],
    );
  }
}

class _OperationalBaselineCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const stats = [
      _StatRow(Icons.groups_outlined, 'Barangay Covered', '81',
          Icons.water_drop_outlined, 'Pumping Stations', '12'),
      _StatRow(Icons.flood_outlined, 'Known Flood-Prone Areas', '18',
          Icons.local_shipping_outlined, 'Rescue Assets Logged', '64'),
      _StatRow(Icons.night_shelter_outlined, 'Evacuation Centers', '42',
          Icons.check_circle_outlined, 'Dataset Status', 'Ready'),
    ];

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.summarize_outlined,
                    size: 16, color: Color(0xFF374151)),
                SizedBox(width: 8),
                Text('Operational Baseline',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827))),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 10),
            ...stats.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: s,
                )),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon1;
  final String label1;
  final String value1;
  final IconData icon2;
  final String label2;
  final String value2;

  const _StatRow(
      this.icon1, this.label1, this.value1, this.icon2, this.label2, this.value2);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _statCell(icon1, label1, value1)),
        const SizedBox(width: 8),
        Expanded(
            child: _statCell(icon2, label2, value2)),
      ],
    );
  }

  Widget _statCell(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF374151))),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827))),
      ],
    );
  }
}

class _PriorityRiskAreasCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.flag_outlined, size: 16, color: Color(0xFF374151)),
                SizedBox(width: 8),
                Text('Priority Risk Areas',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827))),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 8),
            if (!isMobile) ...[
              // Table header
              const Row(
                children: [
                  SizedBox(width: 24, child: Text('#', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))),
                  Expanded(flex: 2, child: Text('Area', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))),
                  Expanded(flex: 3, child: Text('Risk Level (Baseline)', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))),
                  Expanded(flex: 3, child: Text('Key Risk Factors', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))),
                ],
              ),
              const SizedBox(height: 6),
            ],
            ..._priorityAreas.asMap().entries.map((e) {
              final i = e.key;
              final area = e.value;
              if (isMobile) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: area.riskColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(area.name,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827))),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: area.riskColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    area.riskLabel,
                                    style: TextStyle(
                                        color: area.riskColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(area.keyFactors,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: area.riskColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(area.name,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827))),
                    ),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: area.riskColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          area.riskLabel,
                          style: TextStyle(
                              color: area.riskColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(area.keyFactors,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280))),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// Risk Map Tab
// -----------------------------------------------------------

class _RiskMapTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barangaysAsync = ref.watch(barangayPolygonsProvider);
    final simResult = ref.watch(simulationResultProvider);

    Map<String, String>? riskMap;
    if (simResult != null) {
      riskMap = {};
      for (final b in simResult.impactedBarangays) {
        riskMap[b.barangayName] = b.zoneStatus.name;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: _card(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: FlutterMap(
            options: const MapOptions(
              initialCenter: _kManilaCtr,
              initialZoom: 12.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.acta.app',
              ),
              barangaysAsync.when(
                data: (barangays) => PolygonLayer(
                  polygons: buildBarangayMapPolygons(barangays, riskMap: riskMap),
                ),
                loading: () => const PolygonLayer(polygons: <Polygon>[]),
                error: (_, __) => const PolygonLayer(polygons: <Polygon>[]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// Alerts Tab
// -----------------------------------------------------------

class _AlertsTab extends StatelessWidget {
  static const _alerts = [
    _AlertItem('HIGH', 'Flood watch issued for Tondo District',
        'PAGASA issued a flood watch advisory for Tondo and surrounding barangays due to sustained rainfall above 80mm/hr.', '10 mins ago'),
    _AlertItem('MODERATE', 'Pumping station offline — Sampaloc',
        'Pumping station PS-07 in Sampaloc has gone offline. Drainage capacity reduced by 30%.', '32 mins ago'),
    _AlertItem('LOW', 'Evacuation center at 70% capacity',
        'Rizal High School evacuation center is nearing capacity. Consider activating backup site.', '1 hr ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _alerts.length,
      itemBuilder: (context, i) => _AlertCard(alert: _alerts[i]),
    );
  }
}

class _AlertItem {
  final String level;
  final String title;
  final String body;
  final String time;
  const _AlertItem(this.level, this.title, this.body, this.time);
}

class _AlertCard extends StatelessWidget {
  final _AlertItem alert;
  const _AlertCard({required this.alert});

  Color get _color => switch (alert.level) {
        'HIGH' => const Color(0xFF1E3A8A),
        'MODERATE' => const Color(0xFF2563EB),
        _ => const Color(0xFF0EA5E9),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: _color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(alert.level,
                    style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(alert.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
              ),
              Text(alert.time,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          ),
          const SizedBox(height: 6),
          Text(alert.body,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.5)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Resources Overview Tab
// -----------------------------------------------------------

class _ResourcesOverviewTab extends StatelessWidget {
  static const _resources = [
    ('Pumping Stations', '12', '9 Online, 3 Offline', Color(0xFF0EA5E9)),
    ('Rescue Boats', '64', '52 Ready, 12 Deployed', Color(0xFF60A5FA)),
    ('Evacuation Centers', '42', '38 Open, 4 At Capacity', Color(0xFF2563EB)),
    ('Medical Teams', '24', '18 On Standby', Color(0xFF1D4ED8)),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: _resources
            .map((r) => SizedBox(
                  width: isMobile ? double.infinity : 280,
                  child: _ResourceOverviewCard(
                    label: r.$1,
                    count: r.$2,
                    detail: r.$3,
                    color: r.$4,
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _ResourceOverviewCard extends StatelessWidget {
  final String label;
  final String count;
  final String detail;
  final Color color;

  const _ResourceOverviewCard({
    required this.label,
    required this.count,
    required this.detail,
    required this.color,
  });

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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2_outlined, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
                Text(count,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: color)),
                Text(detail,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Shared card helper
// -----------------------------------------------------------

Widget _card({required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: child,
  );
}
