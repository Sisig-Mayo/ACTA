/// ACTA Frontend — AI Action Plan Screen
/// ========================================
/// Displays Gemini AI-generated action plans with
/// explainability cards, time-decayed task timelines,
/// risk narratives, and PDF export capabilities.
///
/// Target Branch : feature/frontend-dashboard
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/simulation_models.dart';

// -----------------------------------------------------------
// State Providers
// -----------------------------------------------------------

/// The currently loaded action plan (null if none generated).
final actionPlanProvider = StateProvider<SimulationOutput?>((ref) => null);

/// Whether the plan has been approved by the operator.
final planApprovedProvider = StateProvider<bool>((ref) => false);

/// PDF export loading state.
final exportLoadingProvider = StateProvider<bool>((ref) => false);

// -----------------------------------------------------------
// AI Action Plan Screen
// -----------------------------------------------------------

class AiActionPlanScreen extends ConsumerStatefulWidget {
  const AiActionPlanScreen({super.key});

  @override
  ConsumerState<AiActionPlanScreen> createState() =>
      _AiActionPlanScreenState();
}

class _AiActionPlanScreenState extends ConsumerState<AiActionPlanScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = ref.watch(actionPlanProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1200;

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: plan == null
          ? _buildEmptyState(theme)
          : isWide
              ? _buildWideLayout(theme, plan)
              : _buildNarrowLayout(theme, plan),
    );
  }

  // ---------------------------------------------------------
  // App Bar
  // ---------------------------------------------------------

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    final plan = ref.watch(actionPlanProvider);

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
              Icons.auto_awesome,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text('AI Action Plan'),
          const SizedBox(width: 8),
          Text(
            '— Gemini-Powered Strategy',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        if (plan != null) ...[
          // Export PDF button
          IconButton(
            onPressed: () {
              // TODO: Trigger PDF export via /api/v1/simulation/export-pdf
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export Action Plan PDF',
          ),
          const SizedBox(width: 8),
          // Dispatch button
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Dispatch plan via /api/v1/simulation/dispatch
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Dispatch'),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ],
    );
  }

  // ---------------------------------------------------------
  // Empty State
  // ---------------------------------------------------------

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_outlined,
              size: 64, color: Colors.grey[700]),
          const SizedBox(height: 20),
          Text(
            'No Action Plan Generated',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Run a simulation to generate an AI-powered action plan',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to Simulation Setup
            },
            icon: const Icon(Icons.science_outlined, size: 20),
            label: const Text('Go to Simulation Setup'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Wide Layout (Desktop)
  // ---------------------------------------------------------

  Widget _buildWideLayout(ThemeData theme, SimulationOutput plan) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Explainability Card & Risk Summary
        SizedBox(
          width: 400,
          child: _buildExplainabilityPanel(theme, plan),
        ),

        // Center: Task Timeline
        Expanded(
          flex: 3,
          child: _buildTaskTimeline(theme, plan),
        ),

        // Right: Approval & Dispatch Panel
        SizedBox(
          width: 340,
          child: _buildApprovalPanel(theme, plan),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // Narrow Layout (Mobile / Tablet)
  // ---------------------------------------------------------

  Widget _buildNarrowLayout(ThemeData theme, SimulationOutput plan) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildExplainabilityPanel(theme, plan),
          _buildTaskTimeline(theme, plan),
          _buildApprovalPanel(theme, plan),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Explainability & Risk Panel
  // ---------------------------------------------------------

  Widget _buildExplainabilityPanel(ThemeData theme, SimulationOutput plan) {
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
              Icon(Icons.psychology_outlined,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              const Text(
                'AI Explainability',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Gemini-generated rationale for the action plan.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),

          const SizedBox(height: 20),

          // Summary
          _buildNarrativeSection(
            'Executive Summary',
            plan.explainabilityCard.summary,
            Icons.summarize_outlined,
            const Color(0xFF00BFA6),
          ),

          const SizedBox(height: 16),

          // Risk Narrative
          _buildNarrativeSection(
            'Risk Narrative',
            plan.explainabilityCard.riskNarrative,
            Icons.warning_amber_rounded,
            const Color(0xFFFFB74D),
          ),

          const SizedBox(height: 16),

          // Action Rationale
          _buildNarrativeSection(
            'Action Rationale',
            plan.explainabilityCard.actionRationale,
            Icons.lightbulb_outline,
            const Color(0xFF26C6DA),
          ),

          const SizedBox(height: 16),

          // Confidence Note
          _buildNarrativeSection(
            'Confidence Assessment',
            plan.explainabilityCard.confidenceNote,
            Icons.verified_outlined,
            const Color(0xFF66BB6A),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Task Timeline Panel
  // ---------------------------------------------------------

  Widget _buildTaskTimeline(ThemeData theme, SimulationOutput plan) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2E36), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.checklist,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Time-Decayed Action Timeline',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${plan.taskList.length} tasks',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildMiniStat(
                    'Critical',
                    plan.taskList
                        .where((t) => t.priority == 'CRITICAL')
                        .length
                        .toString(),
                    const Color(0xFFEF5350)),
                const SizedBox(width: 8),
                _buildMiniStat(
                    'High',
                    plan.taskList
                        .where((t) => t.priority == 'HIGH')
                        .length
                        .toString(),
                    const Color(0xFFFF7043)),
                const SizedBox(width: 8),
                _buildMiniStat(
                    'Medium',
                    plan.taskList
                        .where((t) => t.priority == 'MEDIUM')
                        .length
                        .toString(),
                    const Color(0xFFFFB74D)),
                const SizedBox(width: 8),
                _buildMiniStat(
                    'Low',
                    plan.taskList
                        .where((t) => t.priority == 'LOW')
                        .length
                        .toString(),
                    const Color(0xFF66BB6A)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Task list
          Expanded(
            child: plan.taskList.isEmpty
                ? Center(
                    child: Text(
                      'No tasks generated',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: plan.taskList.length,
                    itemBuilder: (context, index) {
                      return _buildTaskCard(plan.taskList[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Approval & Dispatch Panel
  // ---------------------------------------------------------

  Widget _buildApprovalPanel(ThemeData theme, SimulationOutput plan) {
    final isApproved = ref.watch(planApprovedProvider);
    final isExporting = ref.watch(exportLoadingProvider);

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
              Icon(Icons.gavel_outlined,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Plan Approval',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Review, approve, and dispatch the action plan to field teams.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),

          const SizedBox(height: 24),

          // Severity badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D23),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'THREAT LEVEL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  plan.severityTier.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'T-${plan.preparationWindowHours}h preparation window',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Impact summary
          _buildImpactRow(Icons.location_on, 'Red Zones',
              '${plan.redZoneCount}', const Color(0xFFEF5350)),
          const SizedBox(height: 8),
          _buildImpactRow(Icons.warning, 'Yellow Zones',
              '${plan.yellowZoneCount}', const Color(0xFFFFB74D)),
          const SizedBox(height: 8),
          _buildImpactRow(Icons.task_alt, 'Total Tasks',
              '${plan.taskList.length}', const Color(0xFF00BFA6)),

          const SizedBox(height: 32),

          // Approve toggle
          SizedBox(
            width: double.infinity,
            height: 48,
            child: isApproved
                ? OutlinedButton.icon(
                    onPressed: () {
                      ref.read(planApprovedProvider.notifier).state = false;
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF66BB6A)),
                    ),
                    icon: const Icon(Icons.check_circle,
                        color: Color(0xFF66BB6A)),
                    label: const Text(
                      'Plan Approved ✓',
                      style: TextStyle(color: Color(0xFF66BB6A)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () {
                      ref.read(planApprovedProvider.notifier).state = true;
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF66BB6A),
                    ),
                    icon: const Icon(Icons.thumb_up_outlined, size: 20),
                    label: const Text('Approve Plan'),
                  ),
          ),

          const SizedBox(height: 12),

          // Dispatch button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isApproved
                  ? () {
                      // TODO: Dispatch via /api/v1/simulation/dispatch
                    }
                  : null,
              icon: const Icon(Icons.send_rounded, size: 20),
              label: const Text('Dispatch to Field Teams'),
            ),
          ),

          const SizedBox(height: 12),

          // Export PDF
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: isExporting
                  ? null
                  : () {
                      // TODO: Export PDF via /api/v1/simulation/export-pdf
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF3A3F4B)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 20),
              label: Text(isExporting ? 'Generating...' : 'Export PDF'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Reusable Widgets
  // ---------------------------------------------------------

  Widget _buildNarrativeSection(
      String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskItem task, int index) {
    final Color priorityColor = switch (task.priority) {
      'CRITICAL' => const Color(0xFFEF5350),
      'HIGH' => const Color(0xFFFF7043),
      'MEDIUM' => const Color(0xFFFFB74D),
      _ => const Color(0xFF66BB6A),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D23),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: priorityColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.priority,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: priorityColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.category,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[400],
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

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactRow(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
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
}
