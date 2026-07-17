import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

/// Commission rates for the on-screen price *estimate* only.
/// The authoritative rate + commission are computed SERVER-SIDE by the
/// `create_booking` Postgres RPC, which reads them from the
/// `commission_rates` table. Never trust these values for anything charged.
const double kHotelCommissionRate = 0.03; // display estimate — hotels 3%
const double kGuideCommissionRate = 0.10; // display estimate — guides 10%

class BookingService {
  final _db = Supabase.instance.client;

  /// Creates a booking via the server-side `create_booking` RPC.
  /// The client never sends a price or commission — the database looks up
  /// the current price from `hotels`/`guides`, the rate from
  /// `commission_rates`, validates the dates/guests, and inserts the row.
  Future<Map<String, dynamic>> createBooking({
    required String itemType, // 'hotel' | 'guide'
    required String itemId,   // hotel/guide row id
    required String customerName,
    required String customerContact,
    required DateTime checkIn,
    required DateTime checkOut,
    int guests = 1,
  }) async {
    String d(DateTime x) => x.toIso8601String().split('T').first;

    final res = await _db.rpc('create_booking', params: {
      'p_item_type':        itemType,
      'p_item_id':          itemId,
      'p_check_in':         d(checkIn),
      'p_check_out':        d(checkOut),
      'p_guests':           guests,
      'p_customer_name':    customerName,
      'p_customer_contact': customerContact,
    });

    // A function returning a single row may arrive as an object or a
    // one-element list depending on PostgREST negotiation — handle both.
    final booking = (res is List)
        ? Map<String, dynamic>.from(res.first as Map)
        : Map<String, dynamic>.from(res as Map);

    // Remember the contact locally so the Account screen can show
    // this device's bookings.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefMyContact, customerContact);
    } catch (_) {}

    return booking;
  }

  Future<List<Map<String, dynamic>>> getBookingsByContact(
      String contact) async {
    final res = await _db
        .from('bookings')
        .select()
        .eq('customer_contact', contact)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Cancels the signed-in user's own pending booking via the
  /// `cancel_my_booking` RPC. Direct client UPDATE on `bookings` is
  /// revoked, so this is the only path.
  Future<void> cancelBooking(String bookingId) async {
    await _db.rpc('cancel_my_booking', params: {'p_booking_id': bookingId});
  }

  /// Live stream of the signed-in user's bookings, newest first.
  /// When the admin confirms or cancels, this updates instantly.
  static Stream<List<Map<String, dynamic>>> myBookingsStream() {
    final email = Supabase.instance.client.auth.currentUser?.email;
    return Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
            .where((b) => email != null && b['user_email'] == email)
            .toList());
  }
}
