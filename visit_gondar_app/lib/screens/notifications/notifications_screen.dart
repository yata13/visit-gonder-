import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

// ── Provider — realtime stream ────────────────────────────────
final notificationsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((data) => List<Map<String, dynamic>>.from(data));
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Read-state is persisted so notifications stay "read" after the
  // screen closes or the app restarts.
  static const _prefsKey = 'notif_read_ids';
  Set<String> _readIds = {};
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadReadIds();
  }

  Future<void> _loadReadIds() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() =>
        _readIds = (_prefs!.getStringList(_prefsKey) ?? []).toSet());
  }

  Future<void> _saveReadIds() async {
    // Cap the stored list so it never grows unbounded.
    final ids = _readIds.toList();
    await _prefs?.setStringList(
        _prefsKey, ids.length > 300 ? ids.sublist(ids.length - 300) : ids);
  }

  void _markRead(String id) {
    setState(() => _readIds.add(id));
    _saveReadIds();
  }

  /// Open the full notification, like reading a message, and mark it read.
  void _openNotif(Map<String, dynamic> n) {
    _markRead(n['id'].toString());

    final type = (n['type'] ?? 'news') as String;
    final title = (n['title'] ?? 'Visit Gondar') as String;
    final body =
        (n['message'] ?? n['body'] ?? '') as String;

    IconData icon; Color color;
    switch (type) {
      case 'safety':
        icon = Icons.warning_amber_rounded; color = AppColors.error; break;
      case 'moment':
        icon = Icons.local_fire_department_outlined;
        color = const Color(0xFF7C5800); break;
      default:
        icon = Icons.campaign_outlined; color = const Color(0xFF1565C0);
    }

    String timeStr = '';
    try {
      final dt = DateTime.parse(n['created_at']).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        timeStr = '${diff.inMinutes} min ago';
      } else if (diff.inHours < 24) {
        timeStr = '${diff.inHours} hours ago';
      } else {
        timeStr = '${diff.inDays} days ago';
      }
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(22, 16, 22,
            22 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(999))),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: color.withAlpha(28),
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(type.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                      color: color, letterSpacing: 1)),
              if (timeStr.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(timeStr, style: const TextStyle(fontSize: 12,
                    color: AppColors.textMuted)),
              ],
            ])),
          ]),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 21,
              fontWeight: FontWeight.w800, color: AppColors.charcoal,
              height: 1.3)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(body, style: const TextStyle(fontSize: 15,
                color: AppColors.textSecondary, height: 1.7)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.charcoal,
                foregroundColor: AppColors.gold,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: const Icon(Icons.arrow_back),
                ),
                const Text('Visit Gondar',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.surfaceVariant),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('EN / አማ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text('Notifications',
                      style: TextStyle(fontSize: 36,
                          fontWeight: FontWeight.w700, height: 1.1)),
                ),
                GestureDetector(
                  onTap: () {
                    notifAsync.whenData((list) {
                      setState(() => _readIds.addAll(
                          list.map((n) => n['id'].toString())));
                      _saveReadIds();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min,
                        children: [
                      Icon(Icons.done_all, size: 15, color: AppColors.gold),
                      SizedBox(width: 6),
                      Text('Mark all read',
                          style: TextStyle(color: AppColors.gold,
                              fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List
          Expanded(
            child: notifAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold)),
              error: (e, _) => Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.notifications_off_outlined,
                      size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  const Text('No notifications yet',
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Text('$e', style: const TextStyle(fontSize: 11,
                      color: AppColors.textMuted), textAlign: TextAlign.center),
                ]),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_outlined,
                          size: 52, color: AppColors.textMuted),
                      SizedBox(height: 12),
                      Text('No notifications yet',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted)),
                      SizedBox(height: 4),
                      Text('Check back soon for updates from Gondar',
                          style: TextStyle(fontSize: 13,
                              color: AppColors.textMuted)),
                    ],
                  ));
                }
                return RefreshIndicator(
                  color: AppColors.gold,
                  onRefresh: () async =>
                      ref.invalidate(notificationsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final n = list[i];
                      final id = n['id'].toString();
                      final isUnread = !_readIds.contains(id);
                      return GestureDetector(
                        onTap: () => _openNotif(n),
                        child: _notifCard(n, isUnread),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _notifCard(Map<String, dynamic> n, bool unread) {
    final type = n['type'] ?? 'news';

    IconData icon;
    Color iconBg, iconColor;

    switch (type) {
      case 'safety':
        icon = Icons.warning_amber_rounded;
        iconBg = const Color(0xFFFFDAD6);
        iconColor = const Color(0xFFBA1A1A);
        break;
      case 'moment':
        icon = Icons.local_fire_department_outlined;
        iconBg = const Color(0xFFFFF3CD);
        iconColor = const Color(0xFF7C5800);
        break;
      default: // news
        icon = Icons.campaign_outlined;
        iconBg = const Color(0xFFE6F0FF);
        iconColor = const Color(0xFF1565C0);
    }

    // Format time
    String timeStr = '';
    try {
      final dt = DateTime.parse(n['created_at']).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        timeStr = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeStr = '${diff.inHours}h ago';
      } else {
        timeStr = '${diff.inDays}d ago';
      }
    } catch (_) {}

    return GestureDetector(
      onTap: () => _openNotif(n),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: unread
              ? const Color(0xFFFFF8E7)
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(color: AppColors.onBackground,
                    fontSize: 14, height: 1.4),
                children: [
                  TextSpan(text: n['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: '  ${n['message'] ?? ''}'),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(timeStr, style: const TextStyle(
                fontSize: 12, color: AppColors.textMuted)),
          ])),
          if (unread)
            Container(
              width: 10, height: 10,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                  color: AppColors.goldDark, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }
}
