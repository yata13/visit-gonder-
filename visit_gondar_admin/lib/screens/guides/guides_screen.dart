import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_data_service.dart';

class GuidesAdminScreen extends StatefulWidget {
  const GuidesAdminScreen({super.key});
  @override
  State<GuidesAdminScreen> createState() => _GuidesAdminScreenState();
}

class _GuidesAdminScreenState extends State<GuidesAdminScreen> {
  List<AdminGuide> _guides = [];
  bool _loading = true, _isEditing = false;
  String _search = '';
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _form;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _guides = await AdminDataService.getGuides(); setState(() {});
    } catch (e) { _snack('$e', error: true); }
    finally { setState(() => _loading = false); }
  }

  void _startAdd() {
    _form = {
      'id': '', 'name': '', 'specialty': '',
      'photo': 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=600&auto=format&fit=crop&q=60',
      'languages': 'English, Amharic',
      'price': 30.0, 'license_status': 'licensed', 'publish_status': 'published',
    };
    setState(() => _isEditing = true);
  }

  void _startEdit(AdminGuide g) {
    _form = {
      'id': g.id, 'name': g.name, 'specialty': g.specialty,
      'photo': g.photo, 'languages': g.languages.join(', '),
      'price': g.price, 'license_status': g.licenseStatus,
      'publish_status': g.publishStatus,
    };
    setState(() => _isEditing = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    try {
      await AdminDataService.saveGuide(AdminGuide(
        id: _form['id'], name: _form['name'], specialty: _form['specialty'],
        photo: _form['photo'],
        languages: (_form['languages'] as String)
            .split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        price: (_form['price'] as num).toDouble(),
        licenseStatus: _form['license_status'],
        publishStatus: _form['publish_status'],
      ));
      setState(() => _isEditing = false);
      await _load();
      _snack('Guide saved');
    } catch (e) { _snack('$e', error: true); }
  }

  Future<void> _delete(String id) async {
    final ok = await _confirm('Delete this guide profile?');
    if (!ok) return;
    try { await AdminDataService.deleteGuide(id); await _load(); _snack('Deleted'); }
    catch (e) { _snack('$e', error: true); }
  }

  Future<void> _toggleLicense(AdminGuide g) async {
    final next = g.licenseStatus == 'licensed' ? 'unlicensed' : 'licensed';
    await AdminDataService.saveGuide(AdminGuide(
      id: g.id, name: g.name, specialty: g.specialty, photo: g.photo,
      languages: g.languages, price: g.price,
      licenseStatus: next, publishStatus: g.publishStatus,
    ));
    await _load();
  }

  Future<void> _togglePublish(AdminGuide g) async {
    final next = g.publishStatus == 'published' ? 'hidden' : 'published';
    await AdminDataService.saveGuide(AdminGuide(
      id: g.id, name: g.name, specialty: g.specialty, photo: g.photo,
      languages: g.languages, price: g.price,
      licenseStatus: g.licenseStatus, publishStatus: next,
    ));
    await _load();
  }

  Future<bool> _confirm(String msg) async =>
      await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(title: const Text('Confirm'),
          content: Text(msg), actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ])) ?? false;

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AdminColors.error : AdminColors.success,
      ));

  List<AdminGuide> get _filtered => _guides.where((g) =>
    g.name.toLowerCase().contains(_search.toLowerCase()) ||
    g.specialty.toLowerCase().contains(_search.toLowerCase())
  ).toList();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tour Guides Registry', style: TextStyle(fontSize: 22,
                fontWeight: FontWeight.w800, color: AdminColors.textPrimary)),
            SizedBox(height: 4),
            Text('Verify license badges, track pricing, manage languages.',
                style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
          ])),
          if (!_isEditing)
            ElevatedButton.icon(onPressed: _startAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add New Guide')),
        ]),
        const SizedBox(height: 6),
        const Divider(color: AdminColors.border),
        const SizedBox(height: 20),

        if (_loading) const Center(child: CircularProgressIndicator(color: AdminColors.gold))
        else if (_isEditing) _buildForm()
        else _buildList(),
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
        Icon(Icons.person_pin, color: AdminColors.gold, size: 20),
        SizedBox(width: 8),
        Text('Guide Entry Form', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w800, color: AdminColors.textPrimary)),
      ]),
      const SizedBox(height: 20),

      Row(children: [
        Expanded(child: _f('Full Name', 'name', hint: 'e.g. Yohannes Weldegerima')),
        const SizedBox(width: 16),
        Expanded(child: _f('Languages (comma separated)', 'languages',
            hint: 'English, French, Amharic')),
      ]),
      const SizedBox(height: 16),
      _f('Specialization', 'specialty',
          hint: 'e.g. Imperial castle history, Simien trekking'),
      const SizedBox(height: 16),

      Row(children: [
        Expanded(child: _nf('Daily Hiring Cost (USD)', 'price')),
        const SizedBox(width: 16),
        Expanded(child: _dd('License Status', 'license_status', [
          _o('licensed', 'Licensed (Official badge)'),
          _o('unlicensed', 'Unlicensed / Pending'),
        ])),
        const SizedBox(width: 16),
        Expanded(child: _dd('Listing Status', 'publish_status', [
          _o('published', 'Published Live'),
          _o('pending', 'Awaiting Review'),
          _o('hidden', 'Hidden'),
        ])),
      ]),
      const SizedBox(height: 16),
      _f('Profile Photo URL', 'photo', hint: 'https://images.unsplash.com/...'),
      const SizedBox(height: 24),
      const Divider(color: AdminColors.border),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        OutlinedButton(onPressed: () => setState(() => _isEditing = false),
            child: const Text('Discard')),
        const SizedBox(width: 12),
        ElevatedButton.icon(onPressed: _save,
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Save Guide')),
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

  Widget _nf(String label, String key) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: AdminColors.textSecondary,
            letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _form[key]?.toString() ?? '0',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '\$ '),
          onSaved: (v) => _form[key] = double.tryParse(v ?? '0') ?? 0.0,
        ),
      ]);

  Widget _dd(String label, String key, List<DropdownMenuItem> items) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: AdminColors.textSecondary,
            letterSpacing: 0.5)),
        const SizedBox(height: 6),
        DropdownButtonFormField(
          value: _form[key], items: items,
          onChanged: (v) => setState(() => _form[key] = v),
          decoration: const InputDecoration(),
        ),
      ]);

  DropdownMenuItem _o(dynamic v, String l) =>
      DropdownMenuItem(value: v, child: Text(l, style: const TextStyle(fontSize: 13)));

  Widget _buildList() => Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
    SizedBox(width: 380, child: TextField(
      onChanged: (v) => setState(() => _search = v),
      decoration: const InputDecoration(hintText: 'Search guides, specialties...',
          prefixIcon: Icon(Icons.search, size: 18, color: AdminColors.textMuted)),
    )),
    const SizedBox(height: 20),
    if (_filtered.isEmpty)
      const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 60),
          child: Text('No guides found.', style: TextStyle(color: AdminColors.textMuted))))
    else
      LayoutBuilder(builder: (ctx, c) {
        final cols = c.maxWidth > 1000 ? 3 : c.maxWidth > 650 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, crossAxisSpacing: 16,
              mainAxisSpacing: 16, childAspectRatio: 0.7),
          itemCount: _filtered.length,
          itemBuilder: (_, i) => _GuideCard(
            guide: _filtered[i],
            onEdit: () => _startEdit(_filtered[i]),
            onDelete: () => _delete(_filtered[i].id),
            onToggleLicense: () => _toggleLicense(_filtered[i]),
            onTogglePublish: () => _togglePublish(_filtered[i]),
          ),
        );
      }),
  ]);
}

class _GuideCard extends StatelessWidget {
  final AdminGuide guide;
  final VoidCallback onEdit, onDelete, onToggleLicense, onTogglePublish;
  const _GuideCard({required this.guide, required this.onEdit,
      required this.onDelete, required this.onToggleLicense,
      required this.onTogglePublish});

  @override
  Widget build(BuildContext context) {
    final isLicensed  = guide.licenseStatus == 'licensed';
    final isPublished = guide.publishStatus == 'published';
    return Container(
      decoration: BoxDecoration(color: AdminColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AdminColors.border)),
      child: Column(children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: Stack(children: [
            SizedBox(height: 160, width: double.infinity,
              child: guide.photo.isNotEmpty
                  ? CachedNetworkImage(imageUrl: guide.photo, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                          color: AdminColors.background,
                          child: const Icon(Icons.person, size: 40,
                              color: AdminColors.textMuted)))
                  : Container(color: AdminColors.background,
                      child: const Icon(Icons.person, size: 40,
                          color: AdminColors.textMuted)),
            ),
            Positioned(top: 10, right: 10, child: Column(
                crossAxisAlignment: CrossAxisAlignment.end, children: [
              _badge(guide.publishStatus,
                  isPublished ? Colors.green[800]! : AdminColors.textMuted,
                  isPublished ? Colors.green[50]! : Colors.grey[100]!),
              if (isLicensed) ...[
                const SizedBox(height: 4),
                _badge('LICENSED', Colors.blue[800]!, Colors.blue[50]!),
              ],
            ])),
          ]),
        ),
        Expanded(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('DAILY: \$${guide.price.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace',
                      color: AdminColors.textMuted)),
            ]),
            const SizedBox(height: 6),
            Text(guide.name, style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w800, color: AdminColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Specializes in: ${guide.specialty}',
                style: const TextStyle(fontSize: 11, color: AdminColors.textMuted),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Wrap(spacing: 4, runSpacing: 4, children: [
              const Icon(Icons.translate, size: 12, color: AdminColors.gold),
              ...guide.languages.map((l) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AdminColors.background,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(l.toUpperCase(), style: const TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    fontFamily: 'monospace', color: AdminColors.textSecondary)),
              )),
            ]),
          ]),
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(color: AdminColors.background,
              border: Border(top: BorderSide(color: AdminColors.border)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14))),
          child: Row(children: [
            GestureDetector(onTap: onToggleLicense,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(color: AdminColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AdminColors.border)),
                child: Text(isLicensed ? 'REVOKE' : 'VERIFY',
                    style: const TextStyle(fontSize: 9,
                        fontWeight: FontWeight.w700, fontFamily: 'monospace',
                        color: AdminColors.textSecondary)),
              ),
            ),
            const Spacer(),
            GestureDetector(onTap: onTogglePublish,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AdminColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AdminColors.border)),
                child: Icon(isPublished ? Icons.visibility_off : Icons.visibility,
                    size: 13, color: AdminColors.textMuted),
              ),
            ),
            const SizedBox(width: 6),
            _iBtn(Icons.edit_outlined, Colors.blue[700]!, Colors.blue[50]!, onEdit),
            const SizedBox(width: 6),
            _iBtn(Icons.delete_outline, Colors.red[700]!, Colors.red[50]!, onDelete),
          ]),
        ),
      ]),
    );
  }

  Widget _badge(String t, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
    child: Text(t.toUpperCase(), style: TextStyle(fontSize: 9,
        fontWeight: FontWeight.w700, color: fg, fontFamily: 'monospace')),
  );

  Widget _iBtn(IconData icon, Color fg, Color bg, VoidCallback onTap) =>
      GestureDetector(onTap: onTap,
        child: Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 14, color: fg)));
}
