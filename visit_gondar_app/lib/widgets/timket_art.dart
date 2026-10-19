import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  TIMKET ART — the background painting of the Timket card:
//  sun rays, a faint field of Ethiopian processional crosses, the
//  ceremonial umbrellas of the procession and the skyline of
//  Fasilides' castle, all in soft brand gold.
// ═══════════════════════════════════════════════════════════════
class TimketArt extends StatelessWidget {
  const TimketArt({super.key});

  @override
  Widget build(BuildContext context) =>
      const IgnorePointer(child: CustomPaint(painter: _TimketPainter()));
}

class _TimketPainter extends CustomPainter {
  const _TimketPainter();

  static Paint _gold(double alpha) =>
      Paint()..color = AppColors.brandGold.withValues(alpha: alpha);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    _rays(canvas, Offset(w * 0.92, -h * 0.1), h * 1.4);
    _crossField(canvas, size);
    _castle(canvas, size);
    _umbrellas(canvas, size);
  }

  // Thin rays fanning down from the top-right corner.
  void _rays(Canvas canvas, Offset from, double len) {
    final p = _gold(0.07);
    for (var i = 0; i < 9; i++) {
      final a = math.pi * (0.52 + i * 0.07);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(from.dx + math.cos(a - 0.018) * len,
            from.dy + math.sin(a - 0.018) * len)
        ..lineTo(from.dx + math.cos(a + 0.018) * len,
            from.dy + math.sin(a + 0.018) * len)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  // A sparse diagonal grid of small processional crosses.
  void _crossField(Canvas canvas, Size size) {
    final p = _gold(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const step = 34.0;
    for (var row = 0; row * step < size.height + step; row++) {
      for (var col = 0; col * step < size.width + step; col++) {
        final dx = col * step + (row.isOdd ? step / 2 : 0);
        _cross(canvas, Offset(dx, row * step), 6, p);
      }
    }
  }

  /// Ethiopian-style cross: four arms ending in small rings.
  void _cross(Canvas canvas, Offset c, double r, Paint p) {
    canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), p);
    canvas.drawLine(c.translate(0, -r), c.translate(0, r), p);
    for (final d in [Offset(r, 0), Offset(-r, 0), Offset(0, r), Offset(0, -r)]) {
      canvas.drawCircle(c + d * 1.25, r * 0.28, p);
    }
    canvas.drawCircle(c, r * 0.45, p);
  }

  // Fasilides' castle: a crenellated keep, a tall square tower and
  // round domed corner towers, sitting on the bottom edge.
  void _castle(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final base = h;
    final left = w * 0.36, right = w * 0.80;
    final keepTop = h * 0.66;
    final p = _gold(0.20);
    final path = Path()..moveTo(left, base);

    // Left domed tower.
    final t1 = left + (right - left) * 0.08;
    path
      ..lineTo(left, h * 0.60)
      ..arcToPoint(Offset(t1 + (t1 - left), h * 0.60),
          radius: Radius.circular(t1 - left))
      ..lineTo(t1 + (t1 - left), keepTop);

    // Crenellated wall up to the tall tower.
    final towerL = left + (right - left) * 0.55;
    var x = t1 + (t1 - left);
    const merlon = 7.0;
    while (x + merlon * 2 < towerL) {
      path
        ..lineTo(x, keepTop - merlon)
        ..lineTo(x + merlon, keepTop - merlon)
        ..lineTo(x + merlon, keepTop)
        ..lineTo(x + merlon * 2, keepTop);
      x += merlon * 2;
    }
    path.lineTo(towerL, keepTop);

    // Tall square tower with its own battlements.
    final towerR = towerL + (right - left) * 0.16;
    final towerTop = h * 0.40;
    path
      ..lineTo(towerL, towerTop)
      ..lineTo(towerL + 5, towerTop)
      ..lineTo(towerL + 5, towerTop - 6)
      ..lineTo(towerL + 11, towerTop - 6)
      ..lineTo(towerL + 11, towerTop);
    path
      ..lineTo(towerR - 11, towerTop)
      ..lineTo(towerR - 11, towerTop - 6)
      ..lineTo(towerR - 5, towerTop - 6)
      ..lineTo(towerR - 5, towerTop)
      ..lineTo(towerR, towerTop)
      ..lineTo(towerR, keepTop + 6);

    // Right domed tower.
    final r2 = (right - towerR) * 0.42;
    path
      ..lineTo(right - r2 * 2, keepTop + 6)
      ..lineTo(right - r2 * 2, h * 0.62)
      ..arcToPoint(Offset(right, h * 0.62), radius: Radius.circular(r2))
      ..lineTo(right, base)
      ..close();
    canvas.drawPath(path, p);

    // Arched windows cut back out of the stone.
    final win = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = Colors.black.withValues(alpha: 0.55);
    for (final cx in [towerL + (towerR - towerL) / 2]) {
      _archWindow(canvas, Offset(cx, h * 0.55), 4, 9, win);
    }
    for (var i = 0; i < 3; i++) {
      final cx = t1 * 2 - left + 14 + i * 18;
      if (cx < towerL - 8) _archWindow(canvas, Offset(cx, h * 0.80), 3.5, 8, win);
    }
  }

  void _archWindow(Canvas canvas, Offset top, double r, double hgt, Paint p) {
    final path = Path()
      ..moveTo(top.dx - r, top.dy + r + hgt)
      ..lineTo(top.dx - r, top.dy + r)
      ..arcToPoint(Offset(top.dx + r, top.dy + r), radius: Radius.circular(r))
      ..lineTo(top.dx + r, top.dy + r + hgt)
      ..close();
    canvas.drawPath(path, p);
  }

  // Ceremonial Timket umbrellas carried in the procession.
  void _umbrellas(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final spots = [
      (Offset(w * 0.86, h * 0.36), 15.0),
      (Offset(w * 0.95, h * 0.46), 11.0),
      (Offset(w * 0.47, h * 0.36), 12.0),
    ];
    for (final (c, r) in spots) {
      final canopy = _gold(0.26);
      final pole = _gold(0.22)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      // Pole.
      canvas.drawLine(c, c.translate(0, r * 2.6), pole);
      // Dome canopy.
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi, math.pi,
          true, canopy);
      // Fringe of tassels along the rim.
      final fringe = _gold(0.30)..strokeWidth = 1;
      for (var i = 0; i <= 8; i++) {
        final x = c.dx - r + i * (r * 2 / 8);
        canvas.drawLine(Offset(x, c.dy), Offset(x, c.dy + r * 0.32), fringe);
      }
      // Finial cross on top.
      _cross(canvas, c.translate(0, -r - 4), 3,
          _gold(0.30)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(_TimketPainter oldDelegate) => false;
}
