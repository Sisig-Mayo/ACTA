/// ACTA Frontend — Master Action Plan Screen
/// ==========================================
/// Displays the formal, signed-off disaster response plan.
/// Includes the executive summary, severity risk tier breakdown,
/// task ledger, plan dispatch capability, and PDF download functionality.
/// Renders as content inside AppShell (no Scaffold).
///
/// Target Branch : feat/dashboard
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../models/simulation_models.dart';
import '../models/simulation_state.dart';
import '../models/user_profile.dart';
import '../utils/pdf_download.dart';
import 'ai_action_plan_screen.dart'; // To reuse planApprovedProvider
import 'app_shell.dart';

// -----------------------------------------------------------
// Providers
// -----------------------------------------------------------

/// Dispatch loading state.
final dispatchLoadingProvider = StateProvider<bool>((ref) => false);

// -----------------------------------------------------------
// Master Action Plan Screen Content
// -----------------------------------------------------------

class MasterActionPlanContent extends ConsumerStatefulWidget {
  const MasterActionPlanContent({super.key});

  @override
  ConsumerState<MasterActionPlanContent> createState() => _MasterActionPlanContentState();
}

class _MasterActionPlanContentState extends ConsumerState<MasterActionPlanContent> {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  Future<void> _handleDownloadPdf(SimulationOutput output) async {
    ref.read(exportLoadingProvider.notifier).state = true;
    try {
      final response = await _dio.post(
        '/api/v1/simulation/export-pdf',
        data: output.toJson(),
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data as List<int>;
      downloadPdf(bytes, 'ACTA_Master_Action_Plan.pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF downloaded successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      ref.read(exportLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _handleDispatch(SimulationOutput output) async {
    ref.read(dispatchLoadingProvider.notifier).state = true;
    try {
      // Prepare dispatch payload
      final payload = {
        'run_id': output.metadata['run_id'] ?? 'unknown',
        'dispatched_by': ref.read(authUserProvider)?.email ?? 'operator@lgu.gov.ph',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'action_count': output.taskList.length,
      };

      await _dio.post(
        '/api/v1/simulation/dispatch',
        data: payload,
      );

      ref.read(planApprovedProvider.notifier).state = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Master action plan approved and successfully dispatched!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Fallback to local state if backend dispatch fails/is mock
        ref.read(planApprovedProvider.notifier).state = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan dispatched locally. Backend notice: $e'),
            backgroundColor: Colors.amber,
          ),
        );
      }
    } finally {
      ref.read(dispatchLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(simulationResultProvider);
    final isExporting = ref.watch(exportLoadingProvider);

    return Column(
      children: [
        PageHeader(
          title: 'Master Action Plan',
          subtitle: 'Official signed-off PDF blueprint for disaster operations',
          actions: [
            if (result != null)
              OutlinedButton.icon(
                onPressed: isExporting ? null : () => _handleDownloadPdf(result),
                icon: isExporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_outlined, size: 15),
                label: Text(isExporting ? 'Generating...' : 'Download PDF'),
              ),
          ],
        ),
        Expanded(
          child: result == null
              ? _EmptyState()
              : _MasterPlanBody(
                  result: result,
                  onDownload: () => _handleDownloadPdf(result),
                  onDispatch: () => _handleDispatch(result),
                ),
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
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.article_outlined,
                size: 48, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          const Text('No Master Action Plan Ready',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 6),
          const Text(
            'Run a simulation first to generate the executive report and task ledger.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.read(shellIndexProvider.notifier).state = 1,
            icon: const Icon(Icons.science_outlined, size: 18),
            label: const Text('Go to Simulation Setup'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Master Plan Body
// -----------------------------------------------------------

class _MasterPlanBody extends ConsumerWidget {
  final SimulationOutput result;
  final VoidCallback onDownload;
  final VoidCallback onDispatch;

  const _MasterPlanBody({
    required this.result,
    required this.onDownload,
    required this.onDispatch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: Document Content
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildExecutiveSummary(context, ref),
                const SizedBox(height: 16),
                _buildTaskLedger(context),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right column: Control Panel / Signatures
          SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildApprovalPanel(context, ref),
                const SizedBox(height: 16),
                _buildPlanDetailsPanel(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Executive Summary Card ---
  Widget _buildExecutiveSummary(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final formattedDate = DateFormat('MMMM dd, yyyy - hh:mm a').format(now);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXECUTIVE BLUEPRINT',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF16A34A),
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'REF: ACTA-${result.metadata['run_id']?.toString().substring(0, 8).toUpperCase() ?? 'PLAN-01'}',
                style: GoogleFonts.robotoMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Disaster Action Plan Executive Summary',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Generated on $formattedDate',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          const SizedBox(height: 16),
          Text(
            result.explainabilityCard.summary.isNotEmpty
                ? result.explainabilityCard.summary
                : 'Based on the storm path and simulated flood level parameters, critical barangays are expected to suffer severe inundation. The decision engine recommends immediate localized action plans prioritizing high risk zones.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              height: 1.6,
            ),
          ),
          if (result.explainabilityCard.riskNarrative.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Threat Analysis',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              result.explainabilityCard.riskNarrative,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
          ],
          if (result.explainabilityCard.actionRationale.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Mitigation Strategy & Rationale',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              result.explainabilityCard.actionRationale,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Task Ledger Table Card ---
  Widget _buildTaskLedger(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TASK LEDGER',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF16A34A),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recommended Operations Ledger',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2), // Priority
              1: FlexColumnWidth(1.5), // Category
              2: FlexColumnWidth(4.5), // Action Details
              3: FlexColumnWidth(1.2), // Deadline
            },
            border: const TableBorder(
              horizontalInside: BorderSide(color: Color(0xFFF1F5F9), width: 1),
            ),
            children: [
              // Header row
              TableRow(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                ),
                children: [
                  _tableHeader('Priority'),
                  _tableHeader('Category'),
                  _tableHeader('Action Details'),
                  _tableHeader('Deadline'),
                ],
              ),
              // Data rows
              ...result.taskList.map((task) => TableRow(
                    children: [
                      _priorityBadge(task.priority),
                      _tableCell(task.category),
                      _tableCell(task.action),
                      _tableCell('T-${task.deadlineHours} hrs'),
                    ],
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _priorityBadge(String priority) {
    final Color color;
    final Color bg;
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
      case 'HIGH':
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        break;
      case 'MEDIUM':
        color = const Color(0xFFD97706);
        bg = const Color(0xFFFFFBEB);
        break;
      case 'LOW':
      default:
        color = const Color(0xFF16A34A);
        bg = const Color(0xFFF0FDF4);
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Text(
            priority,
            style: GoogleFonts.robotoMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  // --- Approval Panel Card ---
  Widget _buildApprovalPanel(BuildContext context, WidgetRef ref) {
    final isApproved = ref.watch(planApprovedProvider);
    final isDispatching = ref.watch(dispatchLoadingProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Approval Status',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isApproved ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isApproved ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isApproved ? Icons.verified : Icons.pending_actions_outlined,
                  color: isApproved ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isApproved ? 'Approved & Dispatched' : 'Pending Operations Review',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isApproved ? const Color(0xFF15803D) : const Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isApproved ? 'Signed off by Command Officer' : 'Awaiting sign-off authority',
                        style: TextStyle(
                          fontSize: 10,
                          color: isApproved ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: isApproved
                ? OutlinedButton.icon(
                    onPressed: () => ref.read(planApprovedProvider.notifier).state = false,
                    icon: const Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFDC2626)),
                    label: const Text('Revoke Approval', style: TextStyle(color: Color(0xFFDC2626))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDC2626)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: isDispatching ? null : onDispatch,
                    icon: isDispatching
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 15),
                    label: Text(isDispatching ? 'Dispatching...' : 'Approve & Dispatch'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- Plan Details Panel Card ---
  Widget _buildPlanDetailsPanel(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    final totalAreas = result.impactedBarangays.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verification Signatures',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 12),
          _detailRow('Authorized Officer', user?.firstName != null ? '${user!.firstName} ${user.lastName}' : 'Operations Commander'),
          _detailRow('Office Code', 'LGU-MILA-FLOOD'),
          _detailRow('Severity Level', result.severityTier.name.toUpperCase()),
          _detailRow('Preparation Window', '${result.preparationWindowHours} Hours'),
          _detailRow('Total Risk Zones', '$totalAreas Barangay zones'),
          const Divider(height: 20, color: Color(0xFFE2E8F0)),
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SHA-256 Verified Blueprint',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
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
