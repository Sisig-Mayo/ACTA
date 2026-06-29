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
import 'package:dio/dio.dart';

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

/// Settings overlay visibility.
final settingsOverlayVisibleProvider = StateProvider<bool>((ref) => false);

/// Local notification preferences.
final simulationCompleteNotificationsProvider = StateProvider<bool>(
  (ref) => true,
);
final criticalRiskNotificationsProvider = StateProvider<bool>((ref) => true);
final dispatchNotificationsProvider = StateProvider<bool>((ref) => true);

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
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFD1D5DB)),
        foregroundColor: const Color(0xFF374151),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: const Color(0xFF6B7280),
      indicatorColor: primary,
      dividerColor: const Color(0xFFE5E7EB),
      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
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
    return Theme(data: buildDashboardTheme(), child: const _ShellScaffold());
  }
}

class _ShellScaffold extends ConsumerWidget {
  const _ShellScaffold();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(shellIndexProvider);
    final isRunSim = ref.watch(runSimulationActiveProvider);
    final simState = ref.watch(simulationRunStateProvider);
    final settingsVisible = ref.watch(settingsOverlayVisibleProvider);

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
      drawer: isMobile
          ? Drawer(child: _Sidebar(selectedIndex: selectedIndex))
          : null,
      body: Stack(
        children: [
          Row(
            children: [
              if (!isMobile) _Sidebar(selectedIndex: selectedIndex),
              Expanded(child: pageContent),
            ],
          ),
          if (settingsVisible) const _SettingsOverlay(),
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
            if (toastVisible)
              _NotificationToast(
                onDismiss: () =>
                    ref.read(toastVisibleProvider.notifier).state = false,
              ),

            // --- Settings ---
            const Divider(color: Color(0xFF1E293B), height: 1),
            _NavTile(
              item: const _NavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
              ),
              isSelected: false,
              onTap: () {
                ref.read(settingsOverlayVisibleProvider.notifier).state = true;
                if (Scaffold.of(context).isDrawerOpen) {
                  Navigator.of(context).pop();
                }
              },
            ),
            _NavTile(
              item: const _NavItem(
                icon: Icons.logout_outlined,
                label: 'Logout',
              ),
              isSelected: false,
              onTap: () async {
                await AuthStorage.clearToken();
                ref.read(authUserProvider.notifier).state = null;
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const _LogoutRedirect()),
                    (_) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
    final displayName = user?.fullName.trim();
    final email = user?.email.trim();

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
                Text(
                  displayName?.isNotEmpty == true
                      ? displayName!
                      : 'No active operator',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email?.isNotEmpty == true ? email! : 'Not signed in',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'New',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(
                    Icons.close,
                    size: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Notifications sent here',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(
                  Icons.open_in_new,
                  size: 10,
                  color: Color(0xFF16A34A),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// Settings Overlay
// -----------------------------------------------------------

class _SettingsOverlay extends ConsumerStatefulWidget {
  const _SettingsOverlay();

  @override
  ConsumerState<_SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends ConsumerState<_SettingsOverlay> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://acta-production.up.railway.app',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  bool _isSavingPassword = false;
  bool _isCheckingStatus = true;
  bool _apiHealthy = false;
  bool _sessionHealthy = false;
  String _statusMessage = 'Checking services...';

  @override
  void initState() {
    super.initState();
    _checkSystemStatus();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkSystemStatus() async {
    setState(() {
      _isCheckingStatus = true;
      _statusMessage = 'Checking services...';
    });

    var apiHealthy = false;
    var sessionHealthy = false;
    var message = 'Some services need attention.';

    try {
      final health = await _dio.get('/health');
      apiHealthy = health.statusCode == 200;

      final user = ref.read(authUserProvider);
      if (user != null) {
        final session = await _dio.get(
          '/api/v1/auth/me',
          options: Options(
            headers: {'Authorization': 'Bearer ${user.accessToken}'},
          ),
        );
        sessionHealthy = session.statusCode == 200;
      }

      if (apiHealthy && sessionHealthy) {
        message = 'API and current session are online.';
      } else if (apiHealthy) {
        message = 'API is online, but the current session was not verified.';
      }
    } catch (e) {
      message = 'Unable to reach ACTA services.';
    }

    if (!mounted) return;
    setState(() {
      _apiHealthy = apiHealthy;
      _sessionHealthy = sessionHealthy;
      _statusMessage = message;
      _isCheckingStatus = false;
    });
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authUserProvider);
    if (user == null) {
      _showSnack('Your session is no longer available.', Colors.redAccent);
      return;
    }

    setState(() => _isSavingPassword = true);
    try {
      await _dio.post(
        '/api/v1/auth/change-password',
        data: {
          'current_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
        },
        options: Options(
          headers: {'Authorization': 'Bearer ${user.accessToken}'},
        ),
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnack('Password changed successfully.', const Color(0xFF16A34A));
    } on DioException catch (e) {
      final detail =
          e.response?.data?['detail']?.toString() ?? 'Password update failed.';
      _showSnack(detail, Colors.redAccent);
    } catch (_) {
      _showSnack('Password update failed.', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _close() {
    ref.read(settingsOverlayVisibleProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    final isMobile = MediaQuery.of(context).size.width < 720;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            child: Container(color: Colors.black.withValues(alpha: 0.42)),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 920,
              maxHeight: MediaQuery.of(context).size.height - 48,
            ),
            child: Material(
              color: Colors.white,
              elevation: 24,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SettingsHeader(onClose: _close),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: isMobile
                          ? Column(
                              children: [
                                _AccountDetailsSection(user: user),
                                const SizedBox(height: 14),
                                _PasswordSection(
                                  formKey: _formKey,
                                  currentPasswordController:
                                      _currentPasswordController,
                                  newPasswordController: _newPasswordController,
                                  confirmPasswordController:
                                      _confirmPasswordController,
                                  isSaving: _isSavingPassword,
                                  onSubmit: _changePassword,
                                ),
                                const SizedBox(height: 14),
                                const _NotificationSettingsSection(),
                                const SizedBox(height: 14),
                                _SystemStatusSection(
                                  isChecking: _isCheckingStatus,
                                  apiHealthy: _apiHealthy,
                                  sessionHealthy: _sessionHealthy,
                                  message: _statusMessage,
                                  onRefresh: _checkSystemStatus,
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      _AccountDetailsSection(user: user),
                                      const SizedBox(height: 14),
                                      _SystemStatusSection(
                                        isChecking: _isCheckingStatus,
                                        apiHealthy: _apiHealthy,
                                        sessionHealthy: _sessionHealthy,
                                        message: _statusMessage,
                                        onRefresh: _checkSystemStatus,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    children: [
                                      _PasswordSection(
                                        formKey: _formKey,
                                        currentPasswordController:
                                            _currentPasswordController,
                                        newPasswordController:
                                            _newPasswordController,
                                        confirmPasswordController:
                                            _confirmPasswordController,
                                        isSaving: _isSavingPassword,
                                        onSubmit: _changePassword,
                                      ),
                                      const SizedBox(height: 14),
                                      const _NotificationSettingsSection(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _SettingsHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: Color(0xFF16A34A),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Operator account, alerts, and system health',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _AccountDetailsSection extends StatelessWidget {
  final UserProfile? user;
  const _AccountDetailsSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = user?.fullName.trim();
    final email = user?.email.trim();

    return _SettingsSection(
      title: 'Account Details',
      icon: Icons.badge_outlined,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF16A34A),
              child: Text(
                user?.initials.isNotEmpty == true ? user!.initials : 'OP',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName?.isNotEmpty == true
                        ? displayName!
                        : 'No active operator',
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email?.isNotEmpty == true ? email! : 'Not signed in',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SettingsDetailRow(
          label: 'User ID',
          value: user?.id.isNotEmpty == true ? user!.id : 'Unavailable',
        ),
        _SettingsDetailRow(
          label: 'Access',
          value: user == null ? 'No active session' : 'Authenticated session',
        ),
      ],
    );
  }
}

class _PasswordSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool isSaving;
  final VoidCallback onSubmit;

  const _PasswordSection({
    required this.formKey,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.isSaving,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Change Password',
      icon: Icons.lock_outline,
      children: [
        Form(
          key: formKey,
          child: Column(
            children: [
              _PasswordField(
                controller: currentPasswordController,
                label: 'Current password',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _PasswordField(
                controller: newPasswordController,
                label: 'New password',
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Use at least 6 characters';
                  }
                  if (value == currentPasswordController.text) {
                    return 'Use a different password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _PasswordField(
                controller: confirmPasswordController,
                label: 'Confirm new password',
                validator: (value) {
                  if (value != newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : onSubmit,
                  icon: isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 16),
                  label: Text(isSaving ? 'Saving...' : 'Update Password'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.validator,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline, size: 18),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

class _NotificationSettingsSection extends ConsumerWidget {
  const _NotificationSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsSection(
      title: 'Notifications',
      icon: Icons.notifications_active_outlined,
      children: [
        _SettingsSwitchRow(
          title: 'Simulation complete',
          subtitle: 'Alert when AI results are ready',
          value: ref.watch(simulationCompleteNotificationsProvider),
          onChanged: (value) {
            ref.read(simulationCompleteNotificationsProvider.notifier).state =
                value;
          },
        ),
        _SettingsSwitchRow(
          title: 'Critical risk threshold',
          subtitle: 'Alert when high-priority barangays are detected',
          value: ref.watch(criticalRiskNotificationsProvider),
          onChanged: (value) {
            ref.read(criticalRiskNotificationsProvider.notifier).state = value;
          },
        ),
        _SettingsSwitchRow(
          title: 'Dispatch updates',
          subtitle: 'Alert when master plan dispatch changes',
          value: ref.watch(dispatchNotificationsProvider),
          onChanged: (value) {
            ref.read(dispatchNotificationsProvider.notifier).state = value;
          },
        ),
      ],
    );
  }
}

class _SystemStatusSection extends StatelessWidget {
  final bool isChecking;
  final bool apiHealthy;
  final bool sessionHealthy;
  final String message;
  final VoidCallback onRefresh;

  const _SystemStatusSection({
    required this.isChecking,
    required this.apiHealthy,
    required this.sessionHealthy,
    required this.message,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'System Status',
      icon: Icons.monitor_heart_outlined,
      children: [
        _StatusRow(
          label: 'ACTA API',
          healthy: apiHealthy,
          isChecking: isChecking,
        ),
        _StatusRow(
          label: 'Current session',
          healthy: sessionHealthy,
          isChecking: isChecking,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isChecking ? null : onRefresh,
            icon: isChecking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(isChecking ? 'Checking...' : 'Refresh Status'),
          ),
        ),
      ],
    );
  }
}

class _SettingsDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _SettingsDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF16A34A),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool healthy;
  final bool isChecking;

  const _StatusRow({
    required this.label,
    required this.healthy,
    required this.isChecking,
  });

  @override
  Widget build(BuildContext context) {
    final color = isChecking
        ? const Color(0xFFF59E0B)
        : healthy
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    final text = isChecking
        ? 'Checking'
        : healthy
        ? 'Online'
        : 'Unavailable';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
            Wrap(spacing: 8, runSpacing: 8, children: actions),
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
