import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_data_service.dart';

class HotelsAdminScreen extends StatefulWidget {
  const HotelsAdminScreen({super.key});
  @override
  State<HotelsAdminScreen> createState() => _HotelsAdminScreenState();
}

class _HotelsAdminScreenState extends State<HotelsAdminScreen> {
  List<AdminHotel> _hotels = [];
  bool _loading = true;
  bool _isEditing = false;
  String _search = '';

  // Form state
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _form;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await AdminDataService.getHotels();
      setState(() => _hotels = data);
    } catch (e) {
      _snack('Failed to load hotels: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _startAdd() {
    _form = {
      'id': '', 'name_en': '', 'name_am': '', 'description': '',
      'location': 'Gondar, Ethiopia', 'contact': '+251 ',
      'photos': [''], 'price': 80.0, 'star_ranking': 4,
      'publish_status': 'published',
    };
    setState(() => _isEditing = true);
  }

  void _startEdit(AdminHotel h) {
    _form = {
      'id': h.id, 'name_en': h.nameEn, 'name_am': h.nameAm,
      'description': h.description, 'location': h.location,
      'contact': h.contact,
      'photos': List<String>.from(h.photos.isEmpty ? [''] : h.photos),
      'price': h.price, 'star_ranking': h.starRanking,
      'publish_status': h.publishStatus,
    };
    setState(() => _isEditing = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    try {
      final hotel = AdminHotel(
        id: _form['id'], nameEn: _form['name_en'], nameAm: _form['name_am'],
        description: _form['description'], location: _form['location'],
        contact: _form['contact'],
        photos: (_form['photos'] as List<String>).where((s) => s.isNotEmpty).toList(),
        price: (_form['price'] as num).toDouble(),
        starRanking: _form['star_ranking'],
        publishStatus: _form['publish_status'],
      );
      await AdminDataService.saveHotel(hotel);
      setState(() => _isEditing = false);
      await _load();
      _snack('Hotel saved successfully');
    } catch (e) {
      _snack('Save failed: $e', error: true);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await _confirm('Delete this hotel? This cannot be undone.');
    if (!ok) return;
    try {
      await AdminDataService.deleteHotel(id);
      await _load();
      _snack('Hotel deleted');
    } catch (e) {
      _snack('Delete failed: $e', error: true);
    }
  }

  Future<void> _togglePublish(AdminHotel h) async {
    final next = h.publishStatus == 'published' ? 'hidden' : 'published';
    try {
      await AdminDataService.saveHotel(AdminHotel(
        id: h.id, nameEn: h.nameEn, nameAm: h.nameAm,
        description: h.description, location: h.location,
        contact: h.contact, photos: h.photos, price: h.price,
        starRanking: h.starRanking, publishStatus: next,
      ));
      await _load();
    } catch (e) {
      _snack('Toggle failed', error: true);
    }
  }

  Future<bool> _confirm(String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AdminColors.error : AdminColors.success,
    ));
  }

  List<AdminHotel> get _filtered => _hotels.where((h) =>
    h.nameEn.toLowerCase().contains(_search.toLowerCase()) ||
    h.nameAm.contains(_search) ||
    h.location.toLowerCase().contains(_search.toLowerCase())
  ).toList();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Hotel Listings Manager',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: AdminColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Create, publish, adjust pricing, and assign stars to Gondar hotels.',
                style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
          ])),
          if (!_isEditing)
            ElevatedButton.icon(
              onPressed: _startAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add New Hotel'),
            ),
        ]),
        const SizedBox(height: 6),
        const Divider(color: AdminColors.border),
        const SizedBox(height: 20),

        if (_loading)
          const Center(child: CircularProgressIndicator(color: AdminColors.gold))
        else if (_isEditing)
          _buildForm()
        else
          _buildList(),
      ]),
    );
  }

  // ── FORM ──────────────────────────────────────────────────────
  Widget _buildForm() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 760),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.hotel, color: AdminColors.gold, size: 20),
            const SizedBox(width: 8),
            Text(
              _form['id'].isEmpty ? 'Register New Hotel' : 'Edit Hotel',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: AdminColors.textPrimary),
            ),
          ]),
          const SizedBox(height: 20),

          // Name row
          Row(children: [
            Expanded(child: _field('Hotel Name (English)', 'name_en',
                hint: 'e.g. Goha Hotel')),
            const SizedBox(width: 16),
            Expanded(child: _field('የሆቴል ስም (Amharic)', 'name_am',
                hint: 'ለምሳሌ፡ ጎሃ ሆቴል')),
          ]),
          const SizedBox(height: 16),

          _field('Hotel Description', 'description',
              hint: 'Details of luxury services, cuisine style...', maxLines: 3),
          const SizedBox(height: 16),

          // Price / Stars / Status
          Row(children: [
            Expanded(child: _numberField('Room Cost (USD/night)', 'price')),
            const SizedBox(width: 16),
            Expanded(child: _dropdown('Star Rating', 'star_ranking', [
              _opt(1, '1 Star Economy'), _opt(2, '2 Star Comfort'),
              _opt(3, '3 Star Standard'), _opt(4, '4 Star Deluxe'),
              _opt(5, '5 Star Royal Elite'),
            ])),
            const SizedBox(width: 16),
            Expanded(child: _dropdown('Status', 'publish_status', [
              _opt('published', 'Published (Active)'),
              _opt('pending', 'Pending (Needs review)'),
              _opt('hidden', 'Hidden (Archived)'),
            ])),
          ]),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(child: _field('Location / Address', 'location',
                hint: 'e.g. Goha Hill, Gondar',
                prefix: const Icon(Icons.location_on_outlined, size: 16,
                    color: AdminColors.textMuted))),
            const SizedBox(width: 16),
            Expanded(child: _field('Contact Phone', 'contact',
                hint: '+251 58 111 0000',
                prefix: const Icon(Icons.phone_outlined, size: 16,
                    color: AdminColors.textMuted))),
          ]),
          const SizedBox(height: 16),

          _field('Photo URL', 'photos',
              hint: 'https://images.unsplash.com/...',
              prefix: const Icon(Icons.image_outlined, size: 16,
                  color: AdminColors.textMuted),
              isPhotoField: true),
          const SizedBox(height: 24),

          // Actions
          const Divider(color: AdminColors.border),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              onPressed: () => setState(() => _isEditing = false),
              child: const Text('Discard Changes'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Commit to Database'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _field(String label, String key, {
    String hint = '', int maxLines = 1,
    Widget? prefix, bool isPhotoField = false,
  }) {
    final controller = TextEditingController(
      text: isPhotoField
          ? ((_form['photos'] as List<String>).isNotEmpty
              ? (_form['photos'] as List<String>)[0] : '')
          : _form[key]?.toString() ?? '',
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: AdminColors.textSecondary, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hint, prefixIcon: prefix),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        onSaved: (v) {
          if (isPhotoField) {
            _form['photos'] = [v ?? ''];
          } else {
            _form[key] = v ?? '';
          }
        },
      ),
    ]);
  }

  Widget _numberField(String label, String key) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: AdminColors.textSecondary, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      TextFormField(
        initialValue: _form[key]?.toString() ?? '0',
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(prefixText: '\$ '),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        onSaved: (v) => _form[key] = double.tryParse(v ?? '0') ?? 0.0,
      ),
    ]);
  }

  Widget _dropdown(String label, String key, List<DropdownMenuItem> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: AdminColors.textSecondary, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      DropdownButtonFormField(
        value: _form[key],
        items: items,
        onChanged: (v) => setState(() => _form[key] = v),
        decoration: const InputDecoration(),
      ),
    ]);
  }

  DropdownMenuItem _opt(dynamic val, String label) =>
      DropdownMenuItem(value: val, child: Text(label,
          style: const TextStyle(fontSize: 13)));

  // ── LIST ──────────────────────────────────────────────────────
  Widget _buildList() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Search
      SizedBox(
        width: 380,
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: const InputDecoration(
            hintText: 'Filter by name (EN/አማርኛ) or address...',
            prefixIcon: Icon(Icons.search, size: 18, color: AdminColors.textMuted),
          ),
        ),
      ),
      const SizedBox(height: 20),

      if (_filtered.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Text('No hotels found. Add one above.',
                style: TextStyle(color: AdminColors.textMuted, fontSize: 14)),
          ),
        )
      else
        LayoutBuilder(builder: (ctx, constraints) {
          final cols = constraints.maxWidth > 1000 ? 3
              : constraints.maxWidth > 650 ? 2 : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemCount: _filtered.length,
            itemBuilder: (_, i) => _HotelCard(
              hotel: _filtered[i],
              onEdit: () => _startEdit(_filtered[i]),
              onDelete: () => _delete(_filtered[i].id),
              onToggle: () => _togglePublish(_filtered[i]),
            ),
          );
        }),
    ]);
  }
}

// ── Card ──────────────────────────────────────────────────────
class _HotelCard extends StatelessWidget {
  final AdminHotel hotel;
  final VoidCallback onEdit, onDelete, onToggle;
  const _HotelCard({
    required this.hotel, required this.onEdit,
    required this.onDelete, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isPublished = hotel.publishStatus == 'published';
    final isPending   = hotel.publishStatus == 'pending';
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(children: [
        // Image
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: Stack(children: [
            SizedBox(
              height: 160, width: double.infinity,
              child: hotel.photos.isNotEmpty && hotel.photos[0].isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: hotel.photos[0],
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                          color: AdminColors.background,
                          child: const Icon(Icons.hotel, size: 40,
                              color: AdminColors.textMuted)),
                    )
                  : Container(color: AdminColors.background,
                      child: const Icon(Icons.hotel, size: 40,
                          color: AdminColors.textMuted)),
            ),
            // Badges
            Positioned(top: 10, right: 10, child: Column(
              crossAxisAlignment: CrossAxisAlignment.end, children: [
              _badge(
                hotel.publishStatus,
                isPublished ? Colors.green[800]! : isPending
                    ? Colors.orange[800]! : AdminColors.textMuted,
                isPublished ? Colors.green[50]! : isPending
                    ? Colors.orange[50]! : Colors.grey[100]!,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4)),
                child: Text('\$${hotel.price.toStringAsFixed(0)}/night',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 10, fontFamily: 'monospace')),
              ),
            ])),
          ]),
        ),

        // Body
        Expanded(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Stars
            Row(children: List.generate(5, (i) => Icon(
              i < hotel.starRanking ? Icons.star : Icons.star_border,
              size: 13, color: Colors.amber[600],
            ))),
            const SizedBox(height: 6),
            Text('${hotel.nameEn} (${hotel.nameAm})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: AdminColors.textPrimary),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(hotel.description,
                style: const TextStyle(fontSize: 11, color: AdminColors.textMuted,
                    height: 1.4),
                maxLines: 3, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 11,
                  color: AdminColors.gold),
              const SizedBox(width: 4),
              Expanded(child: Text(hotel.location.split(',')[0],
                  style: const TextStyle(fontSize: 10,
                      color: AdminColors.textMuted, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 11,
                  color: AdminColors.gold),
              const SizedBox(width: 4),
              Text(hotel.contact,
                  style: const TextStyle(fontSize: 10,
                      color: AdminColors.textMuted, fontFamily: 'monospace')),
            ]),
          ]),
        )),

        // Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: AdminColors.background,
            border: Border(top: BorderSide(color: AdminColors.border)),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
          ),
          child: Row(children: [
            // Toggle
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isPublished ? Colors.grey[100] : Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isPublished ? Icons.visibility_off : Icons.visibility,
                      size: 12,
                      color: isPublished ? AdminColors.textMuted
                          : Colors.green[800]),
                  const SizedBox(width: 4),
                  Text(isPublished ? 'HIDE' : 'PUBLISH',
                      style: TextStyle(fontSize: 9,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: isPublished ? AdminColors.textMuted
                              : Colors.green[800])),
                ]),
              ),
            ),
            const Spacer(),
            // Edit
            _iconBtn(Icons.edit_outlined, Colors.blue[700]!,
                Colors.blue[50]!, onEdit),
            const SizedBox(width: 6),
            // Delete
            _iconBtn(Icons.delete_outline, Colors.red[700]!,
                Colors.red[50]!, onDelete),
          ]),
        ),
      ]),
    );
  }

  Widget _badge(String text, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg,
        borderRadius: BorderRadius.circular(4)),
    child: Text(text.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
            color: fg, fontFamily: 'monospace')),
  );

  Widget _iconBtn(IconData icon, Color fg, Color bg, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: bg,
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 14, color: fg),
        ),
      );
}
