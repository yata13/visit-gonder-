import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_data_service.dart';

class SitesAdminScreen extends StatefulWidget {
  const SitesAdminScreen({super.key});
  @override
  State<SitesAdminScreen> createState() => _SitesAdminScreenState();
}

class _SitesAdminScreenState extends State<SitesAdminScreen> {
  List<AdminSite> _sites = [];
  bool _loading = true, _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _form;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { _sites = await AdminDataService.getSites(); setState(() {}); }
    catch (e) { _snack('$e', error: true); }
    finally { setState(() => _loading = false); }
  }

  void _startAdd() {
    _form = {
      'id': '', 'name_en': '', 'name_am': '', 'description': '',
      'info': 'Open Hours: 8:30 AM – 5:30 PM.',
      'location': 'Gondar, Ethiopia',
      'photo': 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=600',
    };
    setState(() => _isEditing = true);
  }

  void _startEdit(AdminSite s) {
    _form = {
      'id': s.id, 'name_en': s.nameEn, 'name_am': s.nameAm,
      'description': s.description, 'info': s.info,
      'location': s.location, 'photo': s.photo,
    };
    setState(() => _isEditing = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    try {
      await AdminDataService.saveSite(AdminSite(
        id: _form['id'], nameEn: _form['name_en'], nameAm: _form['name_am'],
        description: _form['description'], info: _form['info'],
        location: _form['location'], photo: _form['photo'],
      ));
      setState(() => _isEditing = false);
      await _load(); _snack('Site saved');
    } catch (e) { _snack('$e', error: true); }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Site?'),
          content: const Text('This will permanently remove the historic site listing.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        )) ?? false;
    if (!ok) return;
    try { await AdminDataService.deleteSite(id); await _load(); _snack('Deleted'); }
    catch (e) { _snack('$e', error: true); }
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AdminColors.error : AdminColors.success,
      ));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('Sites & Historic Attractions', style: TextStyle(fontSize: 22,
                fontWeight: FontWeight.w800, color: AdminColors.textPrimary)),
            SizedBox(height: 4),
            Text('Curate World Heritage locations, castles, religious architecture.',
                style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
          ])),
          if (!_isEditing)
            ElevatedButton.icon(onPressed: _startAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Historic Site')),
        ]),
        const SizedBox(height: 6),
        const Divider(color: AdminColors.border),
        const SizedBox(height: 20),

        if (_loading) const Center(child: CircularProgressIndicator(color: AdminColors.gold))
        else if (_isEditing) _buildForm()
        else _buildGrid(),
      ]),
    );
  }

  Widget _buildForm() => Container(
    constraints: const BoxConstraints(maxWidth: 760),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border)),
    child: Form(key: _formKey, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.account_balance, color: AdminColors.gold, size: 20),
        SizedBox(width: 8),
        Text('Curator Castle & Sites Form', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w800, color: AdminColors.textPrimary)),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _f('Site Name (English)', 'name_en',
            hint: 'e.g. Fasil Ghebbi Royal Enclosure')),
        const SizedBox(width: 16),
        Expanded(child: _f('የስፍራው ስም (Amharic)', 'name_am',
            hint: 'ለምሳሌ፡ ፋሲል ግቢ')),
      ]),
      const SizedBox(height: 16),
      _f('Historical Description', 'description',
          hint: 'Write background, architectural heritage...', ml: 4),
      const SizedBox(height: 16),
      _f('Visiting & Entrance Info', 'info',
          hint: 'Open daily. Tour fee includes scout services.'),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _f('Location / Address', 'location',
            hint: 'City Center, Gondar, Ethiopia')),
        const SizedBox(width: 16),
        Expanded(child: _f('Photo URL', 'photo',
            hint: 'https://images.unsplash.com/...')),
      ]),
      const SizedBox(height: 24),
      const Divider(color: AdminColors.border),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        OutlinedButton(onPressed: () => setState(() => _isEditing = false),
            child: const Text('Discard')),
        const SizedBox(width: 12),
        ElevatedButton.icon(onPressed: _save,
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Save Landmark Site')),
      ]),
    ])),
  );

  Widget _f(String label, String key, {String hint = '', int ml = 1}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: AdminColors.textSecondary,
            letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _form[key]?.toString() ?? '',
          maxLines: ml,
          decoration: InputDecoration(hintText: hint),
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          onSaved: (v) => _form[key] = v ?? '',
        ),
      ]);

  Widget _buildGrid() {
    if (_sites.isEmpty) return const Center(
      child: Padding(padding: EdgeInsets.symmetric(vertical: 60),
        child: Text('No sites yet. Add one above.',
            style: TextStyle(color: AdminColors.textMuted, fontSize: 14))));

    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 900 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, crossAxisSpacing: 16,
            mainAxisSpacing: 16, childAspectRatio: 2.2),
        itemCount: _sites.length,
        itemBuilder: (_, i) {
          final s = _sites[i];
          return Container(
            decoration: BoxDecoration(color: AdminColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AdminColors.border)),
            clipBehavior: Clip.antiAlias,
            child: Row(children: [
              // Photo
              SizedBox(width: 160,
                child: s.photo.isNotEmpty
                    ? CachedNetworkImage(imageUrl: s.photo, fit: BoxFit.cover,
                        height: double.infinity,
                        errorWidget: (_, __, ___) => Container(
                            color: AdminColors.background,
                            child: const Icon(Icons.account_balance, size: 36,
                                color: AdminColors.textMuted)))
                    : Container(color: AdminColors.background,
                        child: const Icon(Icons.account_balance, size: 36,
                            color: AdminColors.textMuted)),
              ),
              // Content
              Expanded(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFAF1DF),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('HERITAGE SITE', style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w800,
                            color: Color(0xFF7C5800))),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text('${s.nameEn} (${s.nameAm})', style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: AdminColors.textPrimary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(s.description, style: const TextStyle(
                        fontSize: 11, color: AdminColors.textMuted, height: 1.4),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AdminColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AdminColors.border)),
                      child: Row(children: [
                        const Icon(Icons.info_outline, size: 12,
                            color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(child: Text(s.info, style: const TextStyle(
                            fontSize: 10, color: AdminColors.textSecondary),
                            maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 11,
                          color: AdminColors.gold),
                      const SizedBox(width: 4),
                      Text(s.location.split(',')[0], style: const TextStyle(
                          fontSize: 10, color: AdminColors.textMuted,
                          fontFamily: 'monospace')),
                    ]),
                    Row(children: [
                      GestureDetector(
                        onTap: () => _startEdit(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: AdminColors.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AdminColors.border)),
                          child: const Text('EDIT', style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _delete(s.id),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: Colors.red[50],
                              borderRadius: BorderRadius.circular(6)),
                          child: Icon(Icons.delete_outline, size: 14,
                              color: Colors.red[700]),
                        ),
                      ),
                    ]),
                  ]),
                ]),
              )),
            ]),
          );
        },
      );
    });
  }
}
