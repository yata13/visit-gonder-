import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../services/booking_service.dart';
import '../../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  ACCOUNT — real profile from Supabase auth, real bookings from
//  the SAME `bookings` table the admin manages. No mock data.
// ═══════════════════════════════════════════════════════════════
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loadingBookings = true;

  User? get _user => Supabase.instance.client.auth.currentUser;

  String get _displayName {
    final meta = _user?.userMetadata;
    final name = (meta?['full_name'] ?? meta?['name'] ?? '') as String;
    if (name.isNotEmpty) return name;
    final email = _user?.email;
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Guest Explorer';
  }

  String get _initials {
    final parts = _displayName.trim().split(RegExp(r'\s+'));
    return parts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
  }

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  /// Bookings made from this device (saved by contact at booking time).
  Future<void> _loadBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contact = prefs.getString(AppConstants.prefMyContact);
      if (contact == null || contact.isEmpty) {
        setState(() => _loadingBookings = false);
        return;
      }
      final bookings = await BookingService().getBookingsByContact(contact);
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _loadingBookings = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header bar
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
              const SizedBox(height: 24),

              // Profile section — real auth user (initials avatar, no mock photo)
              Center(
                child: Column(children: [
                  Stack(children: [
                    Container(
                      width: 88, height: 88,
                      decoration: const BoxDecoration(
                        color: AppColors.charcoal,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(_initials,
                            style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 30,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    if (_user != null)
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified, size: 14,
                              color: AppColors.goldDeep),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Text(_displayName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(_user?.email ?? 'Sign in to sync your bookings',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ]),
              ),
              const SizedBox(height: 28),

              // My Bookings — live from the bookings table
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('My Bookings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: _loadingBookings
                    ? const Center(child: CircularProgressIndicator(
                        color: AppColors.gold, strokeWidth: 2))
                    : _bookings.isEmpty
                        ? const Center(
                            child: Text('No bookings yet — book a hotel or guide',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textMuted)))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _bookings.length,
                            itemBuilder: (_, i) => _bookingCard(_bookings[i]),
                          ),
              ),
              const SizedBox(height: 24),

              // Settings menu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                        blurRadius: 8)],
                  ),
                  child: Column(children: [
                    _menuItem(Icons.download_outlined, 'Offline downloads'),
                    _divider(),
                    _menuItem(Icons.emergency_outlined, 'Emergency help',
                        iconColor: Colors.red),
                    _divider(),
                    _menuItem(Icons.record_voice_over_outlined, 'Useful phrases'),
                    _divider(),
                    _menuItemWithValue(Icons.language, 'Language', 'English'),
                    _divider(),
                    _menuItem(Icons.settings_outlined, 'Settings'),
                  ]),
                ),
              ),
              const SizedBox(height: 24),

              // Sign out
              if (_user != null)
                Center(
                  child: TextButton(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (mounted) setState(() {});
                    },
                    child: const Text('Sign Out',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600,
                            fontSize: 15)),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> b) {
    final name = (b['item_name'] ?? '—') as String;
    final type = (b['item_type'] ?? 'hotel') as String;
    final date = (b['booking_date'] ?? '') as String;
    final status = (b['status'] ?? 'pending') as String;
    final total = ((b['total_price'] ?? b['price'] ?? 0) as num).toDouble();

    final statusColor = switch (status) {
      'approved' || 'confirmed' => AppColors.green,
      'cancelled' => AppColors.error,
      _ => AppColors.goldDark,
    };

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(type == 'guide' ? Icons.person_pin_outlined : Icons.hotel_outlined,
              color: AppColors.rust),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(date,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('\$${total.toStringAsFixed(0)} · ${type == 'guide' ? 'Guide' : 'Hotel'}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(status,
                  style: TextStyle(fontSize: 10,
                      color: statusColor, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _menuItem(IconData icon, String label, {Color iconColor = AppColors.onBackground}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
        const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ]),
    );
  }

  Widget _menuItemWithValue(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 20),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
        Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ]),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 50, color: AppColors.surfaceVariant);
}
