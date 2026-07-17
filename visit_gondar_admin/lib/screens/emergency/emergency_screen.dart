import 'package:flutter/material.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_supabase.dart';

class EmergencyAdminScreen extends StatefulWidget {
  const EmergencyAdminScreen({super.key});
  @override
  State<EmergencyAdminScreen> createState() => _EmergencyAdminScreenState();
}

class _EmergencyAdminScreenState extends State<EmergencyAdminScreen> {
  final db = AdminSupabase.db;
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String _filter = 'all'; // all / pending / responding / resolved

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await db.from('emergency_requests')
          .select()
          .order('created_at', ascending: false);
      setState(() => _requests = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      _snack('Failed to load: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    await db.from('emergency_requests').update({'status': status}).eq('id', id);
    await _load();
    _snack('Status updated to $status');
  }

  Future<void> _delete(String id) async {
    await db.from('emergency_requests').delete().eq('id', id);
    await _load();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : AdminColors.gold,
    ));
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _requests;
    return _requests.where((r) => r['status'] == _filter).toList();
  }

  int _count(String status) =>
      status == 'all' ? _requests.length
      : _requests.where((r) => r['status'] == status).length;

  @override
  Widget build(BuildContext context) {
    final pending = _count('pending');

    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Column(children: [

        // ── Header ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          color: Colors.white,
          child: Row(children: [
            Stack(children: [
              const Icon(Icons.sos_outlined, color: Colors.red, size: 28),
              if (pending > 0) Positioned(
                right: 0, top: 0,
                child: Container(
                  width: 14, height: 14,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: Center(child: Text('$pending',
                      style: const TextStyle(color: Colors.white, fontSize: 8,
                          fontWeight: FontWeight.bold))),
                ),
              ),
            ]),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Emergency Requests',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text('Live tourist SOS, calls, messages & transport requests',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            ])),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: AdminColors.gold),
              tooltip: 'Refresh',
            ),
          ]),
        ),

        // ── Stats row ────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(children: [
            _statChip('All', _count('all'), Colors.grey, 'all'),
            const SizedBox(width: 8),
            _statChip('Pending', _count('pending'), Colors.red, 'pending'),
            const SizedBox(width: 8),
            _statChip('Responding', _count('responding'), Colors.orange, 'responding'),
            const SizedBox(width: 8),
            _statChip('Resolved', _count('resolved'), Colors.green, 'resolved'),
          ]),
        ),

        const Divider(height: 1),

        // ── List ─────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AdminColors.gold))
              : _filtered.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle_outline, size: 56,
                          color: Colors.green.shade200),
                      const SizedBox(height: 12),
                      Text(_filter == 'all'
                          ? 'No emergency requests yet'
                          : 'No $_filter requests',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text('All tourists are safe ✅',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AdminColors.gold,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _requestCard(_filtered[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _statChip(String label, int count, Color color, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(30) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? color : Colors.grey,
          )),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: selected ? color : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$count', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.grey.shade600,
            )),
          ),
        ]),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r) {
    final type = r['type'] ?? 'message';
    final status = r['status'] ?? 'pending';
    final createdAt = r['created_at'] ?? '';

    IconData typeIcon;
    Color typeColor;
    String typeLabel;
    switch (type) {
      case 'call':
        typeIcon = Icons.phone_in_talk_outlined;
        typeColor = const Color(0xFF1565C0);
        typeLabel = 'Call Request';
        break;
      case 'transport':
        typeIcon = Icons.directions_car_outlined;
        typeColor = const Color(0xFF6A1B9A);
        typeLabel = 'Transport';
        break;
      case 'sos':
        typeIcon = Icons.sos_outlined;
        typeColor = const Color(0xFFD32F2F);
        typeLabel = 'SOS EMERGENCY';
        break;
      default:
        typeIcon = Icons.chat_bubble_outline;
        typeColor = const Color(0xFF00695C);
        typeLabel = 'Message';
    }

    Color statusColor;
    switch (status) {
      case 'responding': statusColor = Colors.orange; break;
      case 'resolved':   statusColor = Colors.green;  break;
      default:           statusColor = Colors.red;
    }

    String timeAgo = '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) timeAgo = '${diff.inMinutes}m ago';
      else if (diff.inHours < 24) timeAgo = '${diff.inHours}h ago';
      else timeAgo = '${diff.inDays}d ago';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'pending'
              ? Colors.red.withAlpha(80)
              : Colors.grey.shade200,
          width: status == 'pending' ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(
          color: Colors.black.withAlpha(10),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Top row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: typeColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(typeIcon, color: typeColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(typeLabel, style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14, color: typeColor)),
              Text(timeAgo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withAlpha(80)),
              ),
              child: Text(status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: statusColor)),
            ),
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Info
          if ((r['name'] ?? '').isNotEmpty)
            _infoRow(Icons.person_outline, r['name']),
          if ((r['phone'] ?? '').isNotEmpty)
            _infoRow(Icons.phone_outlined, r['phone']),
          if ((r['location'] ?? '').isNotEmpty)
            _infoRow(Icons.location_on_outlined, r['location']),
          if ((r['message'] ?? '').isNotEmpty)
            _infoRow(Icons.chat_bubble_outline, r['message']),

          const SizedBox(height: 12),

          // Action buttons
          Row(children: [
            if (status == 'pending') ...[
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _updateStatus(r['id'], 'responding'),
                icon: const Icon(Icons.headset_mic_outlined, size: 16),
                label: const Text('Responding'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )),
              const SizedBox(width: 8),
            ],
            if (status != 'resolved')
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _updateStatus(r['id'], 'resolved'),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Resolved'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _delete(r['id']),
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              tooltip: 'Delete',
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: Colors.grey),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );
}
