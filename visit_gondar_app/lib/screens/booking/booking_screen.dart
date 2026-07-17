import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../theme/app_theme.dart';
import '../../services/booking_service.dart';
import 'my_bookings_screen.dart';

class BookingScreen extends StatefulWidget {
  final String type;           // 'hotel' | 'guide'
  final String referenceId;
  final String referenceName;
  final String referenceImage;
  final double pricePerUnit;   // per night or per day
  final String priceLabel;     // 'night' | 'day'

  const BookingScreen({
    super.key,
    required this.type,
    required this.referenceId,
    required this.referenceName,
    required this.referenceImage,
    required this.pricePerUnit,
    required this.priceLabel,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _service = BookingService();
  final _name    = TextEditingController();
  final _contact = TextEditingController();

  DateTime _checkIn  = DateTime.now().add(const Duration(days: 1));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 3));
  int _guests = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefillDetails();
  }

  /// Pre-fill the form with what we already know about the visitor —
  /// their account name and the phone they last booked with — so they
  /// don't have to retype it every time.
  Future<void> _prefillDetails() async {
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata;
    final name = (meta?['full_name'] ?? meta?['name'] ?? '') as String;
    if (name.isNotEmpty) _name.text = name;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedContact = prefs.getString(AppConstants.prefMyContact);
      if (savedContact != null && savedContact.isNotEmpty) {
        _contact.text = savedContact;
      } else if (user?.email != null) {
        // fall back to the account email if no phone saved yet
        _contact.text = user!.email!;
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  int get _days => _checkOut.difference(_checkIn).inDays;
  double get _total => widget.pricePerUnit * _days * _guests;
  double get _rate =>
      widget.type == 'guide' ? kGuideCommissionRate : kHotelCommissionRate;
  double get _commission => _total * _rate;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isCheckIn) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isCheckIn ? _checkIn : _checkOut,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.charcoal,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isCheckIn) {
        _checkIn = picked;
        if (_checkOut.isBefore(_checkIn.add(const Duration(days: 1)))) {
          _checkOut = _checkIn.add(const Duration(days: 1));
        }
      } else {
        _checkOut = picked;
      }
    });
  }

  Future<void> _confirmBooking() async {
    if (_name.text.trim().isEmpty || _contact.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name and phone number');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      // Price/commission are computed server-side from the item id + dates;
      // the client never sends money figures.
      final booking = await _service.createBooking(
        itemType:        widget.type,
        itemId:          widget.referenceId,
        customerName:    _name.text.trim(),
        customerContact: _contact.text.trim(),
        checkIn:         _checkIn,
        checkOut:        _checkOut,
        guests:          _guests,
      );

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => BookingConfirmedScreen(
          booking: booking,
          days: _days,
          priceLabel: widget.priceLabel,
        ),
      ));
    } on PostgrestException catch (e) {
      // The RPC raises friendly messages (bad dates, item unavailable, …).
      setState(() { _error = e.message; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    String fmt(DateTime d) => '${d.day} ${_month(d.month)} ${d.year}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Book ${widget.type == 'hotel' ? 'Room' : 'Guide'}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Property card ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(15),
                  blurRadius: 8)],
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(widget.referenceImage,
                    width: 72, height: 72, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 72, height: 72,
                        color: AppColors.surfaceVariant,
                        child: const Icon(Icons.hotel,
                            color: AppColors.textMuted))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.referenceName,
                    style: const TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text('\$${widget.pricePerUnit.toStringAsFixed(0)} / ${widget.priceLabel}',
                    style: const TextStyle(color: AppColors.goldDark,
                        fontWeight: FontWeight.w600)),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Your details ──
          const Text('Your Details',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: _inputDecoration('Full name', Icons.person_outline),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contact,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration(
                'Phone / WhatsApp', Icons.phone_outlined),
          ),
          const SizedBox(height: 24),

          // ── Dates ──
          const Text('Select Dates',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _dateCard(
                widget.type == 'hotel' ? 'Check-in' : 'Start Date',
                fmt(_checkIn), () => _pickDate(true))),
            const SizedBox(width: 12),
            Expanded(child: _dateCard(
                widget.type == 'hotel' ? 'Check-out' : 'End Date',
                fmt(_checkOut), () => _pickDate(false))),
          ]),
          const SizedBox(height: 8),
          Center(
            child: Text('$_days ${_days == 1 ? widget.priceLabel : '${widget.priceLabel}s'}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          const SizedBox(height: 20),

          // ── Guests ──
          const Text('Guests', style: TextStyle(fontWeight: FontWeight.w700,
              fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Number of guests',
                    style: TextStyle(fontSize: 15)),
                Row(children: [
                  IconButton(
                    onPressed: _guests > 1
                        ? () => setState(() => _guests--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppColors.charcoal,
                  ),
                  Text('$_guests',
                      style: const TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  IconButton(
                    onPressed: _guests < 10
                        ? () => setState(() => _guests++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.charcoal,
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Price breakdown ──
          const Text('Price Breakdown',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              _priceRow('\$${widget.pricePerUnit.toStringAsFixed(0)} × $_days ${widget.priceLabel}s × $_guests guest${_guests > 1 ? 's' : ''}',
                  '\$${_total.toStringAsFixed(2)}'),
              const Divider(height: 20),
              _priceRow('Platform fee (${(_rate * 100).toStringAsFixed(0)}%)',
                  '\$${_commission.toStringAsFixed(2)}',
                  color: AppColors.textMuted, small: true),
              const Divider(height: 20),
              _priceRow('Total you pay',
                  '\$${_total.toStringAsFixed(2)}',
                  bold: true),
            ]),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(color: AppColors.error,
                        fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 100),
        ]),
      ),

      // ── Bottom confirm button ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(20),
              blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('\$${_total.toStringAsFixed(0)} total',
                  style: const TextStyle(fontSize: 20,
                      fontWeight: FontWeight.w700)),
              Text('$_days ${widget.priceLabel}s · $_guests guest${_guests > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12,
                      color: AppColors.textMuted)),
            ]),
            SizedBox(
              width: 160,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _confirmBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.charcoal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: AppColors.charcoal))
                    : const Text('Confirm Booking',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          const Text('No charge today · pay on arrival',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      );

  Widget _dateCard(String label, String date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11,
              color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(date, style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          const Icon(Icons.calendar_today_outlined,
              size: 14, color: AppColors.goldDark),
        ]),
      ),
    );
  }

  Widget _priceRow(String label, String value,
      {Color? color, bool small = false, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(label, style: TextStyle(
            fontSize: small ? 12 : 14,
            color: color ?? AppColors.onBackground))),
        Text(value, style: TextStyle(
            fontSize: small ? 12 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? AppColors.onBackground)),
      ]),
    );
  }

  String _month(int m) => const ['','Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'][m];
}

// ── Booking confirmed screen ──
class BookingConfirmedScreen extends StatelessWidget {
  final Map<String, dynamic> booking;
  final int days;
  final String priceLabel;
  const BookingConfirmedScreen({
    super.key, required this.booking,
    required this.days, required this.priceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final total = ((booking['total_price'] ?? booking['price'] ?? 0) as num)
        .toDouble();
    // Short, friendly reference from the booking id (first 6 chars).
    final rawId = (booking['id'] ?? '').toString().replaceAll('-', '');
    final ref = rawId.isEmpty
        ? ''
        : rawId.substring(0, rawId.length < 6 ? rawId.length : 6).toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: const BoxDecoration(
                  color: AppColors.greenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: AppColors.green, size: 52),
              ),
              const SizedBox(height: 24),
              const Text('Booking Requested!',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Your $days-$priceLabel booking at ${booking['item_name']} has been submitted.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15,
                      color: AppColors.textMuted, height: 1.5)),
              const SizedBox(height: 16),

              // Booking reference
              if (ref.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('Booking #$ref',
                      style: const TextStyle(color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 13, letterSpacing: 1)),
                ),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(15),
                      blurRadius: 8)],
                ),
                child: Column(children: [
                  _row('Property', '${booking['item_name'] ?? '—'}'),
                  const Divider(height: 20),
                  _row('Total', '\$${total.toStringAsFixed(0)}'),
                  const Divider(height: 20),
                  _row('Status', 'Pending confirmation'),
                  const Divider(height: 20),
                  _row('Payment', 'Pay on arrival'),
                ]),
              ),
              const SizedBox(height: 16),

              // What happens next
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF1DC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFF9C7320)),
                  SizedBox(width: 10),
                  Expanded(child: Text(
                    'The hotel will confirm shortly. You can check the status any time under "My Bookings" — it updates the moment they confirm.',
                    style: TextStyle(fontSize: 12.5,
                        color: Color(0xFF6D4C1F), height: 1.5),
                  )),
                ]),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(context,
                      MaterialPageRoute(
                          builder: (_) => const MyBookingsScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.charcoal,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Track My Booking',
                      style: TextStyle(fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Back to Home',
                      style: TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 15, color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: AppColors.textMuted,
          fontSize: 14)),
      Flexible(child: Text(value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
    ],
  );
}
