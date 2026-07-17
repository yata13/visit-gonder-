import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/posts/feed_screen.dart';
import '../screens/booking/my_bookings_screen.dart';

/// Global navigator key — lets the alert service show banners and
/// navigate from anywhere, over whatever screen is open.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

// ═══════════════════════════════════════════════════════════════
//  REALTIME ALERTS — Supabase Realtime (postgres_changes).
//  · INSERT on `notifications`  → gold banner + chime, anywhere
//  · INSERT/UPDATE on `danger_zones` (active) → red urgent banner
//  Tap banner → opens the full detail screen.
// ═══════════════════════════════════════════════════════════════
class RealtimeAlerts {
  RealtimeAlerts._();
  static final _player = AudioPlayer();
  static RealtimeChannel? _channel;
  static OverlayEntry? _entry;
  static bool _started = false;

  static void start() {
    if (_started) return;
    _started = true;

    _channel = Supabase.instance.client
        .channel('public:alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final n = payload.newRecord;
            _show(
              title: (n['title'] ?? 'Visit Gondar') as String,
              message: (n['message'] ?? n['body'] ?? '') as String,
              urgent: (n['type'] ?? '') == 'safety',
              onTap: () => _open(const NotificationsScreen()),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            final p = payload.newRecord;
            _show(
              title: '📰 ${p['title'] ?? 'New from Visit Gondar'}',
              message: (p['body'] ?? '') as String,
              urgent: false,
              onTap: () => _open(const FeedScreen()),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'danger_zones',
          callback: (payload) {
            final z = payload.newRecord;
            if (z['is_active'] == false) return;
            _show(
              title: '⚠ Safety alert · ${z['name'] ?? 'Gondar'}',
              message: (z['description'] ??
                  'An area in Gondar is currently unsafe. Open the map.') as String,
              urgent: true,
              onTap: () => _open(const MapScreen()),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          callback: (payload) {
            final b = payload.newRecord;
            // Only tell THIS user about THEIR booking.
            final myEmail =
                Supabase.instance.client.auth.currentUser?.email;
            if (myEmail == null || b['user_email'] != myEmail) return;
            final status = (b['status'] ?? '') as String;
            final confirmed = status == 'confirmed' || status == 'approved';
            final cancelled = status == 'cancelled' || status == 'rejected';
            if (!confirmed && !cancelled) return;
            _show(
              title: confirmed
                  ? '✅ Booking confirmed'
                  : '❌ Booking cancelled',
              message: confirmed
                  ? 'Your booking at ${b['item_name']} is confirmed. Pay on arrival.'
                  : 'Your booking at ${b['item_name']} was cancelled. Tap to rebook.',
              urgent: false,
              onTap: () => _open(const MyBookingsScreen()),
            );
          },
        )
      ..subscribe();
  }

  static void stop() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
    _started = false;
  }

  static void _open(Widget screen) {
    _dismiss();
    rootNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => screen));
  }

  static Future<void> _sound(bool urgent) async {
    try {
      await _player.play(
          AssetSource('sounds/${urgent ? 'urgent' : 'notify'}.wav'));
    } catch (_) {}
  }

  static void _dismiss() {
    _entry?.remove();
    _entry = null;
  }

  static void _show({
    required String title,
    required String message,
    required bool urgent,
    required VoidCallback onTap,
  }) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _dismiss();
    _sound(urgent);

    _entry = OverlayEntry(
      builder: (_) => _AlertBanner(
        title: title,
        message: message,
        urgent: urgent,
        onTap: onTap,
        onClose: _dismiss,
      ),
    );
    overlay.insert(_entry!);

    // Normal notifications auto-dismiss; urgent ones stay until tapped.
    if (!urgent) {
      final shown = _entry;
      Timer(const Duration(seconds: 6), () {
        if (_entry == shown) _dismiss();
      });
    }
  }
}

// ── Banner widget — slides down from the top, 300ms ───────────
class _AlertBanner extends StatefulWidget {
  final String title, message;
  final bool urgent;
  final VoidCallback onTap, onClose;
  const _AlertBanner({
    required this.title,
    required this.message,
    required this.urgent,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<_AlertBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300))
    ..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    final bg = widget.urgent ? const Color(0xFFB3261E) : AppColors.charcoal;
    final accent = widget.urgent ? Colors.white : AppColors.gold;

    return Positioned(
      top: 0, left: 0, right: 0,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1), end: Offset.zero)
            .animate(anim),
        child: FadeTransition(
          opacity: anim,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(18),
                    border: widget.urgent
                        ? Border.all(color: Colors.white38)
                        : Border.all(
                            color: AppColors.gold.withAlpha(70)),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withAlpha(90),
                        blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(36),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.urgent
                            ? Icons.warning_amber_rounded
                            : Icons.notifications_active_outlined,
                        color: accent, size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                        if (widget.message.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(widget.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: widget.urgent
                                      ? Colors.white
                                      : const Color(0xFFE8DFD0),
                                  fontSize: 12.5, height: 1.4)),
                        ],
                        const SizedBox(height: 4),
                        Text(widget.urgent
                                ? 'Tap to open the map'
                                : 'Tap to read',
                            style: TextStyle(
                                color: accent.withAlpha(170),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6)),
                      ]),
                    ),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close,
                            size: 18, color: accent.withAlpha(180)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
