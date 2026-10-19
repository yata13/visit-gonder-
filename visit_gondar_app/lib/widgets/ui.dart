// ═══════════════════════════════════════════════════════════════
//  Shared building blocks of the v0.5 "black & white glass" design:
//  app mark, glass buttons, section headers, SOS button, tiles.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'motion.dart';
import '../screens/emergency/emergency_screen.dart';

/// Push with the app's smooth glide (see motion.dart).
Future<T?> pushScreen<T>(BuildContext context, Widget screen) =>
    Navigator.push<T>(context, SmoothPageRoute(builder: (_) => screen));

/// The castle app mark (two domed towers + keep), drawn from the
/// design's 48×48 SVG.
class AppMark extends StatelessWidget {
  final double size;
  final Color background, foreground;
  const AppMark({
    super.key,
    this.size = 32,
    this.background = AppColors.ink,
    this.foreground = Colors.white,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _MarkPainter(background, foreground)),
      );
}

class _MarkPainter extends CustomPainter {
  final Color bg, fg;
  _MarkPainter(this.bg, this.fg);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48;
    canvas.scale(s);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 48, 48), const Radius.circular(12)),
        Paint()..color = bg);
    final castle = Path()
      ..moveTo(10, 37)
      ..lineTo(10, 21)
      ..quadraticBezierTo(14, 13, 18, 21)
      ..lineTo(18, 24)
      ..lineTo(21, 24)
      ..lineTo(21, 17)
      ..lineTo(22.5, 17)
      ..lineTo(22.5, 15)
      ..lineTo(25.5, 15)
      ..lineTo(25.5, 17)
      ..lineTo(27, 17)
      ..lineTo(27, 24)
      ..lineTo(30, 24)
      ..lineTo(30, 21)
      ..quadraticBezierTo(34, 13, 38, 21)
      ..lineTo(38, 37)
      ..close();
    canvas.drawPath(castle, Paint()..color = fg);
    final door = Path()
      ..moveTo(21.5, 37)
      ..lineTo(21.5, 32)
      ..arcToPoint(const Offset(26.5, 32), radius: const Radius.circular(2.5))
      ..lineTo(26.5, 37)
      ..close();
    canvas.drawPath(door, Paint()..color = bg);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.bg != bg || old.fg != fg;
}

/// Subtle press feedback for anything tappable.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
  });
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  // Sinks quickly under the finger, springs back with a small bounce.
  late final AnimationController _ctrl = AnimationController(
      vsync: this,
      duration: Motion.fast,
      reverseDuration: const Duration(milliseconds: 420));
  late final Animation<double> _scale = Tween(begin: 1.0, end: 0.95)
      .animate(CurvedAnimation(parent: _ctrl, curve: Motion.curve,
          reverseCurve: Curves.easeOutBack.flipped));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _release() {
    // A quick tap still shows the full press before springing back.
    _ctrl.forward().whenCompleteOrCancel(() {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _release();
          widget.onTap?.call();
        },
        onTapCancel: () => _ctrl.reverse(),
        onLongPress: widget.onLongPress,
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
}

/// 44px round glass button (icon or short label).
class GlassCircleButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool dot;
  const GlassCircleButton({
    super.key,
    this.icon,
    this.label,
    required this.onTap,
    required this.semanticLabel,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: PressScale(
        onTap: onTap,
        child: Container(
          height: 44,
          constraints: const BoxConstraints(minWidth: 44),
          padding: EdgeInsets.symmetric(horizontal: label != null ? 12 : 0),
          decoration: AppDecor.glass(radius: 22),
          child: Stack(alignment: Alignment.center, children: [
            if (icon != null) Icon(icon, size: 22, color: AppColors.ink),
            if (label != null)
              Text(label!,
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w800, color: AppColors.ink)),
            if (dot)
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// "Places near you ............ See all"
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w800, letterSpacing: -0.2,
                  color: AppColors.ink)),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4)),
            child: Text(action!),
          ),
      ]),
    );
  }
}

/// Small uppercase label ("TIMKET IN GONDAR", "NOTICE").
class Kicker extends StatelessWidget {
  final String text;
  final Color color;
  const Kicker(this.text, {super.key, this.color = AppColors.black});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
          letterSpacing: 0.7, color: color));
}

/// Pill tag — status colours are meaning only (see AppColors).
class StatusTag extends StatelessWidget {
  final String text;
  final Color background, foreground;
  final IconData? icon;
  const StatusTag(this.text, {
    super.key,
    this.background = AppColors.gray100,
    this.foreground = AppColors.black,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(13)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                  color: foreground)),
        ]),
      );
}

/// Blue "verified" tick for approved partners.
class VerifiedTick extends StatelessWidget {
  final double size;
  const VerifiedTick({super.key, this.size = 18});
  @override
  Widget build(BuildContext context) => Icon(Icons.verified_rounded,
      size: size, color: AppColors.verified, semanticLabel: 'Verified');
}

/// Big red SOS button — floats on every main screen.
class SosButton extends StatelessWidget {
  final String semanticLabel;
  const SosButton({super.key, this.semanticLabel = 'SOS — get help now'});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: PressScale(
        onTap: () => pushScreen(context, const EmergencyScreen()),
        child: Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.sos,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.sos.withValues(alpha: 0.18),
                  spreadRadius: 5),
              BoxShadow(color: AppColors.sos.withValues(alpha: 0.35),
                  blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: const Text('SOS',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        ),
      ),
    );
  }
}

/// Plain empty / error message used inside lists.
class EmptyNote extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  const EmptyNote({super.key, required this.icon, required this.title,
      this.body});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
                color: AppColors.stone, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w700, color: AppColors.ink)),
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(body!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ]),
      );
}
