import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  appImage — one image widget that works for BOTH:
//    • a web URL  ->  'https://....jpg'      (loaded from internet)
//    • a local file -> 'assets/images/x.png' (bundled in the app)
//
//  Just paste either kind of string into app_constants.dart and
//  this picks the right loader automatically.
// ═══════════════════════════════════════════════════════════════
Widget appImage(String src, {BoxFit fit = BoxFit.cover}) {
  final fallback = Container(color: AppColors.surfaceContainer);

  if (src.startsWith('http')) {
    return Image.network(src, fit: fit,
        errorBuilder: (_, __, ___) => fallback);
  }
  return Image.asset(src, fit: fit,
      errorBuilder: (_, __, ___) => fallback);
}
