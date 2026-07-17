import '../core/constants/app_constants.dart';
import '../models/hotel_model.dart';
import '../services/supabase_service.dart';

class HotelsRepository {
  final _db = SupabaseService.client;

  // Get all hotels sorted by rating
  Future<List<HotelModel>> getHotels({String? tag}) async {
    final response = await _db
        .from(AppConstants.tableHotels)
        .select()
        .order('rating', ascending: false);

    final all = response.map((r) => HotelModel.fromJson(r)).toList();

    if (tag != null && tag != 'Top rated') {
      return all.where((h) => h.tag == tag).toList();
    }
    return all;
  }

  // Get single hotel
  Future<HotelModel> getHotelById(String id) async {
    final response = await _db
        .from(AppConstants.tableHotels)
        .select()
        .eq('id', id)
        .single();
    return HotelModel.fromJson(response);
  }
}
