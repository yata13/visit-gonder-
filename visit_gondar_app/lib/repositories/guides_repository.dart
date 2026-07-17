import '../core/constants/app_constants.dart';
import '../models/guide_model.dart';
import '../services/supabase_service.dart';

class GuidesRepository {
  final _db = SupabaseService.client;

  Future<List<GuideModel>> getGuides({String? tag}) async {
    final response = await _db
        .from(AppConstants.tableGuides)
        .select()
        .order('rating', ascending: false);

    final all = response.map((r) => GuideModel.fromJson(r)).toList();

    if (tag != null && tag != 'All') {
      return all.where((g) => g.tags.contains(tag)).toList();
    }
    return all;
  }

  Future<GuideModel> getGuideById(String id) async {
    final response = await _db
        .from(AppConstants.tableGuides)
        .select()
        .eq('id', id)
        .single();
    return GuideModel.fromJson(response);
  }
}
