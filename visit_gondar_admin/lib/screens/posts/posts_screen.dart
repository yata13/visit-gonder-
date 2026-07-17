import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_supabase.dart';

// ═══════════════════════════════════════════════════════════════
//  NEWS FEED — Facebook-style posts shown on the app home page.
//  Requires the `posts` table (run POSTS_TABLE.sql once).
// ═══════════════════════════════════════════════════════════════
class PostsAdminScreen extends StatefulWidget {
  const PostsAdminScreen({super.key});
  @override
  State<PostsAdminScreen> createState() => _PostsAdminScreenState();
}

class _PostsAdminScreenState extends State<PostsAdminScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _tableMissing = false;
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _titleAmCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _bodyAmCtrl = TextEditingController();
  final _photoCtrl = TextEditingController();
  String _category = 'news';
  bool _saving = false;
  String? _successMsg;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _tableMissing = false; });
    try {
      final data = await AdminSupabase.db
          .from('posts')
          .select()
          .order('created_at', ascending: false);
      _posts = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if ('$e'.contains('posts')) _tableMissing = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminSupabase.db.from('posts').insert({
        'title': _titleCtrl.text.trim(),
        'title_am': _titleAmCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'body_am': _bodyAmCtrl.text.trim(),
        'photo': _photoCtrl.text.trim(),
        'category': _category,
      });
      _titleCtrl.clear(); _titleAmCtrl.clear();
      _bodyCtrl.clear(); _bodyAmCtrl.clear(); _photoCtrl.clear();
      setState(() => _successMsg =
          'Post published! It is live on the app home feed now.');
      Future.delayed(const Duration(seconds: 4),
          () { if (mounted) setState(() => _successMsg = null); });
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
          title: const Text('Delete this post?'),
          content: const Text(
              'It will disappear from the app home feed immediately.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        )) ?? false;
    if (!ok) return;
    try {
      await AdminSupabase.db.from('posts').delete().eq('id', id);
      await _load();
    } catch (e) { _snack('$e', error: true); }
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
        const Text('Gondar News Feed', style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w800, color: AdminColors.textPrimary)),
        const SizedBox(height: 4),
        const Text(
            'Post city news like a blog — every post appears instantly on the app home page ("Gondar Today").',
            style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
        const SizedBox(height: 6),
        const Divider(color: AdminColors.border),
        const SizedBox(height: 20),

        if (_tableMissing)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminColors.warningBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'The posts table does not exist yet. Run POSTS_TABLE.sql '
              '(in the visit_gondar_admin folder) once in the Supabase SQL Editor, then reload this page.',
              style: TextStyle(fontSize: 13, color: AdminColors.textPrimary,
                  height: 1.5),
            ),
          )
        else
          LayoutBuilder(builder: (ctx, c) {
            final side = c.maxWidth > 980;
            if (side) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                SizedBox(width: 400, child: _composer()),
                const SizedBox(width: 20),
                Expanded(child: _feedPanel()),
              ]);
            }
            return Column(children: [
              _composer(), const SizedBox(height: 20), _feedPanel()]);
          }),
      ]),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 11,
        fontWeight: FontWeight.w700, color: AdminColors.textSecondary,
        letterSpacing: 0.5)),
  );

  Widget _composer() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border)),
    child: Form(key: _formKey, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.post_add, color: AdminColors.gold, size: 18),
        SizedBox(width: 8),
        Text('NEW POST', style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w800, color: AdminColors.textPrimary,
            letterSpacing: 0.5)),
      ]),
      const SizedBox(height: 16),

      if (_successMsg != null) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(
                  color: Colors.green.shade500, width: 3))),
          child: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(_successMsg!, style: const TextStyle(
                fontSize: 12, color: Colors.green))),
          ]),
        ),
        const SizedBox(height: 14),
      ],

      _label('CATEGORY'),
      Row(children: [
        _catBtn('news', '📰 NEWS'),
        const SizedBox(width: 8),
        _catBtn('event', '🎉 EVENT'),
        const SizedBox(width: 8),
        _catBtn('culture', '🏛 CULTURE'),
      ]),
      const SizedBox(height: 14),

      _label('TITLE (ENGLISH)'),
      TextFormField(
        controller: _titleCtrl,
        decoration: const InputDecoration(
            hintText: 'e.g. New lighting at Fasil Ghebbi unveiled'),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      _label('ቲትል (አማርኛ) — optional'),
      TextFormField(
        controller: _titleAmCtrl,
        decoration: const InputDecoration(hintText: 'የአማርኛ ርዕስ'),
      ),
      const SizedBox(height: 12),

      _label('BODY (ENGLISH)'),
      TextFormField(
        controller: _bodyCtrl, maxLines: 4,
        decoration: const InputDecoration(
            hintText: 'Write the news like a blog post…'),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      _label('ይዘት (አማርኛ) — optional'),
      TextFormField(
        controller: _bodyAmCtrl, maxLines: 3,
        decoration: const InputDecoration(hintText: 'የአማርኛ ይዘት'),
      ),
      const SizedBox(height: 12),

      _label('PHOTO URL — optional'),
      TextFormField(
        controller: _photoCtrl,
        decoration: const InputDecoration(
            hintText: 'https://… direct link ending in .jpg / .png'),
      ),
      const SizedBox(height: 16),

      SizedBox(
        width: double.infinity, height: 46,
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _publish,
          icon: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.publish, size: 16),
          label: const Text('PUBLISH TO APP HOME'),
        ),
      ),
    ])),
  );

  Widget _catBtn(String val, String label) {
    final selected = _category == val;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _category = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: selected ? const Color(0xFFFAF1DF) : AdminColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? AdminColors.gold : AdminColors.border)),
        child: Center(child: Text(label, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: selected
                ? AdminColors.textPrimary : AdminColors.textMuted))),
      ),
    ));
  }

  Widget _feedPanel() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.dynamic_feed,
            color: AdminColors.gold, size: 16),
        const SizedBox(width: 8),
        Text('PUBLISHED POSTS (${_posts.length})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                color: AdminColors.textPrimary, letterSpacing: 0.5)),
      ]),
      const Divider(color: AdminColors.border, height: 20),

      if (_loading)
        const Center(child: CircularProgressIndicator(
            color: AdminColors.gold))
      else if (_posts.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('No posts yet — write the first one!',
              style: TextStyle(color: AdminColors.textMuted))))
      else
        ..._posts.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AdminColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminColors.border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (((p['photo'] ?? '') as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(p['photo'], width: 56, height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 56, height: 56,
                          color: AdminColors.border,
                          child: const Icon(Icons.broken_image_outlined,
                              size: 18, color: AdminColors.textMuted))),
                ),
              ),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: AdminColors.goldLight,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(((p['category'] ?? 'news') as String)
                          .toUpperCase(),
                      style: const TextStyle(fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.bronze,
                          fontFamily: 'monospace')),
                ),
                const SizedBox(width: 8),
                Text(_formatDate(p['created_at'] ?? ''),
                    style: const TextStyle(fontSize: 10,
                        color: AdminColors.textMuted,
                        fontFamily: 'monospace')),
              ]),
              const SizedBox(height: 4),
              Text((p['title'] ?? '') as String,
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary)),
              const SizedBox(height: 2),
              Text((p['body'] ?? '') as String,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11,
                      color: AdminColors.textSecondary, height: 1.4)),
            ])),
            GestureDetector(
              onTap: () => _delete(p['id'].toString()),
              child: const Padding(padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline, size: 16,
                    color: AdminColors.textMuted)),
            ),
          ]),
        )),
    ]),
  );

  String _formatDate(String iso) {
    try {
      return DateFormat('d MMM, HH:mm')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) { return ''; }
  }
}
