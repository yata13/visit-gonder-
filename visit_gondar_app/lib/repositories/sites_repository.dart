import '../core/constants/app_constants.dart';
import '../models/site_model.dart';
import '../services/supabase_service.dart';

class SitesRepository {
  final _db = SupabaseService.client;

  // Get all sites (optional category filter)
  Future<List<SiteModel>> getSites({String? category}) async {
    var query = _db
        .from(AppConstants.tableSites)
        .select()
        .order('rating', ascending: false);

    final response = await query;
    final all = response.map((r) => SiteModel.fromJson(r)).toList();

    if (category != null && category != 'All') {
      return all.where((s) => s.category == category).toList();
    }
    return all;
  }

  // Get single site by id
  Future<SiteModel> getSiteById(String id) async {
    final response = await _db
        .from(AppConstants.tableSites)
        .select()
        .eq('id', id)
        .single();
    return SiteModel.fromJson(response);
  }

  // Search sites by name
  Future<List<SiteModel>> searchSites(String query) async {
    final response = await _db
        .from(AppConstants.tableSites)
        .select()
        .ilike('name', '%$query%');
    return response.map((r) => SiteModel.fromJson(r)).toList();
  }
}
