/// ACTA Frontend — Explainability Card Widget
/// =============================================
/// Renders the Gemini AI-generated plain-language Explainability Card
/// in a clean, highly legible format for LGU operators.
///
/// Sections:
///   - Executive Summary
///   - Risk Narrative
///   - Action Rationale
///   - Confidence Note (caveats / model disclosure)
///
/// Target Branch : feature/frontend-dashboard
/// Commit        : feat(frontend): build responsive layout controls and map visualization canvas stubs
library;

import 'package:flutter/material.dart';

import '../../models/simulation_models.dart';

class ExplainabilityCardWidget extends StatelessWidget {
  final ExplainabilityCard card;

  const ExplainabilityCardWidget({
    super.key,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E2330),
            const Color(0xFF1A1D23),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00BFA6).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF2A2E36), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Color(0xFF00BFA6),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explainability Card',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'AI-Generated Analysis',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF00BFA6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.smart_toy_outlined, size: 12, color: Color(0xFF9CA3AF)),
                      SizedBox(width: 4),
                      Text(
                        'Gemini',
                        style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sections
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Executive Summary
                _buildSection(
                  icon: Icons.summarize_outlined,
                  title: 'Executive Summary',
                  content: card.summary,
                  accentColor: const Color(0xFF00BFA6),
                ),
                const SizedBox(height: 16),

                // Risk Narrative
                _buildSection(
                  icon: Icons.warning_amber_rounded,
                  title: 'Risk Narrative',
                  content: card.riskNarrative,
                  accentColor: const Color(0xFFFFB74D),
                ),
                const SizedBox(height: 16),

                // Action Rationale
                _buildSection(
                  icon: Icons.psychology_outlined,
                  title: 'Action Rationale',
                  content: card.actionRationale,
                  accentColor: const Color(0xFF26C6DA),
                ),
                const SizedBox(height: 16),

                // Confidence Note
                _buildConfidenceNote(card.confidenceNote),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a labeled section with icon and accent color.
  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: accentColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accentColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.6,
            color: Color(0xFFD1D5DB),
          ),
        ),
      ],
    );
  }

  /// Special styling for the confidence/caveats section.
  Widget _buildConfidenceNote(String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF6B7280).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: Color(0xFF6B7280)),
              SizedBox(width: 6),
              Text(
                'Confidence & Caveats',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Color(0xFF9CA3AF),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
