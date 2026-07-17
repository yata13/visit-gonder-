import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../emergency/emergency_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  MAP — every pin comes from the live database (hotels + sites
//  with lat/lng). No hardcoded places. Clean no-label base map.
//  "Get Directions" opens the place in Google Maps.
// ═══════════════════════════════════════════════════════════════
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

/// Categories the admin can assign in the Map Manager.
const kPlaceCategories = [
  'hotel', 'castle', 'church', 'museum',
  'store', 'club', 'restaurant', 'other',
];

class _MapPlace {
  final String id, name, subtitle, detail, imageUrl, category;
  final LatLng position;
  const _MapPlace({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.detail,
    required this.imageUrl,
    required this.category,
    required this.position,
  });
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  _MapPlace? _selectedPlace;
  String? _activeFilter;
  List<Map<String, dynamic>> _dangerZones = [];
  bool _showDangerBanner = false;

  // Gondar city center — Piazza area
  static const _center = LatLng(12.6040, 37.4700);

  static final _gondarBounds = LatLngBounds(
    const LatLng(12.550, 37.400),
    const LatLng(12.670, 37.540),
  );

  @override
  void initState() {
    super.initState();
    _loadDangerZones();
  }

  Future<void> _loadDangerZones() async {
    try {
      final data = await Supabase.instance.client
          .from('danger_zones')
          .select()
          .eq('is_active', true);
      setState(() {
        _dangerZones = List<Map<String, dynamic>>.from(data);
        _showDangerBanner = _dangerZones.isNotEmpty;
      });
    } catch (_) {}
  }

  /// Every pin comes from the `places` table — the admin manages
  /// them in the Map Manager tab. Rows without coords are skipped.
  List<_MapPlace> _livePlaces(String lang) {
    final places = <_MapPlace>[];
    for (final p in ref.watch(placesProvider).value ?? const []) {
      final lat = p['lat'], lng = p['lng'];
      if (lat is! num || lng is! num) continue;
      places.add(_MapPlace(
        id: '${p['id']}',
        name: localName(p, lang),
        subtitle: (p['info'] ?? '') as String,
        detail: (p['description'] ?? '') as String,
        imageUrl: (p['photo'] ?? '') as String,
        category: (p['category'] ?? 'other') as String,
        position: LatLng(lat.toDouble(), lng.toDouble()),
      ));
    }
    return places;
  }

  Future<void> _openDirections(_MapPlace p) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${p.position.latitude},${p.position.longitude}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'low':      return const Color(0xFF4CAF50);
      case 'high':     return const Color(0xFFFF9800);
      case 'critical': return const Color(0xFFD32F2F);
      default:         return const Color(0xFFFFC107);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final all = _livePlaces(lang);
    final filtered = _activeFilter == null
        ? all
        : all.where((p) => p.category == _activeFilter).toList();
    // Only offer filter chips for categories that actually have pins.
    final presentCategories = kPlaceCategories
        .where((c) => all.any((p) => p.category == c))
        .toList();

    return Scaffold(
      body: Stack(children: [

        // ── REAL MAP — clean tiles, no street labels ──
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 14.5,
            minZoom: 12.5,
            maxZoom: 18.5,
            cameraConstraint: CameraConstraint.containCenter(
              bounds: _gondarBounds,
            ),
            onTap: (_, __) => setState(() => _selectedPlace = null),
          ),
          children: [
            // No-label tiles: no street names in any language —
            // our own pins carry the names instead.
            TileLayer(
              urlTemplate:
                  'https://basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.visitgondar.app',
            ),

            // ── Danger Zone Circles ──
            if (_dangerZones.isNotEmpty)
              CircleLayer(
                circles: _dangerZones.map((z) {
                  final color = _severityColor(z['severity'] ?? 'medium');
                  return CircleMarker(
                    point: LatLng(
                      (z['lat'] as num).toDouble(),
                      (z['lng'] as num).toDouble(),
                    ),
                    radius: (z['radius'] as num? ?? 500).toDouble(),
                    useRadiusInMeter: true,
                    color: color.withAlpha(50),
                    borderColor: color.withAlpha(200),
                    borderStrokeWidth: 2.5,
                  );
                }).toList(),
              ),

            // ── Danger Zone Markers ──
            if (_dangerZones.isNotEmpty)
              MarkerLayer(
                markers: _dangerZones.map((z) => Marker(
                  point: LatLng(
                    (z['lat'] as num).toDouble(),
                    (z['lng'] as num).toDouble(),
                  ),
                  width: 36, height: 36,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(context: context, builder: (_) => AlertDialog(
                        icon: const Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 32),
                        title: Text(z['name'] ?? 'Danger Zone'),
                        content: Text(z['description'] ??
                            'This area is currently unsafe. Please avoid.'),
                        actions: [TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Got it'),
                        )],
                      ));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _severityColor(z['severity'] ?? 'medium'),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(
                          color: _severityColor(z['severity'] ?? 'medium')
                              .withAlpha(150),
                          blurRadius: 8,
                        )],
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                )).toList(),
              ),

            // ── Place pins (LIVE from database) ──
            MarkerLayer(
              markers: filtered.map((place) => Marker(
                point: place.position,
                width: 38,
                height: 38,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedPlace = place);
                    _mapController.move(place.position, 16.0);
                  },
                  child: AnimatedScale(
                    scale: _selectedPlace?.id == place.id ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _pinColor(place.category),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [BoxShadow(
                            color: _pinColor(place.category).withAlpha(110),
                            blurRadius: 8, spreadRadius: 1)],
                      ),
                      child: Icon(
                        _pinIcon(place.category),
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ],
        ),

        // ── DANGER ZONE BANNER ──
        if (_showDangerBanner)
          Positioned(
            bottom: 100, left: 16, right: 16,
            child: GestureDetector(
              onTap: () => setState(() => _showDangerBanner = false),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                    color: Colors.red.withAlpha(100),
                    blurRadius: 12, offset: const Offset(0, 4),
                  )],
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️ Safety Alert',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(
                        '${_dangerZones.length} danger zone${_dangerZones.length > 1 ? 's' : ''} active in Gondar. Tap red markers for details.',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  )),
                  const Icon(Icons.close, color: Colors.white70, size: 18),
                ]),
              ),
            ),
          ),

        // ── TOP CONTROLS ──
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 10)],
                      ),
                      child: const Row(children: [
                        Icon(Icons.location_city,
                            size: 16, color: AppColors.goldDark),
                        SizedBox(width: 6),
                        Text('Gondar City Map',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ]),
                    ),

                    // SOS Button
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const EmergencyScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                              color: Colors.red.withAlpha(120),
                              blurRadius: 12)],
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min,
                            children: [
                          Icon(Icons.sos_outlined,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('SOS', style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w900, fontSize: 13,
                              letterSpacing: 1)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Zoom buttons
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 10)],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        _zoomBtn(Icons.add, 1),
                        const Divider(height: 1),
                        _zoomBtn(Icons.remove, -1),
                      ]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Filter chips — one per category that has pins
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  _chip('All', null, Icons.layers),
                  ...presentCategories.map((c) =>
                      _chip(_categoryLabel(c), c, _pinIcon(c))),
                ]),
              ),
            ],
          ),
        ),

        // ── RECENTER BUTTON ──
        Positioned(
          right: 16,
          bottom: _selectedPlace != null ? 220 : 30,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            onPressed: () => _mapController.move(_center, 14.5),
            backgroundColor: Colors.white,
            foregroundColor: AppColors.darkBrown,
            elevation: 4,
            child: const Icon(Icons.my_location, size: 20),
          ),
        ),

        // ── SELECTED PLACE CARD ──
        if (_selectedPlace != null)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 24, offset: const Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 36, height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(999))),
                  const SizedBox(height: 12),

                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _selectedPlace!.imageUrl.isNotEmpty
                          ? Image.network(_selectedPlace!.imageUrl,
                              width: 80, height: 80, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholderBox())
                          : _placeholderBox(),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _pinColor(_selectedPlace!.category)
                                .withAlpha(26),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                              _categoryLabel(_selectedPlace!.category)
                                  .toUpperCase(),
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: _pinColor(
                                      _selectedPlace!.category))),
                        ),
                        const SizedBox(height: 6),
                        Text(_selectedPlace!.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 17)),
                        if (_selectedPlace!.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(_selectedPlace!.subtitle,
                              style: const TextStyle(fontSize: 12.5,
                                  color: AppColors.goldDark,
                                  fontWeight: FontWeight.w600)),
                        ],
                        if (_selectedPlace!.detail.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(_selectedPlace!.detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12,
                                  color: AppColors.textMuted, height: 1.4)),
                        ],
                      ]),
                    ),
                  ]),

                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _selectedPlace = null),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Close'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          side: const BorderSide(
                              color: AppColors.surfaceVariant),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _openDirections(_selectedPlace!),
                        icon: const Icon(Icons.directions, size: 16),
                        label: const Text('Get Directions',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkBrown,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
      ]),
    );
  }

  Widget _zoomBtn(IconData icon, int delta) => IconButton(
    icon: Icon(icon, size: 18),
    onPressed: () => _mapController.move(
        _mapController.camera.center,
        _mapController.camera.zoom + delta),
    padding: const EdgeInsets.all(8),
    constraints: const BoxConstraints(),
  );

  Widget _chip(String label, String? category, IconData icon) {
    final selected = _activeFilter == category;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkBrown : Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(
              color: Colors.black.withAlpha(26), blurRadius: 6)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13,
              color: selected ? Colors.white : AppColors.textMuted),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.onBackground)),
        ]),
      ),
    );
  }

  Widget _placeholderBox() => Container(
    width: 80, height: 80,
    decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12)),
    child: Icon(_pinIcon(_selectedPlace!.category),
        color: _pinColor(_selectedPlace!.category), size: 28),
  );

  Color _pinColor(String category) {
    switch (category) {
      case 'hotel':      return const Color(0xFF1565C0);
      case 'castle':     return AppColors.rust;
      case 'church':     return const Color(0xFF6A1B9A);
      case 'museum':     return const Color(0xFF00695C);
      case 'store':      return const Color(0xFFEF6C00);
      case 'club':       return const Color(0xFFC2185B);
      case 'restaurant': return const Color(0xFF2E7D32);
      default:           return AppColors.textMuted;
    }
  }

  IconData _pinIcon(String category) {
    switch (category) {
      case 'hotel':      return Icons.hotel;
      case 'castle':     return Icons.fort;
      case 'church':     return Icons.church;
      case 'museum':     return Icons.museum;
      case 'store':      return Icons.storefront;
      case 'club':       return Icons.nightlife;
      case 'restaurant': return Icons.restaurant;
      default:           return Icons.place;
    }
  }

  String _categoryLabel(String category) =>
      category.isEmpty
          ? 'Place'
          : category[0].toUpperCase() + category.substring(1);
}
