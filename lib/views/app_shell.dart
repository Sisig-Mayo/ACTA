/// ACTA Frontend — App Shell
/// ==========================
/// Persistent layout wrapper that provides the left navigation
/// sidebar and content area for all post-login screens.
/// Applies the light dashboard theme over the dark login theme.
///
/// Target Branch : feat/dashboard
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../models/simulation_state.dart';
import '../utils/auth_storage.dart';
import 'command_center_screen.dart';
import 'simulation_setup_screen.dart';
import 'run_simulation_screen.dart';
import 'ai_action_plan_screen.dart';
import 'resource_management_screen.dart';
import 'master_action_plan_screen.dart';
import 'login_screen.dart';

// -----------------------------------------------------------
// Navigation State
// -----------------------------------------------------------

/// Which top-level nav item is selected (0–4).
final shellIndexProvider = StateProvider<int>((ref) => 0);

/// Whether the Run Simulation sub-screen is active (within Simulation).
final runSimulationActiveProvider = StateProvider<bool>((ref) => false);

/// Notification toast visibility.
final toastVisibleProvider = StateProvider<bool>((ref) => true);

// -----------------------------------------------------------
// Light Dashboard Theme
// -----------------------------------------------------------

ThemeData buildDashboardTheme() {
  const primary = Color(0xFF16A34A);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: Color(0xFF0EA5E9),
      surface: Colors.white,
      error: Color(0xFFDC2626),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF111827),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    cardColor: Colors.white,
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    dividerColor: const Color(0xFFE2E8F0),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle:
            GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFD1D5DB)),
        foregroundColor: const Color(0xFF374151),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle:
            GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: const Color(0xFF6B7280),
      indicatorColor: primary,
      dividerColor: const Color(0xFFE5E7EB),
      labelStyle:
          GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle:
          GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: Color(0xFFD1D5DB)),
    ),
  );
}

// -----------------------------------------------------------
// App Shell
// -----------------------------------------------------------

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Theme(
      data: buildDashboardTheme(),
      child: const _ShellScaffold(),
    );
  }
}

class _ShellScaffold extends ConsumerWidget {
  const _ShellScaffold();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(shellIndexProvider);
    final isRunSim = ref.watch(runSimulationActiveProvider);
    final simState = ref.watch(simulationRunStateProvider);

    final Widget pageContent;
    // Show RunSimulationContent if:
    // 1. We're on the Simulation tab AND runSimulationActive is true, OR
    // 2. We're on the Simulation tab AND the simulation is still running
    if (selectedIndex == 1 &&
        (isRunSim || simState == SimulationRunState.running)) {
      pageContent = const RunSimulationContent();
    } else {
      pageContent = switch (selectedIndex) {
        0 => const CommandCenterContent(),
        1 => const SimulationSetupContent(),
        2 => const AiActionPlanContent(),
        3 => const ResourceManagementContent(),
        4 => const MasterActionPlanContent(),
        _ => const CommandCenterContent(),
      };
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: isMobile ? Drawer(child: _Sidebar(selectedIndex: selectedIndex)) : null,
      body: Row(
        children: [
          if (!isMobile) _Sidebar(selectedIndex: selectedIndex),
          Expanded(child: pageContent),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Sidebar
// -----------------------------------------------------------

const _kSidebarBg = Color(0xFF0F172A);
const _kSidebarWidth = 200.0;

class _Sidebar extends ConsumerWidget {
  final int selectedIndex;
  const _Sidebar({required this.selectedIndex});

  static const _navItems = [
    _NavItem(icon: Icons.grid_view_rounded, label: 'Command Center'),
    _NavItem(icon: Icons.science_outlined, label: 'Simulation'),
    _NavItem(icon: Icons.auto_awesome_outlined, label: 'AI Action Plan'),
    _NavItem(icon: Icons.inventory_2_outlined, label: 'Resources'),
    _NavItem(icon: Icons.article_outlined, label: 'Master Plan'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    final toastVisible = ref.watch(toastVisibleProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      width: isMobile ? 240 : _kSidebarWidth,
      color: _kSidebarBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Brand / User ---
            _BrandHeader(user: user),
  
            const SizedBox(height: 8),
            const Divider(color: Color(0xFF1E293B), height: 1),
            const SizedBox(height: 8),
  
            // --- Nav Items ---
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: _navItems.length,
                itemBuilder: (context, i) {
                  return _NavTile(
                    item: _navItems[i],
                    isSelected: selectedIndex == i,
                    onTap: () {
                      ref.read(shellIndexProvider.notifier).state = i;
                      // Only reset run sim flag if the simulation is NOT running
                      final simState = ref.read(simulationRunStateProvider);
                      if (simState != SimulationRunState.running) {
                        ref.read(runSimulationActiveProvider.notifier).state =
                            false;
                      }
                      if (Scaffold.of(context).isDrawerOpen) {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                },
              ),
            ),

          // --- Notification Toast ---
          if (toastVisible) _NotificationToast(
            onDismiss: () =>
                ref.read(toastVisibleProvider.notifier).state = false,
          ),

          // --- Settings ---
          const Divider(color: Color(0xFF1E293B), height: 1),
          _NavTile(
            item: const _NavItem(
                icon: Icons.settings_outlined, label: 'Settings'),
            isSelected: false,
            onTap: () {},
          ),
          _NavTile(
            item: const _NavItem(
                icon: Icons.logout_outlined, label: 'Logout'),
            isSelected: false,
            onTap: () async {
              await AuthStorage.clearToken();
              ref.read(authUserProvider.notifier).state = null;
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const _LogoutRedirect(),
                  ),
                  (_) => false,
                );
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      )),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 17,
                color: isSelected
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final UserProfile? user;
  const _BrandHeader({this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                '#',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Flood Command',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user?.email ?? 'operator@lgu.gov.ph',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down,
              color: Color(0xFF64748B), size: 16),
        ],
      ),
    );
  }
}

class _NotificationToast extends StatelessWidget {
  final VoidCallback onDismiss;
  const _NotificationToast({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('New',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(Icons.close,
                      size: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Notifications sent here',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            const Text(
              'This is a sample, check it out!',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text(
                  'Try it out ',
                  style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.open_in_new,
                    size: 10, color: Color(0xFF16A34A)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// Shared Page Header Widget (reused by all content screens)
// -----------------------------------------------------------

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 28, 20, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isMobile) ...[
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile && actions.isNotEmpty) ...[
                const SizedBox(width: 16),
                ...actions,
              ],
            ],
          ),
          if (isMobile && actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Logout Redirect Helper
// -----------------------------------------------------------

/// Navigates back to the login screen after logout.
/// Used to avoid circular import issues between login and app_shell.
class _LogoutRedirect extends StatelessWidget {
  const _LogoutRedirect();

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}
