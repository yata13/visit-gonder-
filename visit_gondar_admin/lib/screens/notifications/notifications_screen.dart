import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_data_service.dart';

class NotificationsAdminScreen extends StatefulWidget {
  const NotificationsAdminScreen({super.key});
  @override
  State<NotificationsAdminScreen> createState() => _NotificationsAdminScreenState();
}

class _NotificationsAdminScreenState extends State<NotificationsAdminScreen> {
  List<AdminNotification> _notifications = [];
  bool _loading = true;
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String _type = 'news';
  bool _sendToAll = true;
  bool _sending = false;
  String? _successMsg;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { _notifications = await AdminDataService.getNotifications(); setState(() {}); }
    catch (e) { _snack('$e', error: true); }
    finally { setState(() => _loading = false); }
  }

  Future<void> _dispatch() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final n = AdminNotification(
        id: '',
        title: _titleCtrl.text.trim(),
        type: _type,
        message: _msgCtrl.text.trim(),
        sendToAll: _sendToAll,
        createdAt: DateTime.now().toIso8601String(),
      );
      await AdminDataService.saveNotification(n);
      _titleCtrl.clear(); _msgCtrl.clear();
      setState(() => _successMsg = 'Alert "${n.title}" dispatched to all tourists!');
      Future.delayed(const Duration(seconds: 4),
          () => setState(() => _successMsg = null));
      await _load();
    } catch (e) { _snack('$e', error: true); }
    finally { setState(() => _sending = false); }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete notification?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        )) ?? false;
    if (!ok) return;
    try { await AdminDataService.deleteNotification(id); await _load(); }
    catch (e) { _snack('$e', error: true); }
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AdminColors.error : AdminColors.success,
      ));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Advisory Alerts & Moments', style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w800, color: AdminColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Compose push alerts, news posts and safety warnings for Gondar tourists.',
            style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
        const SizedBox(height: 6),
        const Divider(color: AdminColors.border),
        const SizedBox(height: 20),

        LayoutBuilder(builder: (ctx, c) {
          final side = c.maxWidth > 900;
          if (side) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 360, child: _composer()),
              const SizedBox(width: 20),
              Expanded(child: _logPanel()),
            ]);
          }
          return Column(children: [_composer(), const SizedBox(height: 20), _logPanel()]);
        }),
      ]),
    );
  }

  Widget _composer() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border)),
    child: Form(key: _formKey, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.volume_up_outlined, color: AdminColors.gold, size: 18),
        SizedBox(width: 8),
        Text('COMPOSE BROADCAST', style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w800, color: AdminColors.textPrimary,
            letterSpacing: 0.5)),
      ]),
      const SizedBox(height: 16),

      // Success
      if (_successMsg != null) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: Colors.green.shade500, width: 3))),
          child: Row(children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(_successMsg!, style: const TextStyle(
                fontSize: 12, color: Colors.green))),
          ]),
        ),
        const SizedBox(height: 14),
      ],

      // Type selector
      const Text('ANNOUNCEMENT TYPE', style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w700, color: AdminColors.textSecondary,
          letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Row(children: [
        _typeBtn('news', '📰 NEWS'),
        const SizedBox(width: 8),
        _typeBtn('moment', '⚡ MOMENT'),
        const SizedBox(width: 8),
        _typeBtn('safety', '⚠️ SAFETY'),
      ]),
      const SizedBox(height: 14),

      const Text('HEADLINE / TITLE', style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w700, color: AdminColors.textSecondary,
          letterSpacing: 0.5)),
      const SizedBox(height: 6),
      TextFormField(
        controller: _titleCtrl,
        decoration: const InputDecoration(
            hintText: 'e.g. Fasilides Castle Closed Earlier Today'),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 14),

      const Text('MESSAGE BODY', style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w700, color: AdminColors.textSecondary,
          letterSpacing: 0.5)),
      const SizedBox(height: 6),
      TextFormField(
        controller: _msgCtrl, maxLines: 4,
        decoration: const InputDecoration(
            hintText: 'Write notice instructions or news detail...'),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 12),

      Row(children: [
        Checkbox(value: _sendToAll, activeColor: AdminColors.gold,
            onChanged: (v) => setState(() => _sendToAll = v ?? true)),
        const Expanded(child: Text('Broadcast to all tourists on foot',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: AdminColors.textSecondary))),
      ]),
      const SizedBox(height: 14),

      SizedBox(
        width: double.infinity, height: 46,
        child: ElevatedButton.icon(
          onPressed: _sending ? null : _dispatch,
          icon: _sending
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: 16),
          label: const Text('DISPATCH BROADCAST ALERT'),
        ),
      ),
    ])),
  );

  Widget _typeBtn(String val, String label) {
    final selected = _type == val;
    Color bg = selected ? const Color(0xFFFAF1DF) : AdminColors.surface;
    Color border = selected ? AdminColors.gold : AdminColors.border;
    if (val == 'moment' && selected) bg = Colors.amber[100]!;
    if (val == 'moment' && selected) border = Colors.amber.shade500;
    if (val == 'safety' && selected) bg = Colors.red[100]!;
    if (val == 'safety' && selected) border = Colors.red.shade400;

    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _type = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border)),
        child: Center(child: Text(label, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'monospace',
            color: selected ? AdminColors.textPrimary : AdminColors.textMuted))),
      ),
    ));
  }

  Widget _logPanel() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.notifications_active_outlined,
            color: Colors.redAccent, size: 16),
        const SizedBox(width: 8),
        Text('ANNOUNCEMENT LOGS (${_notifications.length})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                color: AdminColors.textPrimary, letterSpacing: 0.5)),
      ]),
      const Divider(color: AdminColors.border, height: 20),

      if (_loading)
        const Center(child: CircularProgressIndicator(color: AdminColors.gold))
      else if (_notifications.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('No notifications sent yet.',
              style: TextStyle(color: AdminColors.textMuted))))
      else
        ..._notifications.map((n) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AdminColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminColors.border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _typeIcon(n.type),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _typeBadge(n.type),
                const SizedBox(width: 8),
                Text(_formatDate(n.createdAt), style: const TextStyle(
                    fontSize: 10, color: AdminColors.textMuted,
                    fontFamily: 'monospace')),
              ]),
              const SizedBox(height: 4),
              Text(n.title, style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w700, color: AdminColors.textPrimary)),
              const SizedBox(height: 2),
              Text(n.message, style: const TextStyle(fontSize: 11,
                  color: AdminColors.textSecondary, height: 1.4)),
            ])),
            GestureDetector(
              onTap: () => _delete(n.id),
              child: const Padding(padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline, size: 16,
                    color: AdminColors.textMuted)),
            ),
          ]),
        )),
    ]),
  );

  Widget _typeIcon(String type) {
    IconData icon; Color color;
    switch (type) {
      case 'safety': icon = Icons.warning_amber_outlined; color = Colors.red; break;
      case 'moment': icon = Icons.local_fire_department_outlined; color = Colors.orange; break;
      default:       icon = Icons.campaign_outlined; color = AdminColors.gold;
    }
    return Icon(icon, size: 18, color: color);
  }

  Widget _typeBadge(String type) {
    Color bg; Color fg;
    switch (type) {
      case 'safety': bg = Colors.red[50]!; fg = Colors.red[800]!; break;
      case 'moment': bg = Colors.amber[50]!; fg = Colors.amber[900]!; break;
      default:       bg = Colors.blue[50]!; fg = Colors.blue[800]!;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(type.toUpperCase(), style: TextStyle(fontSize: 9,
          fontWeight: FontWeight.w700, color: fg, fontFamily: 'monospace')),
    );
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('d MMM yyyy, HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) { return iso; }
  }
}
