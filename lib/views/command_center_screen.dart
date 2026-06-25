/// ACTA Frontend — Command Center Screen
/// ========================================
/// Real-time operational overview for LGU disaster response
/// operators. Displays live status cards, active alert feed,
/// current deployment tracker, and quick-action controls.
///
/// Target Branch : feature/frontend-dashboard
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// -----------------------------------------------------------
// State Providers
// -----------------------------------------------------------

/// Active alert count badge value.
final activeAlertsCountProvider = StateProvider<int>((ref) => 0);

/// Current operational status label.
final operationalStatusProvider = StateProvider<String>((ref) => 'STANDBY');

// -----------------------------------------------------------
// Command Center Screen
// -----------------------------------------------------------

class CommandCenterScreen extends ConsumerStatefulWidget {
  const CommandCenterScreen({super.key});

  @override
  ConsumerState<CommandCenterScreen> createState() =>
      _CommandCenterScreenState();
}

class _CommandCenterScreenState extends ConsumerState<CommandCenterScreen> {
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
              Icons.radar,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Command Center'),
          const SizedBox(width: 8),
          Text(
            '— Real-Time Operations',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        _StatusBadge(status: ref.watch(operationalStatusProvider)),
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
        // Left: Status Overview
        SizedBox(
          width: 340,
          child: _buildStatusPanel(theme),
        ),

        // Center: Live Map / Situation Canvas
        Expanded(
          flex: 3,
          child: _buildSituationCanvas(theme),
        ),

        // Right: Alerts & Deployments Feed
        SizedBox(
          width: 400,
          child: _buildAlertsFeed(theme),
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
          _buildStatusPanel(theme),
          SizedBox(
            height: 400,
            child: _buildSituationCanvas(theme),
          ),
          _buildAlertsFeed(theme),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Status Overview Panel
  // ---------------------------------------------------------

  Widget _buildStatusPanel(ThemeData theme) {
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
              Icon(Icons.dashboard_outlined,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Operational Status',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Real-time overview of active operations and resource readiness.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),

          const SizedBox(height: 24),

          // Status Cards Grid
          _buildStatusCard(
            icon: Icons.warning_amber_rounded,
            label: 'Active Alerts',
            value: '0',
            color: const Color(0xFFFFB74D),
          ),
          const SizedBox(height: 12),
          _buildStatusCard(
            icon: Icons.groups_outlined,
            label: 'Deployed Teams',
            value: '0',
            color: const Color(0xFF26C6DA),
          ),
          const SizedBox(height: 12),
          _buildStatusCard(
            icon: Icons.local_shipping_outlined,
            label: 'Resources In Transit',
            value: '0',
            color: const Color(0xFF66BB6A),
          ),
          const SizedBox(height: 12),
          _buildStatusCard(
            icon: Icons.people_outline,
            label: 'Evacuees Tracked',
            value: '0',
            color: const Color(0xFFEF5350),
          ),

          const SizedBox(height: 32),

          // Quick Actions
          Row(
            children: [
              Icon(Icons.bolt, size: 15, color: Colors.grey[500]),
              const SizedBox(width: 8),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Navigate to Simulation Setup
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('New Simulation'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Trigger manual alert broadcast
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF3A3F4B)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.campaign_outlined, size: 20),
              label: const Text('Broadcast Alert'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Situation Canvas (Map placeholder)
  // ---------------------------------------------------------

  Widget _buildSituationCanvas(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2E36), width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Situation Map Canvas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Live barangay status overlay will render here',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Alerts & Deployments Feed
  // ---------------------------------------------------------

  Widget _buildAlertsFeed(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2E36), width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_outlined,
                size: 48, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Live Alerts & Deployment Feed',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Incoming alerts and deployment updates will stream here',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Reusable Status Card
  // ---------------------------------------------------------

  Widget _buildStatusCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color,
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
// Supporting Widgets
// -----------------------------------------------------------

/// Operational status badge for the app bar.
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  Color get _color => switch (status) {
        'ACTIVE' => const Color(0xFFEF5350),
        'ALERT' => const Color(0xFFFFB74D),
        'STANDBY' => const Color(0xFF66BB6A),
        _ => const Color(0xFF9CA3AF),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
