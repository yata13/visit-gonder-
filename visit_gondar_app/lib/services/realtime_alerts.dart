import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/posts/feed_screen.dart';
import '../screens/booking/my_bookings_screen.dart';
import '../screens/emergency/emergency_screen.dart';
import '../screens/ride/ride_screen.dart';
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
      // Newly published posts / events (visitors only ever read the
      // published ones, so anything new here is fresh news).
      if (_seeded) {
        for (final (table, announce) in [
          ('posts', _announcePost),
          ('events', _announceEvent),
        ]) {
          final latest = await client
              .from(table)
              .select()
              .order('created_at', ascending: false)
              .limit(10);
          for (final r in latest) {
            announce(r);
          }
        }
      }
    } catch (_) {} // offline — try again on the next tick
  }

  // ── "Major update" announcements ────────────────────────────
  /// Keys already announced ("post:12", "sos:5:resolved", …) so an
  /// edit or a repeated event never pops up twice.
  static final _announced = <String>{};
  static bool _seeded = false;

  static bool _published(Map<String, dynamic> r) {
    final s = r['publish_status'];
    return s == null || s == 'published';
  }

  static String? get _myId => Supabase.instance.client.auth.currentUser?.id;
  static String? get _myEmail =>
      Supabase.instance.client.auth.currentUser?.email;

  /// Marks what is already out there, so only NEW things announce.
  static Future<void> _seedSeen() async {
    final db = Supabase.instance.client;
    Future<void> seed(String table, String prefix) async {
      try {
        final rows = await db
            .from(table)
            .select('id')
            .order('created_at', ascending: false)
            .limit(200);
        for (final r in rows) {
          _announced.add('$prefix:${r['id']}');
        }
      } catch (_) {}
    }
    await Future.wait([
      seed('posts', 'post'),
      seed('events', 'event'),
    ]);
    try {
      final zones =
          await db.from('danger_zones').select('id').eq('is_active', true);
      for (final z in zones) {
        _announced.add('zone:${z['id']}');
      }
    } catch (_) {}
    _seeded = true;
  }

  static void _announcePost(Map<String, dynamic> p) {
    if (!_seeded || p['id'] == null || !_published(p)) return;
    if (!_announced.add('post:${p['id']}')) return;
    _show(
      title: '📰 ${p['title'] ?? 'New from Visit Gondar'}',
      message: (p['body'] ?? '') as String,
      urgent: false,
      onTap: () => _open(const FeedScreen()),
    );
  }

  static void _announceEvent(Map<String, dynamic> e) {
    if (!_seeded || e['id'] == null || !_published(e)) return;
    if (!_announced.add('event:${e['id']}')) return;
    _show(
      title: '🎉 New event · ${e['name'] ?? e['title'] ?? 'Gondar'}',
      message: (e['description'] ?? e['date'] ?? '') as String,
      urgent: false,
      onTap: () => _open(const NotificationsScreen()),
    );
  }

  static void _announceZone(Map<String, dynamic> z) {
    if (z['id'] == null) return;
    final key = 'zone:${z['id']}';
    if (z['is_active'] == false) {
      _announced.remove(key); // announce again if it is re-activated
      return;
    }
    if (!_seeded || !_announced.add(key)) return;
    _show(
      title: '⚠ Safety alert · ${z['name'] ?? 'Gondar'}',
      message: (z['description'] ??
          'An area in Gondar is currently unsafe. Open the map.') as String,
      urgent: true,
      onTap: () => _open(const MapScreen()),
    );
  }

  static void _announceEmergency(Map<String, dynamic> r) {
    final me = _myId;
    if (me == null || r['user_id'] != me) return;
    final status = (r['status'] ?? '') as String;
    if (!_announced.add('sos:${r['id']}:$status')) return;
    final (title, msg) = switch (status) {
      'responding' => ('🚑 Help is on the way',
          'The Safety Desk is responding to your request. Stay where you are if you can.'),
      'resolved' => ('✅ Your request is resolved',
          'The Safety Desk marked your request as resolved. Stay safe in Gondar!'),
      _ => ('🆘 Update on your request', 'Status: $status'),
    };
    _show(
      title: title,
      message: msg,
      urgent: status != 'resolved',
      onTap: () => _open(const EmergencyScreen()),
    );
  }

  static void _announceBooking(Map<String, dynamic> b) {
    final me = _myId, email = _myEmail;
    final mine = (me != null && b['user_id'] == me) ||
        (email != null && b['user_email'] == email);
    if (!mine) return;
    final status = (b['status'] ?? 'pending') as String;
    if (!_announced.add('booking:${b['id']}:$status')) return;
    final item = b['item_name'] ?? 'your booking';
    final (String title, String msg)? text = switch (status) {
      'pending' => ('📅 Booking received',
          'We sent your request for $item. You will be told when it is confirmed.'),
      'confirmed' || 'approved' => ('✅ Booking confirmed',
          'Your booking at $item is confirmed. Pay on arrival.'),
      'cancelled' || 'rejected' => ('❌ Booking cancelled',
          'Your booking at $item was cancelled. Tap to rebook.'),
      _ => null,
    };
    if (text == null) return;
    _show(
      title: text.$1,
      message: text.$2,
      urgent: false,
      onTap: () => _open(const MyBookingsScreen()),
    );
  }

  static void _announceRide(Map<String, dynamic> r) {
    final me = _myId;
    if (me == null || r['rider_id'] != me) return;
    final id = '${r['id']}', status = (r['status'] ?? '') as String;
    final wasAccepted = _announced.contains('ride:$id:accepted');
    if (!_announced.add('ride:$id:$status:${r['driver_id']}')) return;
    final plate = r['vehicle_plate'] ?? '';
    final (String, String)? text = switch (status) {
      'accepted' => (
          '🛺 ${r['driver_name'] ?? 'Your driver'} is on the way',
          'Plate $plate. Be ready at ${r['pickup_label'] ?? 'your pickup point'}.'),
      'arrived' => ('📍 Your driver is here', 'Look for plate $plate.'),
      'completed' => ('✅ You have arrived',
          'Pay ${(r['fare_estimate'] as num?)?.round() ?? ''} ETB in cash, then rate your driver.'),
      'requested' when wasAccepted => ('🔄 Finding you another driver',
          'Your driver could not come. Your request is open again.'),
      'cancelled' when r['cancelled_by'] == 'admin' =>
          ('Ride cancelled', 'The Visit Gondar team cancelled this ride.'),
      _ => null,
    };
    if (status == 'accepted') _announced.add('ride:$id:accepted');
    if (status == 'requested') _announced.remove('ride:$id:accepted');
    if (text == null) return;
    _show(
      title: text.$1,
      message: text.$2,
      urgent: false,
      onTap: () => _open(const RideScreen()),
    );
  }

  /// Called by the booking screen right after a booking is saved, so
  /// the phone shows it even before the live event arrives.
  static void bookingCreated(Map<String, dynamic> booking) =>
      _announceBooking({...booking, 'user_id': _myId, 'user_email': _myEmail});

  static void start() {
    if (_started) return;
    _started = true;

    PhoneNotifications.onOpen = () => _open(const NotificationsScreen());

    _checkNew();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _checkNew());

    _seedSeen();
    var channel = Supabase.instance.client
        .channel('public:alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) => _notify(payload.newRecord),
        )
        // News Feed + events: drafts are saved first and PUBLISHED
        // later (an update), so watch both and announce each once.
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          callback: (payload) => _announcePost(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (payload) => _announceEvent(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'danger_zones',
          callback: (payload) => _announceZone(payload.newRecord),
        )
        // The visitor's own SOS / help requests: the city responding.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'emergency_requests',
          callback: (payload) => _announceEmergency(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (payload) => _announceBooking(payload.newRecord),
        )
        // The visitor's own ride: driver found, arrived, trip done.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rides',
          callback: (payload) => _announceRide(payload.newRecord),
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
