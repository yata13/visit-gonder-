import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SiteDetailScreen extends StatelessWidget {
  final Map site;
  const SiteDetailScreen({super.key, required this.site});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nearBlack,
      body: Stack(
        children: [
          // Hero image
          SizedBox(
            height: 320,
            width: double.infinity,
            child: Hero(
              tag: 'site-${site['id']}',
              child: Image.network(site['image'], fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: AppColors.surfaceVariant)),
            ),
          ),

          // Back button
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

          // Content card
          DraggableScrollableSheet(
            initialChildSize: 0.62,
            minChildSize: 0.62,
            maxChildSize: 0.95,
            builder: (_, ctrl) => Container(
              decoration: const BoxDecoration(
                color: AppColors.nearBlack,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: ListView(controller: ctrl, children: [
                // Handle
                Center(
                  child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.white24,
                          borderRadius: BorderRadius.circular(999))),
                ),
                const SizedBox(height: 16),

                // Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('UNESCO INTANGIBLE HERITAGE',
                      style: TextStyle(fontSize: 10, color: AppColors.gold,
                          letterSpacing: 1, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),

                // Title
                Text(site['name'],
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text(site['location'],
                    style: const TextStyle(fontSize: 14, color: Colors.white54)),
                const SizedBox(height: 16),

                // Stats row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat(site['rating'], 'Rating'),
                      _stat('200+', 'Visits/day'),
                      _stat('2.5km', 'From center'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Audio guide button
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.headphones, color: AppColors.gold),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Immersive audio guide',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('Narrated by local historian Dr. A',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Play',
                          style: TextStyle(fontWeight: FontWeight.w700,
                              color: AppColors.goldDeep)),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // About
                const Text('The Imperial Legacy',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 8),
                const Text(
                  'Founded in 1636 by Emperor Fasilides, this former city served as the home of Ethiopia\'s emperors for over two centuries. The architectural style represents a unique fusion of local traditions with Hindu and Arab influences, reflecting the diverse cultural exchanges of the era.\n\nWander through the massive 900-meter-long wall to discover palatial ruins, intricately designed banqueting halls, and ancient bathing pavilions that whisper tales of a glorious imperial past.',
                  style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.6),
                ),
                const SizedBox(height: 24),

                // Directions button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.directions),
                    label: const Text('Get directions',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.goldDeep,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
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
      Text(value, style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.w700, fontSize: 18)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }
}
