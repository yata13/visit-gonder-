import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/posts/feed_screen.dart';
import '../screens/booking/my_bookings_screen.dart';
import '../widgets/motion.dart';
import 'phone_notifications.dart';

/// Global navigator key — lets the alert service show banners and
/// navigate from anywhere, over whatever screen is open.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

// ═══════════════════════════════════════════════════════════════
//  REALTIME ALERTS — Supabase Realtime (postgres_changes).
//  · INSERT on `notifications`  → banner + chime, anywhere
//  · INSERT/UPDATE on `danger_zones` (active) → red urgent banner
//  · any change to listings → [changes] so screens refresh live
//  A 15 s poll backs up the live channel, so a notification still
//  pops up if the socket drops. Tap banner → opens the detail screen.
// ═══════════════════════════════════════════════════════════════
class RealtimeAlerts {
  RealtimeAlerts._();
  static final _player = AudioPlayer();
  static RealtimeChannel? _channel;
  static OverlayEntry? _entry;
  static bool _started = false;
  static Timer? _poll;

  /// Notification ids already shown (live channel and poll both feed
  /// [_notify], so the same one never pops up twice).
  static final _seen = <String>{};
  static DateTime? _since;

  /// Name of a table whenever one of its rows changes — screens listen
  /// to refresh their data without a pull-to-refresh.
  static final _changes = StreamController<String>.broadcast();
  static Stream<String> get changes => _changes.stream;

  /// Tables whose changes should refresh what the visitor sees.
  static const _liveTables = [
    'notifications', 'posts', 'danger_zones', 'hotels', 'sites',
    'guides', 'events', 'places', 'passport_checkpoints',
  ];

  static void _notify(Map<String, dynamic> n) {
    final id = '${n['id']}';
    if (!_seen.add(id)) return;
    final at = DateTime.tryParse('${n['created_at']}');
    if (at != null && (_since == null || at.isAfter(_since!))) _since = at;
    _changes.add('notifications');
    _show(
      title: (n['title'] ?? 'Visit Gondar') as String,
      message: (n['message'] ?? n['body'] ?? '') as String,
      urgent: (n['type'] ?? '') == 'safety',
      onTap: () => _open(const NotificationsScreen()),
    );
  }

  /// Backup for the live channel: asks for anything newer than the
  /// last notification seen.
  static Future<void> _checkNew() async {
    try {
      final client = Supabase.instance.client;
      if (_since == null) {
        // First run: remember where "now" is; don't replay old ones.
        final last = await client
            .from('notifications')
            .select('id, created_at')
            .order('created_at', ascending: false)
            .limit(1);
        _since = last.isEmpty
            ? DateTime.now().toUtc()
            : DateTime.parse('${last.first['created_at']}');
        for (final r in last) {
          _seen.add('${r['id']}');
        }
        return;
      }
      final rows = await client
          .from('notifications')
          .select()
          .gt('created_at', _since!.toIso8601String())
          .order('created_at')
          .limit(5);
      for (final r in rows) {
        _notify(r);
      }
    } catch (_) {} // offline — try again on the next tick
  }

  static void start() {
    if (_started) return;
    _started = true;

    PhoneNotifications.onOpen = () => _open(const NotificationsScreen());

    _checkNew();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _checkNew());

    var channel = Supabase.instance.client
        .channel('public:alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) => _notify(payload.newRecord),
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
        );
    for (final t in _liveTables) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: t,
        callback: (_) => _changes.add(t),
      );
    }
    _channel = channel..subscribe();
  }

  static void stop() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
    _poll?.cancel();
    _poll = null;
    _started = false;
  }

  static void _open(Widget screen) {
    _dismiss();
    rootNavigatorKey.currentState?.push(
        SmoothPageRoute(builder: (_) => screen));
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
    // Status bar / lock screen too — seen even when the app is in the
    // background or the phone is locked.
    PhoneNotifications.show(
        title: title, body: message, urgent: urgent);

    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _dismiss();
    // The phone notification already rings; chime only without it.
    if (!PhoneNotifications.active) _sound(urgent);

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
    final bg = widget.urgent ? const Color(0xFFC4261D) : AppColors.charcoal;
    final accent = widget.urgent ? Colors.white : Colors.white;

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
                            color: Colors.white.withAlpha(70)),
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
                                      : const Color(0xFFE9E9E9),
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
