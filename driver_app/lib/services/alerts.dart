import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../theme.dart';

// ═══════════════════════════════════════════════════════════════
//  Status bar notifications with sound + vibration, so drivers hear
//  a new request (or a cancelled ride) even with the phone in their
//  pocket.
// ═══════════════════════════════════════════════════════════════
class Alerts {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static int _id = 0;

  static Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      // tests / unsupported platform
    }
  }

  /// A new request: loud, like a phone call.
  static Future<void> newRide(String title, String body) async {
    HapticFeedback.heavyImpact();
    await _show(title, body,
        channel: 'vg_driver_requests',
        channelName: 'Ride requests',
        about: 'New ride requests near you',
        urgent: true);
  }

  /// Something happened to my ride (the rider cancelled…).
  static Future<void> update(String title, String body) async {
    HapticFeedback.mediumImpact();
    await _show(title, body,
        channel: 'vg_driver_updates',
        channelName: 'Ride updates',
        about: 'Changes to the ride you are driving',
        urgent: false);
  }

  static Future<void> _show(
    String title,
    String body, {
    required String channel,
    required String channelName,
    required String about,
    required bool urgent,
  }) async {
    if (!_ready) {
      SystemSound.play(SystemSoundType.alert);
      return;
    }
    try {
      await _plugin.show(
        id: _id++,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel,
            channelName,
            channelDescription: about,
            importance: urgent ? Importance.max : Importance.high,
            priority: urgent ? Priority.max : Priority.high,
            color: VG.brown,
            category: urgent ? AndroidNotificationCategory.call : AndroidNotificationCategory.status,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }
}
