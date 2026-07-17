import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hotel_model.dart';
import '../repositories/hotels_repository.dart';

final hotelsRepositoryProvider = Provider((ref) => HotelsRepository());

final hotelsFilterProvider = StateProvider<String>((ref) => 'Top rated');

final hotelsProvider = FutureProvider.autoDispose<List<HotelModel>>((ref) {
  final repo = ref.watch(hotelsRepositoryProvider);
  final tag  = ref.watch(hotelsFilterProvider);
  return repo.getHotels(tag: tag);
});

final hotelDetailProvider = FutureProvider.autoDispose
    .family<HotelModel, String>((ref, id) {
  final repo = ref.watch(hotelsRepositoryProvider);
  return repo.getHotelById(id);
});
