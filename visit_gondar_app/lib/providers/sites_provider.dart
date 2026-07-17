import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/site_model.dart';
import '../repositories/sites_repository.dart';

// Repository provider
final sitesRepositoryProvider = Provider((ref) => SitesRepository());

// Selected filter
final sitesFilterProvider = StateProvider<String>((ref) => 'All');

// Sites list — auto-reloads when filter changes
final sitesProvider = FutureProvider.autoDispose<List<SiteModel>>((ref) {
  final repo     = ref.watch(sitesRepositoryProvider);
  final category = ref.watch(sitesFilterProvider);
  return repo.getSites(category: category);
});

// Single site detail
final siteDetailProvider = FutureProvider.autoDispose
    .family<SiteModel, String>((ref, id) {
  final repo = ref.watch(sitesRepositoryProvider);
  return repo.getSiteById(id);
});
