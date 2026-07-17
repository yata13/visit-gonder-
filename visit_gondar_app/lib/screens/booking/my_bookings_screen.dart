import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/language_provider.dart';
import '../../services/booking_service.dart';

// Live stream of the current user's bookings.
final myBookingsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>(
        (ref) => BookingService.myBookingsStream());

// ═══════════════════════════════════════════════════════════════
//  MY BOOKINGS — the tourist tracks every booking and its status.
//  Pending → Confirmed / Cancelled updates appear live.
// ═══════════════════════════════════════════════════════════════
class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final am = isAm(lang);
    final async = ref.watch(myBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceVariant),
                  ),
                  child: const Icon(Icons.arrow_back,
                      size: 18, color: AppColors.charcoal),
                ),
              ),
              const SizedBox(width: 14),
              Text(am ? 'የእኔ ቦታ ማስያዣዎች' : 'My Bookings',
                  style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal, letterSpacing: -0.4)),
            ]),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold)),
              error: (e, _) => Center(child: Text('$e',
                  style: const TextStyle(color: AppColors.textMuted))),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 52, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(am ? 'እስካሁን ምንም ማስያዣ የለም'
                              : 'No bookings yet',
                          style: const TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(am ? 'ሆቴል ወይም መመሪያ ሲይዙ እዚህ ይታያል'
                              : 'When you book a hotel or guide it shows here',
                          style: const TextStyle(fontSize: 13,
                              color: AppColors.textMuted)),
                    ]),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _BookingCard(b: list[i], am: am),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> b;
  final bool am;
  const _BookingCard({required this.b, required this.am});

  @override
  Widget build(BuildContext context) {
    final name = (b['item_name'] ?? '—') as String;
    final type = (b['item_type'] ?? 'hotel') as String;
    final status = (b['status'] ?? 'pending') as String;
    final total = ((b['total_price'] ?? b['price'] ?? 0) as num).toDouble();
    String date = '';
    try {
      date = DateFormat('d MMM yyyy')
          .format(DateTime.parse(b['booking_date']));
    } catch (_) { date = (b['booking_date'] ?? '') as String; }

    final (statusColor, statusBg, statusLabel, statusIcon) = switch (status) {
      'confirmed' || 'approved' => (AppColors.green, AppColors.greenLight,
          am ? 'ተረጋግጧል' : 'Confirmed', Icons.check_circle),
      'cancelled' || 'rejected' => (AppColors.error, AppColors.errorLight,
          am ? 'ተሰርዟል' : 'Cancelled', Icons.cancel),
      _ => (const Color(0xFF9C7320), const Color(0xFFFBF1DC),
          am ? 'በመጠባበቅ ላይ' : 'Pending', Icons.hourglass_top),
    };
    final isConfirmed = status == 'confirmed' || status == 'approved';
    final isCancelled = status == 'cancelled' || status == 'rejected';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.charcoal.withAlpha(12),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(type == 'guide' ? Icons.person_pin : Icons.hotel,
                color: AppColors.rust, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15.5,
                    fontWeight: FontWeight.w800, color: AppColors.charcoal)),
            const SizedBox(height: 2),
            Text(date, style: const TextStyle(fontSize: 12.5,
                color: AppColors.textMuted)),
          ])),
          Text('\$${total.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w800, color: AppColors.charcoal)),
        ]),
        const SizedBox(height: 14),
        // Status banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(statusIcon, size: 17, color: statusColor),
            const SizedBox(width: 8),
            Text(statusLabel, style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w800, color: statusColor)),
            const Spacer(),
            Text(
              isConfirmed
                  ? (am ? 'በመድረሻ ይክፈሉ' : 'Pay on arrival')
                  : isCancelled
                      ? (am ? 'እንደገና ይሞክሩ' : 'Please rebook')
                      : (am ? 'ሆቴሉ ያረጋግጣል' : 'Awaiting the hotel'),
              style: TextStyle(fontSize: 11.5, color: statusColor.withAlpha(200)),
            ),
          ]),
        ),
      ]),
    );
  }
}
