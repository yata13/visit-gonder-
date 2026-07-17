import '../core/constants/app_constants.dart';
import '../models/booking_model.dart';
import '../services/supabase_service.dart';

class BookingsRepository {
  final _db = SupabaseService.client;

  // Get bookings for current user
  Future<List<BookingModel>> getMyBookings() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    final response = await _db
        .from(AppConstants.tableBookings)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response.map((r) => BookingModel.fromJson(r)).toList();
  }

  // Create a new booking request
  Future<BookingModel> createBooking(BookingModel booking) async {
    final response = await _db
        .from(AppConstants.tableBookings)
        .insert(booking.toJson())
        .select()
        .single();
    return BookingModel.fromJson(response);
  }

  // Cancel a booking
  Future<void> cancelBooking(String bookingId) async {
    await _db
        .from(AppConstants.tableBookings)
        .update({'status': 'cancelled'})
        .eq('id', bookingId);
  }
}
