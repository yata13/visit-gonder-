import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  PHONE NOTIFICATIONS — the system kind: status bar, lock screen,
//  sound and vibration, like a messaging app. RealtimeAlerts calls
//  [show] for every new notification while the app is running
//  (open, in the background, or with the phone locked).
//  Android 13+ asks the visitor once for permission.
// ═══════════════════════════════════════════════════════════════
class PhoneNotifications {
  PhoneNotifications._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _allowed = true;
  static int _nextId = 0;

  /// True when notifications reach the status bar (and make their own
  /// sound), so the in-app chime can stay quiet.
  static bool get active => _ready && _allowed;

  /// Called when the visitor taps a notification in the status bar.
  static VoidCallback? onOpen;

  static const _news = AndroidNotificationDetails(
    'visit_gondar_news',
    'News and updates',
    channelDescription: 'Notifications sent by Visit Gondar',
    importance: Importance.high, // heads-up banner + sound
    priority: Priority.high,
    color: AppColors.brandBrown,
    category: AndroidNotificationCategory.message,
  );

  static const _safety = AndroidNotificationDetails(
    'visit_gondar_safety',
    'Safety alerts',
    channelDescription: 'Urgent safety alerts in Gondar',
    importance: Importance.max,
    priority: Priority.max,
    color: AppColors.sos,
    category: AndroidNotificationCategory.alarm,
  );

  static Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (_) => onOpen?.call(),
      );
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _allowed = granted ?? true;
      _ready = true;
    } catch (_) {
      // Unsupported platform (tests, desktop) — in-app banners still work.
    }
  }

  static Future<void> show({
    required String title,
    required String body,
    bool urgent = false,
  }) async {
    if (!_ready) return;
    final android = urgent ? _safety : _news;
    try {
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          // Long messages expand in the shade instead of being cut off.
          android: AndroidNotificationDetails(
            android.channelId,
            android.channelName,
            channelDescription: android.channelDescription,
            importance: android.importance,
            priority: android.priority,
            color: android.color,
            category: android.category,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }
}
