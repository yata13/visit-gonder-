import 'package:flutter/material.dart';

class AdminColors {
  // Brand — Burnt Orange & Charcoal, matched to the mobile app
  // (names kept for compatibility with existing screens).
  static const gold       = Color(0xFFFF6D29);  // vibrant orange (primary accent)
  static const goldLight  = Color(0xFFFFE7DC);  // soft orange tint
  static const bronze     = Color(0xFF161316);  // near-black charcoal (dark)
  static const bronzeLight= Color(0xFF2A1812);

  // UI
  static const background = Color(0xFFF7F4F1);   // clean warm white (app background)
  static const surface    = Color(0xFFFFFFFF);
  static const sidebar    = Color(0xFF161316);   // charcoal sidebar (app nav)
  static const sidebarHover = Color(0xFF2A1812);

  // Text
  static const textPrimary   = Color(0xFF161316);
  static const textSecondary = Color(0xFF524B45);
  static const textMuted     = Color(0xFF8C857F);

  // Status
  static const success    = Color(0xFF1F7A4D);
  static const successBg  = Color(0xFFE3F3E9);
  static const warning    = Color(0xFFD2541A);
  static const warningBg  = Color(0xFFFFF0E6);
  static const error      = Color(0xFFBA1A1A);
  static const errorBg    = Color(0xFFFFDAD6);
  static const info       = Color(0xFFB5481F);
  static const infoBg     = Color(0xFFFBE9E1);

  // Vibrant accent palette (colorful stat tiles) — warm range
  static const violet = Color(0xFFFF6D29);  // orange (was violet)
  static const blue   = Color(0xFFB5481F);  // burnt orange
  static const green  = Color(0xFF1F7A4D);
  static const amber  = Color(0xFFFF8A3C);
  static const rose   = Color(0xFFD2541A);
  static const cyan   = Color(0xFF7E3315);  // rust dark

  // Border
  static const border     = Color(0xFFEAE5E0);
}

class AdminTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AdminColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AdminColors.gold,
      background: AdminColors.background,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AdminColors.surface,
      foregroundColor: AdminColors.textPrimary,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: AdminColors.textPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminColors.gold,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdminColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
            color: AdminColors.gold, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: AdminColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AdminColors.border),
      ),
    ),
  );
}
