/// ACTA Frontend — Application Entry Point
/// ==========================================
/// Initializes the Flutter application with Riverpod state
/// management and routes to the LGU Operator Dashboard.
///
/// Target Branch : feature/frontend-dashboard
/// Commit        : feat(frontend): build responsive layout controls and map visualization canvas stubs
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import 'models/user_profile.dart';
import 'utils/auth_storage.dart';
import 'views/login_screen.dart';
import 'views/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ActaApp()));
}

/// Root application widget.
class ActaApp extends StatelessWidget {
  const ActaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACTA — Decision-to-Action Engine',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: _buildDarkTheme(),
      home: const _AuthGate(),
    );
  }

  /// Premium dark theme with custom color palette.
  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF00BFA6);     // Teal accent
    const surfaceColor = Color(0xFF1A1D23);     // Deep charcoal
    const cardColor = Color(0xFF22262E);        // Elevated surface
    const errorColor = Color(0xFFFF5252);       // Alert red

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: Color(0xFF26C6DA),
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF12141A),
      cardColor: cardColor,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryColor,
        thumbColor: primaryColor,
        overlayColor: Color(0x2900BFA6),
        inactiveTrackColor: Color(0xFF3A3F4B),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A3F4B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A3F4B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// -----------------------------------------------------------
// Auth Gate — Session Restoration on Page Refresh
// -----------------------------------------------------------

/// Checks for a persisted auth token on startup and either
/// restores the session (navigating to AppShell) or shows
/// the LoginScreen.
class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  bool _checking = true;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        // No stored token — go straight to login
        if (mounted) setState(() => _checking = false);
        return;
      }

      // Validate the token against the backend
      final response = await _dio.get(
        '/api/v1/auth/me',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final userData = response.data as Map<String, dynamic>;
        // Restore user state
        ref.read(authUserProvider.notifier).state =
            UserProfile.fromJson(userData, token);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AppShell()),
          );
        }
        return;
      }
    } catch (_) {
      // Token invalid/expired or backend unreachable — clear it
      await AuthStorage.clearToken();
    }

    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      // Show a loading indicator while validating the session
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return const LoginScreen();
  }
}
