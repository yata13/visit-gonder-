import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_supabase.dart';

// ── Model ─────────────────────────────────────────────────────
class DangerZone {
  final String id, name, description, severity;
  final double lat, lng;
  final int radius;
  final bool isActive;

  DangerZone({
    required this.id, required this.name, required this.description,
    required this.severity, required this.lat, required this.lng,
    required this.radius, required this.isActive,
  });

  factory DangerZone.fromJson(Map<String, dynamic> j) => DangerZone(
    id: j['id']?.toString() ?? '',
    name: j['name'] ?? '',
    description: j['description'] ?? '',
    severity: j['severity'] ?? 'medium',
    lat: (j['lat'] ?? 12.6030).toDouble(),
    lng: (j['lng'] ?? 37.4521).toDouble(),
    radius: (j['radius'] ?? 500).toInt(),
    isActive: j['is_active'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'name': name, 'description': description, 'severity': severity,
    'lat': lat, 'lng': lng, 'radius': radius, 'is_active': isActive,
  };
}

// ── Screen ────────────────────────────────────────────────────
class SafetyAdminScreen extends StatefulWidget {
  const SafetyAdminScreen({super.key});
  @override
  State<SafetyAdminScreen> createState() => _SafetyAdminScreenState();
}

class _SafetyAdminScreenState extends State<SafetyAdminScreen> {
  final db = AdminSupabase.db;
  List<DangerZone> _zones = [];
  bool _loading = true;
  LatLng? _pendingPin; // where user tapped on map
  bool _showForm = false;

  // form
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _severity = 'medium';
  int _radius = 500;

  static const _gondar = LatLng(12.6030, 37.4521);

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await db.from('danger_zones').select()
          .order('created_at', ascending: false);
      setState(() => _zones = (data as List).map((e) => DangerZone.fromJson(e)).toList());
    } catch (e) {
      _snack('Load failed: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _pendingPin == null) return;
    try {
      final zone = DangerZone(
        id: '', name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        severity: _severity,
        lat: _pendingPin!.latitude, lng: _pendingPin!.longitude,
        radius: _radius, isActive: true,
      );
      await db.from('danger_zones').insert(zone.toJson());
      _nameCtrl.clear(); _descCtrl.clear();
      setState(() { _pendingPin = null; _showForm = false; _severity = 'medium'; _radius = 500; });
      await _load();
      _snack('Danger zone added!');
    } catch (e) {
      _snack('Save failed: $e', error: true);
    }
  }

  Future<void> _toggleActive(DangerZone z) async {
    await db.from('danger_zones').update({'is_active': !z.isActive}).eq('id', z.id);
    await _load();
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete danger zone?'),
        content: const Text('This will remove it from the tourist map.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ));
    if (ok == true) {
      await db.from('danger_zones').delete().eq('id', id);
      await _load();
      _snack('Zone deleted');
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : AdminColors.gold,
    ));
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'low':      return const Color(0xFF4CAF50);
      case 'high':     return const Color(0xFFFF9800);
      case 'critical': return const Color(0xFFD32F2F);
      default:         return const Color(0xFFFFC107);
    }
  }

  IconData _severityIcon(String s) {
    switch (s) {
      case 'low':      return Icons.info_outline;
      case 'high':     return Icons.warning_amber_rounded;
      case 'critical': return Icons.dangerous_outlined;
      default:         return Icons.warning_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          color: Colors.white,
          child: Row(children: [
            const Icon(Icons.shield_outlined, color: AdminColors.gold),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Safety Map', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text('Mark danger zones — tourists see them on their map',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            ])),
            if (!_showForm)
              ElevatedButton.icon(
                onPressed: () => setState(() => _showForm = true),
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Add Zone'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.gold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ]),
        ),

        Expanded(
          child: Row(children: [
            // ── Map ─────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Stack(children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _gondar,
                    initialZoom: 13,
                    onTap: _showForm ? (_, latlng) {
                      setState(() => _pendingPin = latlng);
                    } : null,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a','b','c','d'],
                    ),
                    // Danger zone circles
                    CircleLayer(
                      circles: _zones.map((z) => CircleMarker(
                        point: LatLng(z.lat, z.lng),
                        radius: z.radius.toDouble(),
                        useRadiusInMeter: true,
                        color: _severityColor(z.severity).withAlpha(z.isActive ? 60 : 20),
                        borderColor: _severityColor(z.severity).withAlpha(z.isActive ? 200 : 80),
                        borderStrokeWidth: 2,
                      )).toList(),
                    ),
                    // Zone labels
                    MarkerLayer(
                      markers: [
                        ..._zones.map((z) => Marker(
                          point: LatLng(z.lat, z.lng),
                          width: 36, height: 36,
                          child: Tooltip(
                            message: '${z.name}\n${z.severity.toUpperCase()}',
                            child: Container(
                              decoration: BoxDecoration(
                                color: _severityColor(z.severity),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(
                                  color: _severityColor(z.severity).withAlpha(120),
                                  blurRadius: 8,
                                )],
                              ),
                              child: Icon(_severityIcon(z.severity),
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        )),
                        // Pending pin
                        if (_pendingPin != null) Marker(
                          point: _pendingPin!,
                          width: 40, height: 40,
                          child: const Icon(Icons.location_pin,
                              color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
                // Tap hint
                if (_showForm && _pendingPin == null)
                  Positioned(
                    top: 16, left: 0, right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AdminColors.bronze,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.touch_app, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text('Tap on the map to place the danger zone',
                              style: TextStyle(color: Colors.white, fontSize: 13)),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),

            // ── Right Panel ──────────────────────────────────
            Container(
              width: 320,
              color: Colors.white,
              child: _showForm ? _buildForm() : _buildZoneList(),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('New Danger Zone',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            onPressed: () => setState(() { _showForm = false; _pendingPin = null; }),
            icon: const Icon(Icons.close),
          ),
        ]),

        if (_pendingPin != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Pin placed at\n${_pendingPin!.latitude.toStringAsFixed(4)}, ${_pendingPin!.longitude.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 12),
              )),
            ]),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.touch_app, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Text('Tap the map to place pin first',
                  style: TextStyle(fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        const Text('Zone Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            hintText: 'e.g. North Road Checkpoint',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 14),

        const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _descCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'What is the danger? Advise tourists...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 14),

        const Text('Severity Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: ['low', 'medium', 'high', 'critical'].map((s) {
          final selected = _severity == s;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _severity = s),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? _severityColor(s) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected ? _severityColor(s) : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  s[0].toUpperCase() + s.substring(1),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }).toList()),
        const SizedBox(height: 14),

        const Text('Warning Radius', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Slider(
              value: _radius.toDouble(),
              min: 100, max: 3000,
              divisions: 29,
              activeColor: AdminColors.gold,
              onChanged: (v) => setState(() => _radius = v.toInt()),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text('${_radius}m',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _pendingPin != null && _nameCtrl.text.isNotEmpty ? _save : null,
            icon: const Icon(Icons.add_location_alt, size: 18),
            label: const Text('Add Danger Zone'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.gold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildZoneList() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AdminColors.gold));
    if (_zones.isEmpty) return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.shield_outlined, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No danger zones yet', style: TextStyle(color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        Text('Click "Add Zone" and tap the map',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
      ]),
    );

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Text('${_zones.length} zone${_zones.length != 1 ? 's' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${_zones.where((z) => z.isActive).length} active',
              style: const TextStyle(fontSize: 12, color: Colors.green)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _zones.length,
          itemBuilder: (_, i) {
            final z = _zones[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: z.isActive
                    ? _severityColor(z.severity).withAlpha(15)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: z.isActive
                      ? _severityColor(z.severity).withAlpha(80)
                      : Colors.grey.shade200,
                ),
              ),
              child: ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: z.isActive
                        ? _severityColor(z.severity)
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_severityIcon(z.severity), color: Colors.white, size: 18),
                ),
                title: Text(z.name,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: z.isActive ? null : Colors.grey,
                    )),
                subtitle: Text(
                  '${z.severity.toUpperCase()} • ${z.radius}m radius',
                  style: TextStyle(fontSize: 11,
                      color: z.isActive ? _severityColor(z.severity) : Colors.grey),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Switch(
                    value: z.isActive,
                    activeColor: AdminColors.gold,
                    onChanged: (_) => _toggleActive(z),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    onPressed: () => _delete(z.id),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
