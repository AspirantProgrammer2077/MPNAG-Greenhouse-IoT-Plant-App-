// lib/theme/app_theme.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hux/hux.dart';

class AppTheme {
  // ── Brand palette ─────────────────────────────────────────────────────────
  static const Color primaryGreen   = Color(0xFF1B5E20);
  static const Color accentGreen    = Color(0xFF4CAF50);
  static const Color lightGreen     = Color(0xFFA5D6A7);
  static const Color surfaceGreen   = Color(0xFF2E7D32);
  static const Color mintTeal       = Color(0xFF26A69A);
  static const Color waterBlue      = Color(0xFF1E88E5);
  static const Color waterBlueLight = Color(0xFF64B5F6);
  static const Color alertOrange    = Color(0xFFFF8F00);
  static const Color dangerRed      = Color(0xFFE53935);

  // ── Surface palette ───────────────────────────────────────────────────────
  static const Color bgDark      = Color(0xFF0D1F10);
  static const Color cardDark    = Color(0xFF152518);
  static const Color cardDarker  = Color(0xFF0F1D12);
  static const Color borderColor = Color(0xFF2A4A2E);

  // ── Hux dark theme + green overlay ───────────────────────────────────────
  static ThemeData get darkTheme {
    final base = HuxTheme.darkTheme;
    return base.copyWith(
      scaffoldBackgroundColor: bgDark,
      colorScheme: base.colorScheme.copyWith(
        primary:        accentGreen,
        secondary:      mintTeal,
        surface:        cardDark,
        error:          dangerRed,
        onPrimary:      Colors.white,
        onSurface:      Colors.white,
        surfaceVariant: cardDarker,
        outline:        borderColor,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor:        bgDark,
        elevation:               0,
        scrolledUnderElevation:  0,
        surfaceTintColor:        Colors.transparent,
        centerTitle:             false,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: cardDarker,
        elevation:       0,
      ),
      cardTheme: CardThemeData(
        color:     cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      dividerColor:  borderColor,
      dividerTheme: const DividerThemeData(
          color: borderColor, thickness: 1, space: 1),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected)
                ? accentGreen : Colors.white54),
        trackColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected)
                ? accentGreen.withOpacity(0.35) : Colors.white12),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor:   accentGreen,
        thumbColor:         accentGreen,
        overlayColor:       accentGreen.withOpacity(0.2),
        inactiveTrackColor: borderColor,
        trackHeight:        3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:     cardDarker,
        selectedItemColor:   accentGreen,
        unselectedItemColor: Colors.white38,
        type:                BottomNavigationBarType.fixed,
        elevation:           0,
      ),
    );
  }

  static ThemeData? get lightTheme => null;
}