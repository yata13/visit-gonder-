import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/motion.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN SYSTEM v0.7 — "Gondar green"
//  Brand palette: green #2E7D4F · white/cream #F3F7F1 · light
//  green #B7E3BE. Green carries text and main buttons on white;
//  light green marks the active / highlighted thing. Other colour
//  is MEANING only:
//   • SOS red     — SOS and danger, never errors or decoration
//   • Safe green  — Safety Desk and "I'm safe" only (deeper, more
//                   saturated than the brand green, kept distinct)
//   • Amber       — pending / in review / warning zone
//   • Blue        — confirmed / published / info
//   • Verified    — the blue tick on approved partners
//   • Clay        — form errors, failed payment
// ═══════════════════════════════════════════════════════════════
class AppColors {
  // ── Brand ─────────────────────────────────────────────
  static const brandGold  = Color(0xFFB7E3BE); // highlights, active pill (light green)
  static const brandCream = Color(0xFFF3F7F1); // app background (soft white)
  static const brandBrown = Color(0xFF2E7D4F); // main buttons, icons (brand green)
  static const goldTint   = Color(0xFFE3F1E6); // soft green wash

  // ── Neutrals (cool, built from the brand) ─────────────
  static const ink      = brandBrown;        // icons, main buttons
  static const black    = Color(0xFF17241B); // headings, kicker text
  static const ink700   = Color(0xFF1F3326); // body text, dark cards
  static const muted    = Color(0xFF5C6E60); // captions, meta
  static const line     = Color(0xFFD3E0D6); // borders, dividers
  static const stone    = Color(0xFFDCE8DF); // photo placeholders, wells
  static const gray100  = Color(0xFFE0ECE2); // soft highlight, selected row
  static const ground   = brandCream;        // app background
  static const surface  = Color(0xFFFFFFFF); // cards, sheets
  static const onDark   = Color(0xFFFFFFFF);
  static const onDarkMuted = Color(0xFFD3E0D6);

  // Night — headers, hero cards, dark tiles (deep green)
  static const night1 = Color(0xFF16281C);
  static const night2 = Color(0xFF2F6B46);
  static const night3 = brandBrown;

  // ── Meaning — fixed, never decoration ─────────────────
  static const sos         = Color(0xFFC4261D);
  static const dangerTint  = Color(0xFFFCE5E3);
  static const dangerInk   = Color(0xFFB3211A);
  static const safe        = Color(0xFF1C6B3F);
  static const safeTint    = Color(0xFFE2F1E7);
  static const amberTint   = Color(0xFFFFF1CC);
  static const amberInk    = Color(0xFF7A4F00);
  static const infoTint    = Color(0xFFE3ECF6);
  static const infoInk     = Color(0xFF24527F);
  static const locationBlue = Color(0xFF2F6FB0);
  static const verified    = Color(0xFF2158C4);
  static const verifiedTint = Color(0xFFE1EAFB);
  static const clayTint    = Color(0xFFFCEBDD);
  static const clayInk     = Color(0xFF9A4114);

  // ── Legacy names (older screens) → mapped onto v0.5 ───
  static const charcoal     = ink;
  static const gold         = brandBrown; // legacy name: buttons + text, keep readable
  static const rust         = ink700;
  static const background   = ground;
  static const goldDark     = brandBrown;
  static const goldDeep     = black;
  static const bronze       = ink700;
  static const amber        = amberInk;
  static const rustDark     = black;
  static const darkBrown    = ink700;
  static const nearBlack    = black;
  static const surfaceBright        = surface;
  static const surfaceVariant       = line;
  static const surfaceContainer     = gray100;
  static const surfaceContainerHigh = stone;
  static const onBackground  = ink;
  static const onSurface     = ink;
  static const textMuted     = muted;
  static const textSecondary = ink700;
  static const error        = sos;
  static const errorLight   = dangerTint;
  static const green        = safe;
  static const greenLight   = safeTint;
}

/// Corners, spacing and shared decorations from the design.
class AppRadius {
  static const tag = 8.0, button = 12.0, card = 16.0, sheet = 24.0;
  static const glass = 24.0, tile = 28.0, hero = 32.0;
}

class AppDecor {
  /// Frosted white card: white 66% + blur, inner white hairline.
  static BoxDecoration glass({double radius = AppRadius.glass}) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 24,
              offset: Offset(0, 8)),
        ],
      );

  /// Solid white card with a faint outline.
  static BoxDecoration card({double radius = AppRadius.glass}) =>
      BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 24,
              offset: Offset(0, 8)),
          BoxShadow(color: Color(0x12000000), spreadRadius: 1),
        ],
      );

  /// Night gradient: hero cards, headers, dark tiles.
  static BoxDecoration night({double radius = AppRadius.hero}) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.night1, AppColors.night2, AppColors.night3],
          stops: [0, 0.6, 1],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x4D000000), blurRadius: 40,
              offset: Offset(0, 16)),
        ],
      );
}

/// Font families: Schibsted Grotesk for Latin, Noto Sans Ethiopic
/// for Amharic (used automatically as the fallback).
class AppFonts {
  static String? get latin => GoogleFonts.schibstedGrotesk().fontFamily;
  static String? get ethiopic => GoogleFonts.notoSansEthiopic().fontFamily;
  static List<String> get fallback => [if (ethiopic != null) ethiopic!];

  /// Button labels need the family spelled out: a ButtonStyle
  /// textStyle replaces (not merges with) the theme's text style.
  static TextStyle button(double size, [FontWeight w = FontWeight.w700]) =>
      TextStyle(fontFamily: latin, fontFamilyFallback: fallback,
          fontSize: size, fontWeight: w);
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true);
    final fallback = [if (AppFonts.ethiopic != null) AppFonts.ethiopic!];
    TextStyle btn(double size, [FontWeight w = FontWeight.w700]) => TextStyle(
        fontFamily: AppFonts.latin, fontFamilyFallback: fallback,
        fontSize: size, fontWeight: w);
    final text = GoogleFonts.schibstedGroteskTextTheme(base.textTheme)
        .apply(
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
          fontFamilyFallback: fallback,
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ground,
      textTheme: text,
      primaryTextTheme: text,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.ink,
        primary: AppColors.ink,
        onPrimary: Colors.white,
        secondary: AppColors.black,
        surface: AppColors.ground,
        onSurface: AppColors.ink,
        error: AppColors.clayInk,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ground,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800, fontSize: 19,
            color: AppColors.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundBuilder: pressedForeground,
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          textStyle: btn(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundBuilder: pressedForeground,
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          textStyle: btn(16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundBuilder: pressedForeground,
          foregroundColor: AppColors.ink,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.ink, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: btn(15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundBuilder: pressedForeground,
          foregroundColor: AppColors.ink,
          textStyle: btn(14, FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: AppColors.muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: Color(0xFF8C8C8C)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: Color(0xFF8C8C8C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.ink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.clayInk),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.ink,
        side: const BorderSide(color: Color(0xFF8C8C8C)),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600,
            color: AppColors.ink),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sheet)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.ink),
      dividerTheme:
          const DividerThemeData(color: AppColors.stone, thickness: 1),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: SmoothPageTransitionsBuilder(),
        TargetPlatform.iOS: SmoothPageTransitionsBuilder(),
      }),
    );
  }
}

/// Soft grey "glass" backdrop used behind every main screen.
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.ground),
      child: Stack(children: [
        const Positioned.fill(child: IgnorePointer(child: _Glow())),
        child,
      ]),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow();
  @override
  Widget build(BuildContext context) {
    Widget blob(Alignment a, Color c) => Align(
          alignment: a,
          child: FractionallySizedBox(
            widthFactor: 1.1,
            heightFactor: 0.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [c, c.withValues(alpha: 0)],
                  stops: const [0, 0.7],
                ),
              ),
            ),
          ),
        );
    return Stack(children: [
      blob(const Alignment(1.2, -1.1), const Color(0x66B7E3BE)),
      blob(const Alignment(-1.2, -0.05), const Color(0xFFDCE8DF)),
      blob(const Alignment(1.2, 0.75), const Color(0x4DB7E3BE)),
    ]);
  }
}

/// Frosted glass panel (white 66% + 16px blur).
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final bool blur;
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = AppRadius.glass,
    this.padding,
    this.blur = false,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: AppDecor.glass(radius: radius),
      child: child,
    );
    if (!blur) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: box,
      ),
    );
  }
}
