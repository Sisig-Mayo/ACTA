/// ACTA Frontend — Resource Management Screen
/// ==============================================
/// Live view of resource locations and status across Manila,
/// with a searchable/filterable resource table below the map.
/// Renders as content inside AppShell (no Scaffold).
///
/// Target Branch : feat/dashboard
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'app_shell.dart';

// -----------------------------------------------------------
// Static resource data (matches mockup)
// -----------------------------------------------------------

class _Resource {
  final String name;
  final String type;
  final String location;
  final String status;
  final int availability;
  final String lastUpdated;

  const _Resource({
    required this.name,
    required this.type,
    required this.location,
    required this.status,
    required this.availability,
    required this.lastUpdated,
  });
}

const _resources = [
  _Resource(
    name: 'Pumping Station – Estero de San Miguel',
    type: 'Pumping Station',
    location: 'Sampaloc',
    status: 'Available',
    availability: 100,
    lastUpdated: 'May 20, 2025  9:10 AM',
  ),
  _Resource(
    name: 'Evacuation Center – Rizal High School',
    type: 'Evacuation Center',
    location: 'Malate',
    status: 'Deployed',
    availability: 85,
    lastUpdated: 'May 20, 2025  9:05 AM',
  ),
  _Resource(
    name: 'Rescue Boat – RB 03',
    type: 'Rescue Asset',
    location: 'Tondo',
    status: 'Maintenance',
    availability: 0,
    lastUpdated: 'May 20, 2025  8:45 AM',
  ),
  _Resource(
    name: 'Ospital ng Maynila',
    type: 'Medical Facility',
    location: 'Ermita',
    status: 'Available',
    availability: 100,
    lastUpdated: 'May 20, 2025  8:30 AM',
  ),
  _Resource(
    name: 'Central Warehouse',
    type: 'Warehouse',
    location: 'Sta. Cruz',
    status: 'Deployed',
    availability: 78,
    lastUpdated: 'May 20, 2025  8:20 AM',
  ),
];

// Map marker data
const _kManilaCtr = LatLng(14.5928, 120.9762);

class _MapResource {
  final LatLng point;
  final String type;
  final String status;
  const _MapResource(this.point, this.type, this.status);
}

final _mapResources = [
  _MapResource(const LatLng(14.6050, 120.9600), 'Evacuation Center', 'Available'),
  _MapResource(const LatLng(14.5920, 121.0020), 'Evacuation Center', 'Deployed'),
  _MapResource(const LatLng(14.5750, 120.9880), 'Evacuation Center', 'Available'),
  _MapResource(const LatLng(14.5620, 121.0050), 'Evacuation Center', 'Available'),
  _MapResource(const LatLng(14.6210, 120.9940), 'Evacuation Center', 'Deployed'),
  _MapResource(const LatLng(14.6100, 120.9720), 'Pumping Station', 'Available'),
  _MapResource(const LatLng(14.5970, 120.9870), 'Pumping Station', 'Deployed'),
  _MapResource(const LatLng(14.5850, 121.0010), 'Pumping Station', 'Maintenance'),
  _MapResource(const LatLng(14.6000, 120.9650), 'Rescue Asset', 'Available'),
  _MapResource(const LatLng(14.5800, 120.9950), 'Rescue Asset', 'Deployed'),
  _MapResource(const LatLng(14.5720, 120.9800), 'Rescue Asset', 'Available'),
  _MapResource(const LatLng(14.5900, 120.9750), 'Medical Facility', 'Available'),
  _MapResource(const LatLng(14.5650, 121.0080), 'Medical Facility', 'Deployed'),
  _MapResource(const LatLng(14.6080, 121.0030), 'Warehouse', 'Deployed'),
  _MapResource(const LatLng(14.5780, 121.0120), 'Warehouse', 'Available'),
];

// -----------------------------------------------------------
// Provider
// -----------------------------------------------------------

final _searchProvider = StateProvider<String>((ref) => '');

// Layer visibility
final _layersProvider = StateProvider<Map<String, bool>>((ref) => {
      'Evacuation Centers': true,
      'Pumping Stations': true,
      'Rescue Assets': true,
      'Medical Facilities': true,
      'Warehouses': true,
    });

// -----------------------------------------------------------
// Resource Management Content
// -----------------------------------------------------------

class ResourceManagementContent extends ConsumerWidget {
  const ResourceManagementContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        PageHeader(
          title: 'Resource Management',
          subtitle:
              'View, monitor, and manage resources for flood response operations.',
          actions: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_outlined, size: 15),
              label: const Text('Export Resources'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Add New Resource'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A)),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _ResourceMapCard(),
                const SizedBox(height: 20),
                _AllResourcesCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------
// Resource Map Card
// -----------------------------------------------------------

class _ResourceMapCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ResourceMapCard> createState() => _ResourceMapCardState();
}

class _ResourceMapCardState extends ConsumerState<_ResourceMapCard> {
  @override
  Widget build(BuildContext context) {
    final layers = ref.watch(_layersProvider);

    Color markerColor(String type, String status) {
      if (status == 'Maintenance') return const Color(0xFFF59E0B);
      if (status == 'Offline') return const Color(0xFFDC2626);
      return switch (type) {
        'Evacuation Center' => const Color(0xFF16A34A),
        'Pumping Station' => const Color(0xFF0EA5E9),
        'Rescue Asset' => const Color(0xFFDC2626),
        'Medical Facility' => const Color(0xFF8B5CF6),
        'Warehouse' => const Color(0xFFF59E0B),
        _ => const Color(0xFF6B7280),
      };
    }

    IconData markerIcon(String type) => switch (type) {
          'Evacuation Center' => Icons.home_outlined,
          'Pumping Station' => Icons.water_drop_outlined,
          'Rescue Asset' => Icons.directions_boat_outlined,
          'Medical Facility' => Icons.local_hospital_outlined,
          'Warehouse' => Icons.warehouse_outlined,
          _ => Icons.place_outlined,
        };

    final visibleResources = _mapResources.where((r) {
      return layers[r.type] ?? true;
    }).toList();

    return Container(
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text('Resource Map',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827))),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Live view of resource locations and status.',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ),
          SizedBox(
            height: 420,
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
                      MarkerLayer(
                        markers: visibleResources
                            .map((r) => Marker(
                                  point: r.point,
                                  width: 26,
                                  height: 26,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: markerColor(r.type, r.status),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                    ),
                                    child: Icon(markerIcon(r.type),
                                        size: 13, color: Colors.white),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                // Layers panel
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
                        const Text('Map Layers',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151))),
                        const SizedBox(height: 5),
                        ...layers.keys.map((k) {
                          final color = switch (k) {
                            'Evacuation Centers' => const Color(0xFF16A34A),
                            'Pumping Stations' => const Color(0xFF0EA5E9),
                            'Rescue Assets' => const Color(0xFFDC2626),
                            'Medical Facilities' => const Color(0xFF8B5CF6),
                            'Warehouses' => const Color(0xFFF59E0B),
                            _ => const Color(0xFF6B7280),
                          };
                          return _layerCheck(k, layers[k]!, color);
                        }),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => ref
                              .read(_layersProvider.notifier)
                              .state = {
                            for (final k in layers.keys) k: false,
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: const Color(0xFFD1D5DB)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.layers_clear,
                                    size: 11,
                                    color: Color(0xFF6B7280)),
                                SizedBox(width: 4),
                                Text('Clear Layers',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF6B7280))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Status legend
                Positioned(
                  bottom: 10,
                  right: 10,
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
                        const Text('Resource Status',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151))),
                        const SizedBox(height: 5),
                        _statusDot(const Color(0xFF16A34A), 'Available'),
                        _statusDot(const Color(0xFF0EA5E9), 'Deployed'),
                        _statusDot(const Color(0xFFF59E0B), 'Maintenance'),
                        _statusDot(const Color(0xFFDC2626), 'Offline'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _layerCheck(String label, bool value, Color color) {
    return InkWell(
      onTap: () {
        final current = Map<String, bool>.from(ref.read(_layersProvider));
        current[label] = !current[label]!;
        ref.read(_layersProvider.notifier).state = current;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: Checkbox(
                value: value,
                onChanged: (v) {
                  final current =
                      Map<String, bool>.from(ref.read(_layersProvider));
                  current[label] = v ?? false;
                  ref.read(_layersProvider.notifier).state = current;
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label,
                style:
                    const TextStyle(fontSize: 10, color: Color(0xFF374151))),
          ],
        ),
      ),
    );
  }

  Widget _statusDot(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: Color(0xFF374151))),
      ]),
    );
  }
}

// -----------------------------------------------------------
// All Resources Table Card
// -----------------------------------------------------------

class _AllResourcesCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(_searchProvider).toLowerCase();

    final filtered = _resources.where((r) {
      if (search.isEmpty) return true;
      return r.name.toLowerCase().contains(search) ||
          r.type.toLowerCase().contains(search) ||
          r.location.toLowerCase().contains(search) ||
          r.status.toLowerCase().contains(search);
    }).toList();

    return Container(
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Text('All Resources',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
                const Spacer(),
                SizedBox(
                  width: 220,
                  child: TextField(
                    onChanged: (v) =>
                        ref.read(_searchProvider.notifier).state = v,
                    decoration: const InputDecoration(
                      hintText: 'Search resources...',
                      prefixIcon: Icon(Icons.search,
                          size: 16, color: Color(0xFF9CA3AF)),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download_outlined, size: 14),
                  label: const Text('Download'),
                ),
              ],
            ),
          ),

          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF9FAFB),
            child: const Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('Resource Name',
                        style: _tableHeaderStyle)),
                Expanded(
                    flex: 2,
                    child: Text('Type', style: _tableHeaderStyle)),
                Expanded(
                    flex: 2,
                    child:
                        Text('Location', style: _tableHeaderStyle)),
                Expanded(
                    flex: 2,
                    child: Text('Status', style: _tableHeaderStyle)),
                Expanded(
                    flex: 2,
                    child:
                        Text('Availability', style: _tableHeaderStyle)),
                Expanded(
                    flex: 3,
                    child:
                        Text('Last Updated', style: _tableHeaderStyle)),
                SizedBox(
                    width: 60,
                    child:
                        Text('Actions', style: _tableHeaderStyle)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Table rows
          ...filtered.map((r) => _ResourceRow(resource: r)),

          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No resources match your search.',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF9CA3AF))),
              ),
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

const _tableHeaderStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: Color(0xFF6B7280),
);

class _ResourceRow extends StatelessWidget {
  final _Resource resource;
  const _ResourceRow({required this.resource});

  Color get _statusColor => switch (resource.status) {
        'Available' => const Color(0xFF16A34A),
        'Deployed' => const Color(0xFF0EA5E9),
        'Maintenance' => const Color(0xFFF59E0B),
        'Offline' => const Color(0xFFDC2626),
        _ => const Color(0xFF6B7280),
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                  flex: 4,
                  child: Row(children: [
                    _typeIcon(resource.type),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(resource.name,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111827))),
                    ),
                  ])),
              Expanded(
                  flex: 2,
                  child: Text(resource.type,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)))),
              Expanded(
                  flex: 2,
                  child: Text(resource.location,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)))),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: _statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(resource.status,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF374151))),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${resource.availability}%',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _statusColor),
                ),
              ),
              Expanded(
                  flex: 3,
                  child: Text(resource.lastUpdated,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)))),
              SizedBox(
                width: 60,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined,
                          size: 16, color: Color(0xFF6B7280)),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.more_vert,
                          size: 16, color: Color(0xFF6B7280)),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
      ],
    );
  }

  Widget _typeIcon(String type) {
    final color = switch (type) {
      'Pumping Station' => const Color(0xFF0EA5E9),
      'Evacuation Center' => const Color(0xFF16A34A),
      'Rescue Asset' => const Color(0xFFDC2626),
      'Medical Facility' => const Color(0xFF8B5CF6),
      'Warehouse' => const Color(0xFFF59E0B),
      _ => const Color(0xFF6B7280),
    };
    final icon = switch (type) {
      'Pumping Station' => Icons.water_drop_outlined,
      'Evacuation Center' => Icons.home_outlined,
      'Rescue Asset' => Icons.directions_boat_outlined,
      'Medical Facility' => Icons.local_hospital_outlined,
      'Warehouse' => Icons.warehouse_outlined,
      _ => Icons.inventory_2_outlined,
    };
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: color),
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
