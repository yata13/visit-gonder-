import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
//  Visit Gondar brand, shared with the tourist app:
//  green #2E7D4F · white/cream #F3F7F1 · light green #B7E3BE.
// ═══════════════════════════════════════════════════════════════
class VG {
  static const gold = Color(0xFFB7E3BE);
  static const cream = Color(0xFFF3F7F1);
  static const brown = Color(0xFF2E7D4F);
  static const deep = Color(0xFF16281C);
  static const ink = Color(0xFF17241B);
  static const muted = Color(0xFF5C6E60);
  static const line = Color(0xFFD3E0D6);
  static const goldTint = Color(0xFFE3F1E6);
  static const online = Color(0xFF1F7A4D);
  static const danger = Color(0xFFC4261D);
  static const blue = Color(0xFF2F6FB0);

  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brown,
        primary: brown,
        onPrimary: Colors.white,
        secondary: gold,
        surface: cream,
        onSurface: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brown,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 54),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brown,
          minimumSize: const Size(48, 50),
          side: const BorderSide(color: brown, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brown, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
