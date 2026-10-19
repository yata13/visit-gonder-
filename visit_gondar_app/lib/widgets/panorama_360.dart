import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'motion.dart';

// ═══════════════════════════════════════════════════════════════
//  PANORAMA 360 — look all the way around a 360° image.
//  Drag to turn (it wraps without a seam), pinch to zoom, drag up/
//  down to tilt. Turns slowly on its own until touched, then again
//  after a few idle seconds. Pure Flutter — no native plugin.
//  The image is a full-circle strip (width = 360°), e.g. a
//  cylindrical or equirectangular panorama.
// ═══════════════════════════════════════════════════════════════
class Panorama360 extends StatefulWidget {
  /// An asset path or an http(s) URL.
  final String asset;

  /// Where to face first: 0..1 of the way round the image.
  final double initialHeading;

  /// Reports the current heading in degrees (0–360).
  final ValueChanged<double>? onHeading;

  const Panorama360({
    super.key,
    required this.asset,
    this.initialHeading = 0,
    this.onHeading,
  });

  @override
  State<Panorama360> createState() => _Panorama360State();
}

class _Panorama360State extends State<Panorama360>
    with SingleTickerProviderStateMixin {
  ui.Image? _image;
  late double _heading = widget.initialHeading; // 0..1 round the circle
  double _tilt = 0; // -1 (look down) .. 1 (look up)
  double _zoom = 1.15;
  double _zoomAtStart = 1.15;

  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  DateTime _touchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  double _fling = 0; // heading units per second after a swipe

  static const _autoSpeed = 0.006; // of a full turn per second
  static const _idle = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _load();
    _ticker.start();
  }

  /// Loads the picture from the app's assets or, for an http(s)
  /// link, from the web.
  Future<void> _load() async {
    final src = widget.asset;
    if (src.startsWith('http')) {
      final stream =
          NetworkImage(src).resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        stream.removeListener(listener);
        if (mounted) {
          setState(() => _image = info.image);
        } else {
          info.image.dispose();
        }
      }, onError: (_, _) => stream.removeListener(listener));
      stream.addListener(listener);
      return;
    }
    final data = await rootBundle.load(src);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0 || dt > 0.1) return;
    var moved = false;
    if (_fling.abs() > 0.0005) {
      _heading += _fling * dt;
      _fling *= math.pow(0.04, dt).toDouble(); // glide to a stop
      moved = true;
    } else if (DateTime.now().difference(_touchedAt) > _idle &&
        !Motion.reduced(context)) {
      _heading += _autoSpeed * dt;
      moved = true;
    }
    if (moved) {
      _heading %= 1;
      widget.onHeading?.call(_heading * 360);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    return LayoutBuilder(builder: (context, box) {
      // Image height fills the view × zoom; its width is one full turn.
      final scale = box.maxHeight * _zoom / image.height;
      final turn = image.width * scale;
      return GestureDetector(
        onScaleStart: (_) {
          _touchedAt = DateTime.now();
          _fling = 0;
          _zoomAtStart = _zoom;
        },
        onScaleUpdate: (d) {
          _touchedAt = DateTime.now();
          setState(() {
            _heading = (_heading - d.focalPointDelta.dx / turn) % 1;
            final room = box.maxHeight * (_zoom - 1) / 2;
            if (room > 0) {
              _tilt = (_tilt + d.focalPointDelta.dy / room).clamp(-1.0, 1.0);
            }
            if (d.pointerCount > 1) {
              _zoom = (_zoomAtStart * d.scale).clamp(1.0, 2.6);
            }
          });
          widget.onHeading?.call(_heading * 360);
        },
        onScaleEnd: (d) {
          _touchedAt = DateTime.now();
          _fling = -d.velocity.pixelsPerSecond.dx / turn;
        },
        child: CustomPaint(
          size: Size(box.maxWidth, box.maxHeight),
          painter: _PanoramaPainter(image, _heading, _tilt, _zoom),
        ),
      );
    });
  }
}

class _PanoramaPainter extends CustomPainter {
  final ui.Image image;
  final double heading, tilt, zoom;
  _PanoramaPainter(this.image, this.heading, this.tilt, this.zoom);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height * zoom / image.height;
    final turn = image.width * scale;
    final drawH = image.height * scale;
    // Centre the current heading; tilt moves the strip up / down.
    final top = -(drawH - size.height) / 2 * (1 - tilt);
    var x = size.width / 2 - heading * turn;
    while (x > 0) {
      x -= turn;
    }
    final paint = Paint()..filterQuality = FilterQuality.medium;
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    // Lay copies side by side so the circle never shows an edge.
    for (; x < size.width; x += turn) {
      canvas.drawImageRect(
          image, src, Rect.fromLTWH(x, top, turn + 0.5, drawH), paint);
    }
  }

  @override
  bool shouldRepaint(_PanoramaPainter old) =>
      old.heading != heading || old.tilt != tilt || old.zoom != zoom;
}

/// Full-screen 360° view with a compass and a short hint.
class Panorama360Screen extends StatefulWidget {
  final String asset;
  final String title;
  final double initialHeading;
  final bool am;
  const Panorama360Screen({
    super.key,
    required this.asset,
    required this.title,
    this.initialHeading = 0,
    this.am = false,
  });

  @override
  State<Panorama360Screen> createState() => _Panorama360ScreenState();
}

class _Panorama360ScreenState extends State<Panorama360Screen> {
  late final _heading = ValueNotifier(widget.initialHeading * 360);

  @override
  void dispose() {
    _heading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final am = widget.am;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: Panorama360(
            asset: widget.asset,
            initialHeading: widget.initialHeading,
            onHeading: (h) => _heading.value = h,
          ),
        ),
        // Pinned to the top so the panorama, not this bar, sizes the view.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              IconButton(
                tooltip: am ? 'ዝጋ' : 'Close',
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.35),
                    minimumSize: const Size(44, 44)),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(blurRadius: 8)])),
              ),
              // Compass: the needle points to where you are facing.
              ValueListenableBuilder<double>(
                valueListenable: _heading,
                builder: (_, h, _) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54),
                  ),
                  child: Transform.rotate(
                    angle: h * math.pi / 180,
                    child: const Icon(Icons.navigation_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ]),
          ),
        ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Center(
                child: Reveal(
                  delay: const Duration(milliseconds: 400),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.threesixty_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                            am ? 'ለመዞር ይጎትቱ · ለማቅረብ ይቆንጥጡ'
                                : 'Drag to look around · pinch to zoom',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
