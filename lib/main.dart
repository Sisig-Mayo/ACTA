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

import 'views/dashboard_screen.dart';

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
      home: const DashboardScreen(),
    );
  }

  /// Premium dark theme with custom color palette.
  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF00BFA6);     // Teal accent
    const surfaceColor = Color(0xFF1A1D23);     // Deep charcoal
    const cardColor = Color(0xFF22262E);        // Elevated surface
    const errorColor = Color(0xFFFF5252);       // Alert red
    const warningColor = Color(0xFFFFB74D);     // Warning amber

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
