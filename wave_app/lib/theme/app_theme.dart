import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// wave. — Design system
/// Colors, typography, and motion constants.
/// Exact spec from the design session.
class AppTheme {
  // ── Colors ────────────────────────────────────────────
  static const bg = Color(0xFF0A0A0F);
  static const surface = Color(0xFF13131A);
  static const surface2 = Color(0xFF1C1C28);
  static const accent = Color(0xFFC8FF57); // acid lime — primary CTA
  static const accent2 = Color(0xFFFF5C87); // pink-red — artwork gradients only
  static const accent3 = Color(0xFF5CE0FF); // cyan — artwork gradients only
  static const textPrimary = Color(0xFFF0F0F5);
  static const textMuted = Color(0xFF6B6B85);
  static const border = Color(0x12FFFFFF); // 7% white

  // ── Motion ────────────────────────────────────────────
  static const Duration pageTransition = Duration(milliseconds: 280);
  static const Duration staggerDelay = Duration(milliseconds: 40);
  static const Duration pressScale = Duration(milliseconds: 200);
  static const Duration eqPresetTween = Duration(milliseconds: 300);
  static const Duration albumRotation = Duration(seconds: 20);
  static const Duration blobFloat = Duration(seconds: 8);
  static const Curve defaultCurve = Curves.easeOutCubic;

  // ── Radii ─────────────────────────────────────────────
  static const double cardRadius = 12.0;
  static const double searchRadius = 16.0;
  static const double artworkRadius = 24.0;
  static const double moodCardRadius = 18.0;
  static const double buttonRadius = 8.0;

  // ── ThemeData ─────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          surface: surface,
          onPrimary: Colors.black,
          onSurface: textPrimary,
        ),
        textTheme: GoogleFonts.syneTextTheme().copyWith(
          // Syne for display/headings
          displayLarge: GoogleFonts.syne(
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
          headlineMedium: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          titleLarge: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          titleMedium: GoogleFonts.syne(
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          // DM Sans for body
          bodyLarge: GoogleFonts.dmSans(color: textPrimary),
          bodyMedium: GoogleFonts.dmSans(color: textMuted),
          bodySmall: GoogleFonts.dmSans(color: textMuted, fontSize: 11),
          labelLarge: GoogleFonts.dmSans(
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
          labelMedium: GoogleFonts.dmSans(
            fontWeight: FontWeight.w400,
            color: textMuted,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: accent,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
        ),
      );
}
