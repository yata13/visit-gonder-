import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../booking/booking_screen.dart';

class HotelDetailScreen extends StatelessWidget {
  final Map hotel;
  const HotelDetailScreen({super.key, required this.hotel});

  @override
  Widget build(BuildContext context) {
    final amenities = hotel['amenities'] as List;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Hero image
              Stack(children: [
                Image.network(hotel['image'], height: 280,
                    width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(height: 280, color: AppColors.surfaceVariant)),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(Icons.favorite_border, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12, left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.goldDeep,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(hotel['tag'],
                        style: const TextStyle(fontSize: 11, color: AppColors.gold,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(hotel['name'],
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('The Pinnacle of Gondar Hospitality',
                      style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                  const SizedBox(height: 16),

                  // Stats row
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat('\$${hotel['price']}', 'per night'),
                        _stat(hotel['rating'], '${hotel['reviews']} reviews'),
                        _stat(hotel['distance'], 'to Castle'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // About
                  const Text('About this stay',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(hotel['subtitle'],
                      style: const TextStyle(fontSize: 14, color: AppColors.textMuted,
                          height: 1.6)),
                  const SizedBox(height: 20),

                  // Amenities
                  const Text('Amenities',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: amenities.map((a) => _amenityChip(a)).toList(),
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ]),
          ),

          // Bottom booking bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
                    blurRadius: 16, offset: const Offset(0, -4))],
              ),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('\$${hotel['price']}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const Text('total before taxes',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ]),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => BookingScreen(
                        type:           'hotel',
                        referenceId:    hotel['id']?.toString() ?? '',
                        referenceName:  hotel['name'],
                        referenceImage: hotel['image'],
                        pricePerUnit:   (hotel['price'] as int).toDouble(),
                        priceLabel:     'night',
                      )),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.goldDeep,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Request booking',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    ]);
  }

  Widget _amenityChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline, size: 14, color: AppColors.goldDark),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
