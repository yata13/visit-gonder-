import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_data_service.dart';

class EventsAdminScreen extends StatefulWidget {
  const EventsAdminScreen({super.key});
  @override
  State<EventsAdminScreen> createState() => _EventsAdminScreenState();
}

class _EventsAdminScreenState extends State<EventsAdminScreen> {
  List<AdminEvent> _events = [];
  bool _loading = true, _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _form;

  // Timket checklist
  final List<Map<String, dynamic>> _timket = [
    {'time': 'Jan 18 – 2:00 PM', 'task': 'Departure of holy Tabots from local parishes accompanied by ceremonial priests', 'done': true},
    {'time': 'Jan 18 – 6:00 PM', 'task': 'Congregation of Tabots arrives at Fasilides Bath', 'done': true},
    {'time': 'Jan 19 – 2:00 AM', 'task': 'Overnight prayer vigils, sacred chanting, and drumming by ecclesiastical choirs', 'done': true},
    {'time': 'Jan 19 – 7:00 AM', 'task': 'The Divine baptismal water spray blessing ceremony begins at Fasilides pool', 'done': false},
    {'time': 'Jan 20 – 9:00 AM', 'task': "St. Michael's feast parade returning the Tabots to sacred sanctuaries", 'done': false},
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { _events = await AdminDataService.getEvents(); setState(() {}); }
    catch (e) { _snack('$e', error: true); }
    finally { setState(() => _loading = false); }
  }

  void _startAdd() {
    _form = {
      'id': '', 'name': '', 'category': 'Religious Festival',
      'description': '', 'date': '',
      'photo': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600',
      'includes_timket': false,
    };
    setState(() => _isEditing = true);
  }

  void _startEdit(AdminEvent e) {
    _form = {
      'id': e.id, 'name': e.name, 'category': e.category,
      'description': e.description, 'date': e.date,
      'photo': e.photo, 'includes_timket': e.includesTimket,
    };
    setState(() => _isEditing = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    try {
      await AdminDataService.saveEvent(AdminEvent(
        id: _form['id'], name: _form['name'], category: _form['category'],
        description: _form['description'], date: _form['date'],
        photo: _form['photo'], includesTimket: _form['includes_timket'],
      ));
      setState(() => _isEditing = false);
      await _load(); _snack('Event saved');
    } catch (e) { _snack('$e', error: true); }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Event?'),
          content: const Text('Remove this event from the schedule?'),
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
    try { await AdminDataService.deleteEvent(id); await _load(); }
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
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Events & Festivals Scheduler', style: TextStyle(fontSize: 22,
                fontWeight: FontWeight.w800, color: AdminColors.textPrimary)),
            SizedBox(height: 4),
            Text('Post seasonal events, holidays, or organize Timket itinerary.',
                style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
          ])),
          if (!_isEditing)
            ElevatedButton.icon(onPressed: _startAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Schedule New Event')),
        ]),
        const SizedBox(height: 6),
        const Divider(color: AdminColors.border),
        const SizedBox(height: 20),

        if (_loading) const Center(child: CircularProgressIndicator(color: AdminColors.gold))
        else _buildBody(),
      ]),
    );
  }

  Widget _buildBody() {
    return LayoutBuilder(builder: (ctx, c) {
      final showSide = c.maxWidth > 900;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Main content
        Expanded(child: _isEditing ? _buildForm() : _buildGrid()),
        if (showSide) ...[
          const SizedBox(width: 20),
          SizedBox(width: 300, child: _timketPanel()),
        ],
      ]);
    });
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
        Icon(Icons.celebration, color: AdminColors.gold, size: 20),
        SizedBox(width: 8),
        Text('Event Posting Form', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w800, color: AdminColors.textPrimary)),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _f('Event Title', 'name',
            hint: 'e.g. Demera Bonfire Gathering')),
        const SizedBox(width: 16),
        Expanded(child: _dd('Category', 'category', [
          _o('Religious Festival', 'Religious Festival'),
          _o('National Holiday', 'National Holiday'),
          _o('Cultural Celebration', 'Cultural Celebration'),
          _o('Music & Art', 'Music & Art Showcase'),
        ])),
      ]),
      const SizedBox(height: 16),
      _f('Description & Timings', 'description',
          hint: 'Write beautiful details on what tourists can experience...', ml: 4),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _f('Occurrence Date (YYYY-MM-DD)', 'date',
            hint: '2027-01-18')),
        const SizedBox(width: 16),
        Expanded(child: _f('Banner Photo URL', 'photo',
            hint: 'https://images.unsplash.com/...')),
        const SizedBox(width: 16),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(children: [
            Checkbox(
              value: _form['includes_timket'] as bool,
              activeColor: AdminColors.gold,
              onChanged: (v) => setState(() => _form['includes_timket'] = v ?? false),
            ),
            const Expanded(child: Text('Tied to Timket?', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: AdminColors.textSecondary))),
          ]),
        )),
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
            label: const Text('Save Festival Event')),
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

  Widget _dd(String label, String key, List<DropdownMenuItem> items) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: AdminColors.textSecondary,
            letterSpacing: 0.5)),
        const SizedBox(height: 6),
        DropdownButtonFormField(value: _form[key], items: items,
            onChanged: (v) => setState(() => _form[key] = v),
            decoration: const InputDecoration()),
      ]);

  DropdownMenuItem _o(dynamic v, String l) =>
      DropdownMenuItem(value: v, child: Text(l, style: const TextStyle(fontSize: 13)));

  Widget _buildGrid() {
    if (_events.isEmpty) return const Center(
      child: Padding(padding: EdgeInsets.symmetric(vertical: 60),
        child: Text('No events scheduled. Add one above.',
            style: TextStyle(color: AdminColors.textMuted, fontSize: 14))));

    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 700 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, crossAxisSpacing: 16,
            mainAxisSpacing: 16, childAspectRatio: 0.85),
        itemCount: _events.length,
        itemBuilder: (_, i) {
          final ev = _events[i];
          return Container(
            decoration: BoxDecoration(color: AdminColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AdminColors.border)),
            child: Column(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Stack(children: [
                  SizedBox(height: 140, width: double.infinity,
                    child: ev.photo.isNotEmpty
                        ? CachedNetworkImage(imageUrl: ev.photo, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                                color: AdminColors.background))
                        : Container(color: AdminColors.background),
                  ),
                  if (ev.includesTimket)
                    Positioned(top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AdminColors.bronze,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AdminColors.gold)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.auto_awesome, size: 10, color: AdminColors.gold),
                          SizedBox(width: 4),
                          Text('TIMKET SPECIAL', style: TextStyle(fontSize: 9,
                              fontWeight: FontWeight.w800, color: AdminColors.gold,
                              fontFamily: 'monospace')),
                        ]),
                      ),
                    ),
                ]),
              ),
              Expanded(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(ev.category.toUpperCase(), style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: AdminColors.gold, fontFamily: 'monospace')),
                      Text(ev.date, style: const TextStyle(fontSize: 10,
                          color: AdminColors.textMuted, fontFamily: 'monospace')),
                    ]),
                    const SizedBox(height: 6),
                    Text(ev.name, style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700, color: AdminColors.textPrimary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(ev.description, style: const TextStyle(
                        fontSize: 11, color: AdminColors.textMuted, height: 1.4),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    GestureDetector(onTap: () => _startEdit(ev),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AdminColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AdminColors.border)),
                        child: const Text('EDIT CONFIG', style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: AdminColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: () => _delete(ev.id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.red[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200)),
                        child: Icon(Icons.delete_outline, size: 14,
                            color: Colors.red[700]),
                      ),
                    ),
                  ]),
                ]),
              )),
            ]),
          );
        },
      );
    });
  }

  // Timket side panel
  Widget _timketPanel() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.auto_awesome, color: AdminColors.gold, size: 16),
        SizedBox(width: 8),
        Text('TIMKET LITURGY CHECKLIST', style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w800, color: AdminColors.textPrimary,
            letterSpacing: 0.5)),
      ]),
      const SizedBox(height: 4),
      const Text('3-day sacred festival pipeline. Updates live for tourists.',
          style: TextStyle(fontSize: 11, color: AdminColors.textMuted, height: 1.4)),
      const SizedBox(height: 14),
      ..._timket.asMap().entries.map((e) {
        final item = e.value;
        final done = item['done'] as bool;
        return GestureDetector(
          onTap: () => setState(() => _timket[e.key]['done'] = !done),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: done ? AdminColors.background : const Color(0xFFFAF1DF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: done ? AdminColors.border : AdminColors.gold.withOpacity(0.4)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 16, height: 16, margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: done ? AdminColors.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AdminColors.gold),
                ),
                child: done ? const Icon(Icons.check, size: 10,
                    color: AdminColors.bronze) : null,
              ),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item['time'], style: const TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w700, color: Color(0xFF7C5800),
                    fontFamily: 'monospace', letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(item['task'], style: TextStyle(fontSize: 11,
                    color: done ? AdminColors.textMuted : AdminColors.textPrimary,
                    decoration: done ? TextDecoration.lineThrough : null,
                    height: 1.4)),
              ])),
            ]),
          ),
        );
      }),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.amber[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200)),
        child: const Center(child: Text('Timket schedule syncs to tourist widgets.',
            style: TextStyle(fontSize: 10, color: Color(0xFF7C5800),
                fontFamily: 'monospace'), textAlign: TextAlign.center)),
      ),
    ]),
  );
}
