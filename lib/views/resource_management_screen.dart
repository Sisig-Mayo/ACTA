/// ACTA Frontend — Resource Management Screen
/// ==============================================
/// Inventory and logistics dashboard for managing
/// disaster response assets: personnel, vehicles,
/// relief goods, and evacuation center capacity.
///
/// Target Branch : feature/frontend-dashboard
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// -----------------------------------------------------------
// Data Models
// -----------------------------------------------------------

/// A single resource entry in the inventory.
class ResourceItem {
  final String id;
  final String name;
  final String category;
  final int totalQuantity;
  final int deployedQuantity;
  final String status; // 'available', 'deployed', 'low', 'critical'
  final String location;

  const ResourceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.totalQuantity,
    required this.deployedQuantity,
    required this.status,
    required this.location,
  });

  int get availableQuantity => totalQuantity - deployedQuantity;

  double get utilizationPct =>
      totalQuantity > 0 ? (deployedQuantity / totalQuantity) * 100 : 0;
}

/// An evacuation center with capacity tracking.
class EvacuationCenter {
  final String name;
  final String barangay;
  final int maxCapacity;
  final int currentOccupancy;
  final String status; // 'open', 'full', 'closed'

  const EvacuationCenter({
    required this.name,
    required this.barangay,
    required this.maxCapacity,
    required this.currentOccupancy,
    required this.status,
  });

  double get occupancyPct =>
      maxCapacity > 0 ? (currentOccupancy / maxCapacity) * 100 : 0;
}

// -----------------------------------------------------------
// State Providers
// -----------------------------------------------------------

/// Resource inventory list.
final resourceInventoryProvider =
    StateProvider<List<ResourceItem>>((ref) => []);

/// Evacuation center list.
final evacuationCentersProvider =
    StateProvider<List<EvacuationCenter>>((ref) => []);

/// Active filter category.
final resourceFilterProvider = StateProvider<String?>((ref) => null);

// -----------------------------------------------------------
// Resource Categories
// -----------------------------------------------------------

const _resourceCategories = <String, IconData>{
  'Personnel': Icons.groups_outlined,
  'Vehicles': Icons.local_shipping_outlined,
  'Medical': Icons.medical_services_outlined,
  'Relief Goods': Icons.inventory_2_outlined,
  'Equipment': Icons.construction_outlined,
  'Communications': Icons.cell_tower_outlined,
};

// -----------------------------------------------------------
// Resource Management Screen
// -----------------------------------------------------------

class ResourceManagementScreen extends ConsumerStatefulWidget {
  const ResourceManagementScreen({super.key});

  @override
  ConsumerState<ResourceManagementScreen> createState() =>
      _ResourceManagementScreenState();
}

class _ResourceManagementScreenState
    extends ConsumerState<ResourceManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1200;

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: isWide
          ? _buildWideLayout(theme)
          : _buildNarrowLayout(theme),
    );
  }

  // ---------------------------------------------------------
  // App Bar
  // ---------------------------------------------------------

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.inventory_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Resource Management'),
          const SizedBox(width: 8),
          Text(
            '— Logistics & Inventory',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            // TODO: Refresh resource data from backend
          },
          icon: const Icon(Icons.refresh_outlined),
          tooltip: 'Refresh Inventory',
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Open add resource dialog
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Resource'),
          style: ElevatedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  // ---------------------------------------------------------
  // Wide Layout (Desktop)
  // ---------------------------------------------------------

  Widget _buildWideLayout(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Category filters & summary stats
        SizedBox(
          width: 300,
          child: _buildCategorySidebar(theme),
        ),

        // Center: Resource inventory table
        Expanded(
          flex: 3,
          child: _buildInventoryPanel(theme),
        ),

        // Right: Evacuation centers & logistics
        SizedBox(
          width: 380,
          child: _buildEvacuationPanel(theme),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // Narrow Layout (Mobile / Tablet)
  // ---------------------------------------------------------

  Widget _buildNarrowLayout(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildCategorySidebar(theme),
          _buildInventoryPanel(theme),
          _buildEvacuationPanel(theme),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Category Sidebar
  // ---------------------------------------------------------

  Widget _buildCategorySidebar(ThemeData theme) {
    final activeFilter = ref.watch(resourceFilterProvider);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2E36), width: 1),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.category_outlined,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Categories',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Filter resources by category.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),

          const SizedBox(height: 20),

          // All resources filter
          _buildCategoryTile(
            icon: Icons.apps,
            label: 'All Resources',
            isSelected: activeFilter == null,
            onTap: () {
              ref.read(resourceFilterProvider.notifier).state = null;
            },
            theme: theme,
          ),
          const SizedBox(height: 8),

          // Category tiles
          ..._resourceCategories.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCategoryTile(
                icon: entry.value,
                label: entry.key,
                isSelected: activeFilter == entry.key,
                onTap: () {
                  ref.read(resourceFilterProvider.notifier).state =
                      entry.key;
                },
                theme: theme,
              ),
            );
          }),

          const SizedBox(height: 28),

          // Summary Stats
          Row(
            children: [
              Icon(Icons.analytics_outlined,
                  size: 15, color: Colors.grey[500]),
              const SizedBox(width: 8),
              const Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildSummaryCard(
            label: 'Total Resources',
            value: '0',
            color: const Color(0xFF00BFA6),
          ),
          const SizedBox(height: 8),
          _buildSummaryCard(
            label: 'Currently Deployed',
            value: '0',
            color: const Color(0xFF26C6DA),
          ),
          const SizedBox(height: 8),
          _buildSummaryCard(
            label: 'Low Stock Alerts',
            value: '0',
            color: const Color(0xFFFFB74D),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Inventory Panel
  // ---------------------------------------------------------

  Widget _buildInventoryPanel(ThemeData theme) {
    final resources = ref.watch(resourceInventoryProvider);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2E36), width: 1),
      ),
      child: resources.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 48, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    'Resource Inventory Empty',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add resources to start tracking logistics',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Open add resource dialog
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add First Resource'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.table_chart_outlined,
                        color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Inventory Ledger',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${resources.length} items',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Resource rows
                ...resources.map((r) => _buildResourceRow(r)),
              ],
            ),
    );
  }

  // ---------------------------------------------------------
  // Evacuation Centers Panel
  // ---------------------------------------------------------

  Widget _buildEvacuationPanel(ThemeData theme) {
    final centers = ref.watch(evacuationCentersProvider);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2E36), width: 1),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.night_shelter_outlined,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Evacuation Centers',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${centers.length} sites',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Capacity and occupancy tracking for evacuation facilities.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),

          const SizedBox(height: 20),

          if (centers.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.night_shelter_outlined,
                      size: 40, color: Colors.grey[700]),
                  const SizedBox(height: 12),
                  Text(
                    'No evacuation centers registered',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Register evacuation center
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF3A3F4B)),
                    ),
                    icon: const Icon(Icons.add_location_outlined, size: 18),
                    label: const Text('Register Center'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            )
          else
            ...centers.map((c) => _buildEvacCenterCard(c, theme)),

          const SizedBox(height: 24),

          // Logistics quick actions
          Row(
            children: [
              Icon(Icons.local_shipping, size: 15, color: Colors.grey[500]),
              const SizedBox(width: 8),
              const Text(
                'Logistics Actions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: () {
              // TODO: Request resupply
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF3A3F4B)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.sync_outlined, size: 18),
            label: const Text('Request Resupply'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Transfer resources
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF3A3F4B)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.swap_horiz_outlined, size: 18),
            label: const Text('Transfer Resources'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Reusable Widgets
  // ---------------------------------------------------------

  Widget _buildCategoryTile({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : const Color(0xFF1A1D23),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : const Color(0xFF2A2E36),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.grey[500]),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceRow(ResourceItem resource) {
    final Color statusColor = switch (resource.status) {
      'critical' => const Color(0xFFEF5350),
      'low' => const Color(0xFFFFB74D),
      'deployed' => const Color(0xFF26C6DA),
      _ => const Color(0xFF66BB6A),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D23),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${resource.category} · ${resource.location}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          // Utilization bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${resource.deployedQuantity}/${resource.totalQuantity}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: resource.utilizationPct / 100,
                    backgroundColor: const Color(0xFF2A2E36),
                    color: statusColor,
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              resource.status.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: statusColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvacCenterCard(EvacuationCenter center, ThemeData theme) {
    final Color statusColor = switch (center.status) {
      'full' => const Color(0xFFEF5350),
      'open' => const Color(0xFF66BB6A),
      _ => const Color(0xFF9CA3AF),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2E36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  center.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  center.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            center.barangay,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: center.occupancyPct / 100,
                    backgroundColor: const Color(0xFF2A2E36),
                    color: center.occupancyPct > 90
                        ? const Color(0xFFEF5350)
                        : center.occupancyPct > 70
                            ? const Color(0xFFFFB74D)
                            : const Color(0xFF66BB6A),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${center.currentOccupancy}/${center.maxCapacity}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
