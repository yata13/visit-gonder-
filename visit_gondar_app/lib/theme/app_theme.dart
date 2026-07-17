import 'package:flutter/material.dart';

class AppColors {
  // ── Burnt Orange & Charcoal palette ───────────────────
  //  Warm, modern, premium. Vibrant orange accent on near-black
  //  and dark brown, over a clean warm-white. `charcoal` is the
  //  brand dark (near-black) for nav, buttons and headings;
  //  `gold` is the orange accent used throughout.
  static const charcoal     = Color(0xFF161316);  // near-black (primary dark)
  static const gold         = Color(0xFFFF6D29);  // vibrant orange (accent)
  static const rust         = Color(0xFFB5481F);  // burnt orange (secondary)
  static const background   = Color(0xFFF7F4F1);  // clean warm white

  // Derived tones
  static const goldDark     = Color(0xFFD2541A);  // deeper orange text on light
  static const goldDeep     = Color(0xFF2A1812);  // near-black-brown (text on orange)
  static const bronze       = Color(0xFF453027);  // dark brown
  static const amber        = Color(0xFFFF8A3C);
  static const rustDark     = Color(0xFF7E3315);
  static const darkBrown    = Color(0xFF453027);  // dark brown
  static const nearBlack    = Color(0xFF161316);

  // Surface
  static const surfaceBright        = Color(0xFFFFFFFF);
  static const surfaceVariant       = Color(0xFFE7E3DF);
  static const surfaceContainer     = Color(0xFFF1EDE9);
  static const surfaceContainerHigh = Color(0xFFEAE5E0);

  // Text — neutral & readable
  static const onBackground  = Color(0xFF161316);
  static const onSurface     = Color(0xFF161316);
  static const textMuted     = Color(0xFF8C857F);
  static const textSecondary = Color(0xFF524B45);

  // Status
  static const error        = Color(0xFFBA1A1A);
  static const errorLight   = Color(0xFFFFDAD6);
  static const green        = Color(0xFF1F7A4D);  // success
  static const greenLight   = Color(0xFFE3F3E9);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.charcoal,
      surface: AppColors.background,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.onBackground,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: AppColors.onBackground,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.charcoal,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: Color(0xFF9A8C7C),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}
