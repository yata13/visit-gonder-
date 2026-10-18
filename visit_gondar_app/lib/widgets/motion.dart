// ═══════════════════════════════════════════════════════════════
//  Motion — one set of timings and curves for the whole app, so
//  every page, tab, button and list moves the same smooth way
//  (quick start, long soft landing — the One UI feel).
//  Honours the system "remove animations" setting.
// ═══════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';

class Motion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 560);
  static const page = Duration(milliseconds: 440);
  static const pageBack = Duration(milliseconds: 360);

  /// Fast out, long glide in — used for almost everything.
  static const curve = Cubic(0.2, 0.8, 0.2, 1);

  /// A touch of overshoot for things that "pop" into place.
  static const pop = Cubic(0.34, 1.4, 0.64, 1);

  /// Delay between items that reveal one after another. Only the
  /// first few wait, so items scrolled into view later appear at once.
  static Duration stagger(int index, {int stepMs = 55, int max = 8}) =>
      Duration(milliseconds: (index < max ? index : 0) * stepMs);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

// ── Page transitions ───────────────────────────────────────────

/// New page glides in from the right while fading up; the page
/// underneath drifts a little to the left. Used by every route.
Widget smoothPageTransition(Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  final enter = CurvedAnimation(
      parent: animation, curve: Motion.curve,
      reverseCurve: Curves.easeInCubic);
  final exit = CurvedAnimation(
      parent: secondaryAnimation, curve: Motion.curve,
      reverseCurve: Curves.easeOutCubic);
  return SlideTransition(
    position: Tween(begin: Offset.zero, end: const Offset(-0.12, 0))
        .animate(exit),
    child: SlideTransition(
      position: Tween(begin: const Offset(0.22, 0), end: Offset.zero)
          .animate(enter),
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0, 0.6, curve: Curves.easeOut)),
        child: child,
      ),
    ),
  );
}

/// Drop-in replacement for [MaterialPageRoute] with the smooth glide.
class SmoothPageRoute<T> extends MaterialPageRoute<T> {
  SmoothPageRoute({required super.builder, super.settings,
      super.fullscreenDialog});

  @override
  Duration get transitionDuration => Motion.page;
  @override
  Duration get reverseTransitionDuration => Motion.pageBack;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (Motion.reduced(context)) return child;
    return smoothPageTransition(animation, secondaryAnimation, child);
  }
}

/// Theme hook so routes created anywhere get the same glide.
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Motion.page;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
          Animation<double> animation, Animation<double> secondaryAnimation,
          Widget child) =>
      smoothPageTransition(animation, secondaryAnimation, child);
}

// ── Scrolling ──────────────────────────────────────────────────

/// Soft, bouncy scrolling everywhere.
class SmoothScrollBehavior extends MaterialScrollBehavior {
  const SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.normal);
}

// ── Entrance animation ─────────────────────────────────────────

/// Fades and glides its child into place once, after [delay].
class Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  /// Starting offset in logical pixels (default: 24 px below).
  final Offset offset;
  /// Starting scale (1 = no zoom).
  final double scale;

  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.slow,
    this.offset = const Offset(0, 24),
    this.scale = 1,
  });

  /// Wraps each child so they arrive one after another. Plain gaps
  /// and flex children (Spacer, Expanded) are left as they are.
  static List<Widget> stagger(List<Widget> children,
      {Duration start = Duration.zero, int stepMs = 55,
      Offset offset = const Offset(0, 24)}) {
    var i = 0;
    return [
      for (final c in children)
        if ((c is SizedBox && c.child == null) || c is ParentDataWidget)
          c
        else
          Reveal(
            delay: start + Motion.stagger(i++, stepMs: stepMs),
            offset: offset,
            child: c,
          ),
    ];
  }

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t =
      CurvedAnimation(parent: _ctrl, curve: Motion.curve);
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ctrl.isAnimating || _ctrl.isCompleted || _timer != null) return;
    if (Motion.reduced(context)) {
      _ctrl.value = 1;
    } else if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (_, child) {
          final t = _t.value;
          final o = _ctrl.value.clamp(0.0, 1.0);
          Widget w = Transform.translate(
              offset: widget.offset * (1 - t), child: child);
          if (widget.scale != 1) {
            w = Transform.scale(
                scale: widget.scale + (1 - widget.scale) * t, child: w);
          }
          return Opacity(opacity: Curves.easeOut.transform(o), child: w);
        },
      );
}

/// Cross-fades text (or any small widget) when its value changes,
/// e.g. when the language is switched.
class SwapText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  const SwapText(this.text,
      {super.key, this.style, this.textAlign, this.maxLines, this.overflow});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: Motion.medium,
        switchInCurve: Motion.curve,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: textAlign == TextAlign.center
              ? Alignment.center
              : AlignmentDirectional.centerStart,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
                .animate(anim),
            child: child,
          ),
        ),
        child: Text(text,
            key: ValueKey(text),
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow),
      );
}

/// Shrinks content a little while a Material button is held down —
/// plugged into every button style through the theme.
Widget pressedForeground(
        BuildContext context, Set<WidgetState> states, Widget? child) =>
    AnimatedScale(
      scale: states.contains(WidgetState.pressed) ? 0.94 : 1,
      duration: Motion.fast,
      curve: Motion.curve,
      child: child,
    );
