import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guide_model.dart';
import '../repositories/guides_repository.dart';

final guidesRepositoryProvider = Provider((ref) => GuidesRepository());

final guidesFilterProvider = StateProvider<String>((ref) => 'All');

final guidesProvider = FutureProvider.autoDispose<List<GuideModel>>((ref) {
  final repo = ref.watch(guidesRepositoryProvider);
  final tag  = ref.watch(guidesFilterProvider);
  return repo.getGuides(tag: tag);
});
