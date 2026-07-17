import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_data_service.dart';

class BookingsAdminScreen extends StatefulWidget {
  const BookingsAdminScreen({super.key});
  @override
  State<BookingsAdminScreen> createState() => _BookingsAdminScreenState();
}

class _BookingsAdminScreenState extends State<BookingsAdminScreen> {
  List<AdminBooking> _bookings = [];
  bool _loading = true;
  String _search = '';
  String _filterType = 'all';
  String _filterStatus = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { _bookings = await AdminDataService.getBookings(); setState(() {}); }
    catch (e) { _snack('$e', error: true); }
    finally { setState(() => _loading = false); }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await AdminDataService.updateBookingStatus(id, status);
      await _load();
      _snack('Booking $status');
    } catch (e) { _snack('$e', error: true); }
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AdminColors.error : AdminColors.success,
      ));

  List<AdminBooking> get _filtered => _bookings.where((b) {
    final matchType = _filterType == 'all' || b.itemType == _filterType;
    final matchStatus = _filterStatus == 'all' || b.status == _filterStatus;
    final q = _search.toLowerCase();
    final matchSearch = b.customerName.toLowerCase().contains(q) ||
        b.itemName.toLowerCase().contains(q) ||
        b.customerContact.toLowerCase().contains(q);
    return matchType && matchStatus && matchSearch;
  }).toList();

  // Metrics
  double get _totalVolume => _bookings.where((b) => b.status == 'approved')
      .fold(0, (s, b) => s + b.price);
  double get _totalComm => _bookings.where((b) => b.status == 'approved')
      .fold(0, (s, b) => s + b.commissionEarned);
  int get _pendingCount => _bookings.where((b) => b.status == 'pending').length;
  int get _approvedCount => _bookings.where((b) => b.status == 'approved').length;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Reservations & Commissions Panel', style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w800, color: AdminColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Review bookings, service status and commission (3% hotels · 10% guides).',
            style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
        const SizedBox(height: 6),
        const Divider(color: AdminColors.border),
        const SizedBox(height: 20),

        // Stats
        LayoutBuilder(builder: (ctx, c) {
          final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 2 : 1;
          return GridView.count(
            crossAxisCount: cols, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.4,
            children: [
              _statCard('Approved Sales', '\$${_totalVolume.toStringAsFixed(2)}',
                  'Gross income', Icons.attach_money, AdminColors.success,
                  AdminColors.successBg),
              _statCard('Commission', '\$${_totalComm.toStringAsFixed(2)}',
                  'Visit Gondar cut', Icons.receipt_long,
                  AdminColors.gold, AdminColors.goldLight),
              _statCard('Pending Approval', '${_pendingCount} Requests',
                  'Awaiting your action', Icons.hourglass_empty,
                  AdminColors.warning, AdminColors.warningBg),
              _statCard('Approved Bookings', '${_approvedCount} Bookings',
                  'Settled payments', Icons.check_circle_outline,
                  AdminColors.success, AdminColors.successBg),
            ],
          );
        }),
        const SizedBox(height: 20),

        // Filter bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AdminColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.border)),
          child: LayoutBuilder(builder: (ctx, c) {
            final wide = c.maxWidth > 600;
            final children = [
              SizedBox(
                width: wide ? 280 : double.infinity,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Search traveler, hotel or guide...',
                    prefixIcon: Icon(Icons.search, size: 18,
                        color: AdminColors.textMuted),
                    isDense: true,
                  ),
                ),
              ),
              if (wide) const Spacer(),
              Row(children: [
                const Text('TYPE:', style: TextStyle(fontSize: 11,
                    color: AdminColors.textMuted, fontFamily: 'monospace')),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filterType,
                  underline: const SizedBox(),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'hotel', child: Text('🏨 Hotels', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'guide', child: Text('🧭 Guides', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => setState(() => _filterType = v ?? 'all'),
                ),
                const SizedBox(width: 16),
                const Text('STATUS:', style: TextStyle(fontSize: 11,
                    color: AdminColors.textMuted, fontFamily: 'monospace')),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filterStatus,
                  underline: const SizedBox(),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'pending', child: Text('⏳ Pending', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'approved', child: Text('✅ Approved', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'rejected', child: Text('❌ Rejected', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => setState(() => _filterStatus = v ?? 'all'),
                ),
              ]),
            ];
            return wide
                ? Row(children: children)
                : Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: children);
          }),
        ),
        const SizedBox(height: 16),

        // Table
        Container(
          decoration: BoxDecoration(color: AdminColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.border)),
          child: _loading
              ? const Center(child: Padding(padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AdminColors.gold)))
              : _filtered.isEmpty
                  ? const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Text('No matching reservations found.',
                          style: TextStyle(color: AdminColors.textMuted))))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            AdminColors.background),
                        headingTextStyle: const TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.textMuted,
                            fontFamily: 'monospace', letterSpacing: 0.5),
                        dataTextStyle: const TextStyle(fontSize: 12,
                            color: AdminColors.textPrimary),
                        columns: const [
                          DataColumn(label: Text('BOOKING ID')),
                          DataColumn(label: Text('TRAVELER')),
                          DataColumn(label: Text('OUTLET')),
                          DataColumn(label: Text('DATE')),
                          DataColumn(label: Text('FARE'), numeric: true),
                          DataColumn(label: Text('COMMISSION (10%)'), numeric: true),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('ACTIONS')),
                        ],
                        rows: _filtered.map((bk) => DataRow(cells: [
                          DataCell(Text(bk.id.length > 8
                              ? bk.id.substring(0, 8) : bk.id,
                              style: const TextStyle(fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: AdminColors.textMuted))),
                          DataCell(Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Text(bk.customerName, style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12)),
                            Text(bk.customerContact, style: const TextStyle(
                                fontSize: 10, color: AdminColors.textMuted,
                                fontFamily: 'monospace')),
                          ])),
                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AdminColors.background,
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(bk.itemType.toUpperCase(),
                                  style: const TextStyle(fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace',
                                      color: AdminColors.textSecondary)),
                            ),
                            const SizedBox(width: 6),
                            Text(bk.itemName, style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                          ])),
                          DataCell(Text(bk.bookingDate.length > 10
                              ? bk.bookingDate.substring(0, 10)
                              : bk.bookingDate,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 11))),
                          DataCell(Text('\$${bk.price.toStringAsFixed(0)}',
                              style: const TextStyle(fontFamily: 'monospace'))),
                          DataCell(Text(
                              '\$${bk.commissionEarned.toStringAsFixed(0)}',
                              style: const TextStyle(fontFamily: 'monospace',
                                  color: Colors.green, fontWeight: FontWeight.w700))),
                          DataCell(_statusBadge(bk.status)),
                          DataCell(bk.status == 'pending'
                              ? Row(mainAxisSize: MainAxisSize.min, children: [
                                  _actionBtn('APPROVE', Colors.green[50]!,
                                      Colors.green[800]!,
                                      () => _updateStatus(bk.id, 'approved')),
                                  const SizedBox(width: 6),
                                  _actionBtn('REJECT', Colors.red[50]!,
                                      Colors.red[800]!,
                                      () => _updateStatus(bk.id, 'rejected')),
                                ])
                              : const Text('Processed', style: TextStyle(
                                  fontSize: 10, color: AdminColors.textMuted,
                                  fontStyle: FontStyle.italic))),
                        ])).toList(),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _statCard(String title, String value, String sub,
      IconData icon, Color iconColor, Color bg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border)),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: AdminColors.textMuted, fontFamily: 'monospace')),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
              color: iconColor)),
          Text(sub, style: const TextStyle(fontSize: 10,
              color: AdminColors.textMuted)),
        ])),
      ]),
    );
  }

  Widget _statusBadge(String status) {
    Color bg, fg;
    switch (status) {
      case 'approved': bg = Colors.green[50]!; fg = Colors.green[800]!; break;
      case 'rejected': bg = Colors.red[50]!;   fg = Colors.red[800]!;   break;
      default:         bg = Colors.amber[50]!; fg = Colors.amber[900]!;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9,
          fontWeight: FontWeight.w700, color: fg, fontFamily: 'monospace')),
    );
  }

  Widget _actionBtn(String label, Color bg, Color fg, VoidCallback onTap) =>
      GestureDetector(onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          child: Text(label, style: TextStyle(fontSize: 10,
              fontWeight: FontWeight.w700, color: fg)),
        ),
      );
}
