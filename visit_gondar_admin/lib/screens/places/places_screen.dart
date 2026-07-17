import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_supabase.dart';

// ═══════════════════════════════════════════════════════════════
//  MAP MANAGER — full control of every pin on the tourist app map.
//  Tap the map to set a location, fill the form, save. Categories:
//  hotel, castle, church, museum, store, club, restaurant, other.
//  Requires the `places` table (run ALL_IN_ONE.sql once).
// ═══════════════════════════════════════════════════════════════
class PlacesAdminScreen extends StatefulWidget {
  const PlacesAdminScreen({super.key});
  @override
  State<PlacesAdminScreen> createState() => _PlacesAdminScreenState();
}

const _categories = [
  'hotel', 'castle', 'church', 'museum',
  'store', 'club', 'restaurant', 'other',
];

class _PlacesAdminScreenState extends State<PlacesAdminScreen> {
  List<Map<String, dynamic>> _places = [];
  bool _loading = true;
  bool _tableMissing = false;
  bool _saving = false;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nameAmCtrl = TextEditingController();
  final _photoCtrl = TextEditingController();
  final _infoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'hotel';
  LatLng? _picked;
  String? _editingId;

  static const _center = LatLng(12.6040, 37.4700);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _tableMissing = false; });
    try {
      final data = await AdminSupabase.db
          .from('places')
          .select()
          .order('created_at');
      _places = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if ('$e'.contains('places')) _tableMissing = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startEdit(Map<String, dynamic> p) {
    setState(() {
      _editingId = p['id'].toString();
      _nameCtrl.text = (p['name_en'] ?? '') as String;
      _nameAmCtrl.text = (p['name_am'] ?? '') as String;
      _photoCtrl.text = (p['photo'] ?? '') as String;
      _infoCtrl.text = (p['info'] ?? '') as String;
      _descCtrl.text = (p['description'] ?? '') as String;
      _category = (p['category'] ?? 'other') as String;
      final lat = p['lat'], lng = p['lng'];
      _picked = (lat is num && lng is num)
          ? LatLng(lat.toDouble(), lng.toDouble())
          : null;
    });
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _nameCtrl.clear(); _nameAmCtrl.clear(); _photoCtrl.clear();
      _infoCtrl.clear(); _descCtrl.clear();
      _category = 'hotel';
      _picked = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_picked == null) {
      _snack('Tap the map to set the location first', error: true);
      return;
    }
    setState(() => _saving = true);
    final row = {
      'name_en': _nameCtrl.text.trim(),
      'name_am': _nameAmCtrl.text.trim(),
      'category': _category,
      'photo': _photoCtrl.text.trim(),
      'info': _infoCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'lat': _picked!.latitude,
      'lng': _picked!.longitude,
    };
    try {
      if (_editingId != null) {
        await AdminSupabase.db
            .from('places').update(row).eq('id', _editingId!);
      } else {
        await AdminSupabase.db.from('places').insert(row);
      }
      _snack(_editingId != null ? 'Place updated' : 'Place added to the map');
      _clearForm();
      await _load();
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text('Remove this place from the map?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        )) ?? false;
    if (!ok) return;
    try {
      await AdminSupabase.db.from('places').delete().eq('id', id);
      if (_editingId == id) _clearForm();
      await _load();
    } catch (e) { _snack('$e', error: true); }
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AdminColors.error : AdminColors.success,
      ));

  Color _catColor(String c) {
    switch (c) {
      case 'hotel':      return const Color(0xFF1565C0);
      case 'castle':     return const Color(0xFFA8451F);
      case 'church':     return const Color(0xFF6A1B9A);
      case 'museum':     return const Color(0xFF00695C);
      case 'store':      return const Color(0xFFEF6C00);
      case 'club':       return const Color(0xFFC2185B);
      case 'restaurant': return const Color(0xFF2E7D32);
      default:           return AdminColors.textMuted;
    }
  }

  IconData _catIcon(String c) {
    switch (c) {
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

  @override
  Widget build(BuildContext context) {
    if (_tableMissing) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdminColors.warningBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'The places table does not exist yet. Run ALL_IN_ONE.sql '
            '(in the visit_gondar_admin folder) once in the Supabase SQL Editor, then reload this page.',
            style: TextStyle(fontSize: 13,
                color: AdminColors.textPrimary, height: 1.5),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(builder: (ctx, c) {
        final wide = c.maxWidth > 1000;
        final form = SizedBox(
            width: wide ? 360 : c.maxWidth, child: _formPanel());
        final mapAndList = Expanded(
          child: Column(children: [
            Expanded(flex: 3, child: _mapPanel()),
            const SizedBox(height: 14),
            Expanded(flex: 2, child: _listPanel()),
          ]),
        );
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            SingleChildScrollView(child: form),
            const SizedBox(width: 20),
            mapAndList,
          ]);
        }
        return ListView(children: [
          form,
          const SizedBox(height: 16),
          SizedBox(height: 420, child: _mapPanel()),
          const SizedBox(height: 16),
          SizedBox(height: 360, child: _listPanel()),
        ]);
      }),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 12),
    child: Text(t, style: const TextStyle(fontSize: 11,
        fontWeight: FontWeight.w700, color: AdminColors.textSecondary,
        letterSpacing: 0.5)),
  );

  Widget _formPanel() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border)),
    child: Form(key: _formKey, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(_editingId != null ? Icons.edit_location_alt : Icons.add_location_alt,
            color: AdminColors.gold, size: 18),
        const SizedBox(width: 8),
        Text(_editingId != null ? 'EDIT PLACE' : 'ADD PLACE',
            style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AdminColors.textPrimary, letterSpacing: 0.5)),
        const Spacer(),
        if (_editingId != null)
          TextButton(onPressed: _clearForm, child: const Text('Cancel')),
      ]),

      // Picked location indicator
      Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _picked == null
              ? AdminColors.warningBg : AdminColors.successBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(_picked == null ? Icons.touch_app : Icons.check_circle,
              size: 16,
              color: _picked == null
                  ? AdminColors.warning : AdminColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _picked == null
                  ? 'Tap the map to set the location'
                  : 'Location: ${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 12,
                  color: AdminColors.textPrimary),
            ),
          ),
        ]),
      ),

      _label('CATEGORY'),
      Wrap(spacing: 6, runSpacing: 6,
        children: _categories.map((cat) {
          final selected = _category == cat;
          return GestureDetector(
            onTap: () => setState(() => _category = cat),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? _catColor(cat).withOpacity(0.15)
                    : AdminColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: selected ? _catColor(cat) : AdminColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_catIcon(cat), size: 13, color: _catColor(cat)),
                const SizedBox(width: 5),
                Text(cat.toUpperCase(), style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: selected
                        ? _catColor(cat) : AdminColors.textMuted)),
              ]),
            ),
          );
        }).toList(),
      ),

      _label('NAME (ENGLISH)'),
      TextFormField(
        controller: _nameCtrl,
        decoration: const InputDecoration(hintText: 'e.g. Goha Hotel'),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
      _label('ስም (አማርኛ) — optional'),
      TextFormField(
        controller: _nameAmCtrl,
        decoration: const InputDecoration(hintText: 'የአማርኛ ስም'),
      ),
      _label('SHORT INFO — shown under the name'),
      TextFormField(
        controller: _infoCtrl,
        decoration: const InputDecoration(
            hintText: 'e.g. \$120/night · ★★★★★  or  Entry 200 ETB'),
      ),
      _label('DESCRIPTION — optional'),
      TextFormField(
        controller: _descCtrl, maxLines: 3,
        decoration: const InputDecoration(
            hintText: 'A sentence or two about this place'),
      ),
      _label('PHOTO URL — optional'),
      TextFormField(
        controller: _photoCtrl,
        decoration: const InputDecoration(
            hintText: 'https://… direct link ending in .jpg / .png'),
      ),
      const SizedBox(height: 18),

      SizedBox(
        width: double.infinity, height: 46,
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Icon(_editingId != null ? Icons.save : Icons.add_location_alt,
                  size: 16),
          label: Text(_editingId != null
              ? 'SAVE CHANGES' : 'ADD TO MAP'),
        ),
      ),
    ])),
  );

  Widget _mapPanel() => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border)),
    child: FlutterMap(
      options: MapOptions(
        initialCenter: _picked ?? _center,
        initialZoom: 14.5,
        onTap: (_, point) => setState(() => _picked = point),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.visitgondar.admin',
        ),
        MarkerLayer(markers: [
          // Existing places
          ..._places.where((p) =>
              p['lat'] is num && p['lng'] is num).map((p) {
            final cat = (p['category'] ?? 'other') as String;
            return Marker(
              point: LatLng((p['lat'] as num).toDouble(),
                  (p['lng'] as num).toDouble()),
              width: 32, height: 32,
              child: GestureDetector(
                onTap: () => _startEdit(p),
                child: Container(
                  decoration: BoxDecoration(
                    color: _catColor(cat),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(_catIcon(cat),
                      color: Colors.white, size: 14),
                ),
              ),
            );
          }),
          // Currently picked location
          if (_picked != null)
            Marker(
              point: _picked!,
              width: 44, height: 44,
              child: const Icon(Icons.location_pin,
                  color: AdminColors.error, size: 44),
            ),
        ]),
      ],
    ),
  );

  Widget _listPanel() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PLACES ON THE MAP (${_places.length})',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
              color: AdminColors.textPrimary, letterSpacing: 0.5)),
      const Divider(color: AdminColors.border, height: 16),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(
                color: AdminColors.gold))
            : _places.isEmpty
                ? const Center(child: Text(
                    'No places yet — tap the map and add the first one.',
                    style: TextStyle(color: AdminColors.textMuted)))
                : ListView.builder(
                    itemCount: _places.length,
                    itemBuilder: (_, i) {
                      final p = _places[i];
                      final cat = (p['category'] ?? 'other') as String;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AdminColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _editingId == p['id'].toString()
                                  ? AdminColors.gold : AdminColors.border),
                        ),
                        child: Row(children: [
                          Icon(_catIcon(cat),
                              size: 16, color: _catColor(cat)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                              (p['name_en'] ?? '') as String,
                              style: const TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AdminColors.textPrimary))),
                          Text(cat.toUpperCase(),
                              style: TextStyle(fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _catColor(cat))),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _startEdit(p),
                            child: const Icon(Icons.edit_outlined,
                                size: 16, color: AdminColors.textMuted),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _delete(p['id'].toString()),
                            child: const Icon(Icons.delete_outline,
                                size: 16, color: AdminColors.textMuted),
                          ),
                        ]),
                      );
                    },
                  ),
      ),
    ]),
  );
}
