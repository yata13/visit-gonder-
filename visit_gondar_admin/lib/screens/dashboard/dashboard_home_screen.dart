import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_supabase.dart';
import 'package:intl/intl.dart';

// ── Providers ──────────────────────────────────────────────────
final dashboardStatsProvider = FutureProvider<_DashStats>((ref) async {
  final db = AdminSupabase.db;

  // Run each query independently so one failure doesn't block others
  int hotels = 0, guides = 0, sites = 0, events = 0;
  List bookings = [];

  try { hotels  = ((await db.from('hotels').select('id')) as List).length; } catch (_) {}
  try { guides  = ((await db.from('guides').select('id')) as List).length; } catch (_) {}
  try { sites   = ((await db.from('sites').select('id')) as List).length; } catch (_) {}
  try { events  = ((await db.from('events').select('id')) as List).length; } catch (_) {}
  // select() with no column list works on both the legacy schema and the
  // post-migration schema (total_price / commission_amount may not exist yet)
  try { bookings = (await db.from('bookings').select()) as List; } catch (_) {}

  final totalRevenue = bookings.fold<double>(
      0, (s, b) => s + ((b['total_price'] ?? b['price'] ?? 0) as num).toDouble());
  final totalCommission = bookings.fold<double>(
      0, (s, b) => s + ((b['commission_amount'] ?? b['commission_earned'] ?? 0) as num).toDouble());
  final pendingCount = bookings
      .where((b) => b['status'] == 'pending').length;

  return _DashStats(
    hotels: hotels, guides: guides, sites: sites,
    events: events, totalBookings: bookings.length,
    totalRevenue: totalRevenue, totalCommission: totalCommission,
    pendingBookings: pendingCount,
  );
});

final recentBookingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    // No explicit column list — works before and after the commission migration
    final data = await AdminSupabase.db
        .from('bookings')
        .select()
        .order('created_at', ascending: false)
        .limit(8);
    return List<Map<String, dynamic>>.from(data);
  } catch (_) {
    return [];
  }
});

// ── Screen ─────────────────────────────────────────────────────
class DashboardHomeScreen extends ConsumerWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final bookingsAsync = ref.watch(recentBookingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          _Greeting(),
          const SizedBox(height: 28),

          // Stats grid
          statsAsync.when(
            loading: () => _StatsGridSkeleton(),
            error: (e, _) => _ErrorCard('Failed to load stats: $e'),
            data: (s) => _StatsGrid(stats: s),
          ),
          const SizedBox(height: 28),

          // Recent bookings
          const Text('Recent Bookings',
              style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.textPrimary)),
          const SizedBox(height: 14),
          bookingsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AdminColors.gold)),
            error: (e, _) => _ErrorCard('$e'),
            data: (list) => _RecentBookingsTable(bookings: list),
          ),
        ],
      ),
    );
  }
}

// ── Greeting ───────────────────────────────────────────────────
class _Greeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' :
                     hour < 17 ? 'Good afternoon' : 'Good evening';
    final user = AdminSupabase.currentUser;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$greeting 👋',
              style: const TextStyle(fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Managing Visit Gondar as ${user?.email ?? "Admin"}',
              style: const TextStyle(
                  fontSize: 13, color: AdminColors.textMuted)),
        ]),
      ),
      // Date chip
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AdminColors.border),
        ),
        child: Text(
          DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
          style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AdminColors.textSecondary),
        ),
      ),
    ]);
  }
}

// ── Stats grid ─────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final _DashStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(
        icon: Icons.receipt_long_rounded,
        label: 'Total Bookings',
        value: '${stats.totalBookings}',
        sub: '${stats.pendingBookings} pending',
        color: AdminColors.violet,
      ),
      _StatCard(
        icon: Icons.payments_rounded,
        label: 'Total Revenue',
        value: '\$${stats.totalRevenue.toStringAsFixed(0)}',
        sub: 'All time',
        color: AdminColors.green,
      ),
      _StatCard(
        icon: Icons.percent_rounded,
        label: 'Commission Earned',
        value: '\$${stats.totalCommission.toStringAsFixed(2)}',
        sub: '3% hotels · 10% guides',
        color: AdminColors.amber,
      ),
      _StatCard(
        icon: Icons.hotel_rounded,
        label: 'Active Hotels',
        value: '${stats.hotels}',
        sub: 'Listed',
        color: AdminColors.blue,
      ),
      _StatCard(
        icon: Icons.person_pin_rounded,
        label: 'Verified Guides',
        value: '${stats.guides}',
        sub: 'Licensed',
        color: AdminColors.cyan,
      ),
      _StatCard(
        icon: Icons.account_balance_rounded,
        label: 'Historic Sites',
        value: '${stats.sites}',
        sub: '${stats.events} events',
        color: AdminColors.rose,
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 1100
          ? 3 : constraints.maxWidth > 720 ? 2 : 1;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 2.5,
        children: cards,
      );
    });
  }
}

class _StatCard extends StatefulWidget {
  final IconData icon;
  final String label, value, sub;
  final Color color;
  const _StatCard({
    required this.icon, required this.label,
    required this.value, required this.sub,
    required this.color,
  });
  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: _hover
            ? (Matrix4.identity()..translate(0.0, -4.0))
            : Matrix4.identity(),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c, Color.lerp(c, Colors.black, 0.28)!],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: c.withOpacity(_hover ? 0.45 : 0.30),
            blurRadius: _hover ? 24 : 16,
            offset: const Offset(0, 8),
          )],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(widget.icon, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Text(widget.value, style: const TextStyle(fontSize: 25,
                  fontWeight: FontWeight.w800, color: Colors.white,
                  letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(widget.label, style: const TextStyle(fontSize: 12.5,
                  color: Colors.white, fontWeight: FontWeight.w700)),
              Text(widget.sub, style: TextStyle(fontSize: 11,
                  color: Colors.white.withOpacity(0.8))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StatsGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 1100
          ? 3 : constraints.maxWidth > 720 ? 2 : 1;
      return GridView.count(
        crossAxisCount: cols, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 18, crossAxisSpacing: 18, childAspectRatio: 2.5,
        children: List.generate(6, (_) => Container(
          decoration: BoxDecoration(
            color: AdminColors.border,
            borderRadius: BorderRadius.circular(18),
          ),
        )),
      );
    });
  }
}

// ── Recent bookings table ───────────────────────────────────────
class _RecentBookingsTable extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  const _RecentBookingsTable({required this.bookings});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AdminColors.border),
        ),
        child: const Text('No bookings yet',
            style: TextStyle(color: AdminColors.textMuted, fontSize: 14)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(children: [
        // Header
        _tableRow(
          id: 'ID', type: 'Type', name: 'Name',
          amount: 'Amount', status: 'Status',
          date: 'Date', isHeader: true,
        ),
        const Divider(height: 1, color: AdminColors.border),
        ...bookings.asMap().entries.map((e) {
          final b = e.value;
          final name = b['item_name'] ?? b['customer_name'] ?? '—';
          final type = b['item_type'] == 'guide' ? 'Guide' : 'Hotel';
          final amount = '\$${((b['total_price'] ?? b['price'] ?? 0) as num).toStringAsFixed(0)}';
          final status = b['status'] ?? 'pending';
          final date = b['created_at'] != null
              ? DateFormat('d MMM').format(DateTime.parse(b['created_at']))
              : '—';
          return Column(children: [
            _tableRow(
              id: '#${b['id'].toString().substring(0, 6)}',
              type: type, name: name,
              amount: amount, status: status, date: date,
            ),
            if (e.key < bookings.length - 1)
              const Divider(height: 1, color: AdminColors.border),
          ]);
        }),
      ]),
    );
  }

  Widget _tableRow({
    required String id, required String type, required String name,
    required String amount, required String status, required String date,
    bool isHeader = false,
  }) {
    final style = isHeader
        ? const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: AdminColors.textMuted)
        : const TextStyle(fontSize: 13, color: AdminColors.textPrimary);

    Color statusColor = AdminColors.warning;
    Color statusBg = AdminColors.warningBg;
    if (status == 'confirmed') { statusColor = AdminColors.success; statusBg = AdminColors.successBg; }
    if (status == 'cancelled') { statusColor = AdminColors.error;   statusBg = AdminColors.errorBg;   }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        SizedBox(width: 80,  child: Text(id, style: style)),
        SizedBox(width: 70,  child: Text(type, style: style)),
        Expanded(           child: Text(name, style: style)),
        SizedBox(width: 80,  child: Text(amount, style: style)),
        SizedBox(width: 100, child: isHeader
            ? Text(status, style: style)
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status,
                    style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              )),
        SizedBox(width: 70, child: Text(date, style: style)),
      ]),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AdminColors.errorBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(message,
        style: const TextStyle(color: AdminColors.error, fontSize: 13)),
  );
}

// ── Stats model ────────────────────────────────────────────────
class _DashStats {
  final int hotels, guides, sites, events, totalBookings, pendingBookings;
  final double totalRevenue, totalCommission;
  const _DashStats({
    required this.hotels, required this.guides, required this.sites,
    required this.events, required this.totalBookings,
    required this.pendingBookings, required this.totalRevenue,
    required this.totalCommission,
  });
}
