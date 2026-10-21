import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/driver_api.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ═══════════════════════════════════════════════════════════════
//  Become a Visit Gondar driver (or edit your details). The office
//  checks the details and approves the driver in the admin site.
// ═══════════════════════════════════════════════════════════════
class ApplyScreen extends StatefulWidget {
  /// The current row when editing; null for a new application.
  final Map<String, dynamic>? existing;

  /// Called with the saved row (new applications). When editing, the
  /// screen is a pushed page and pops with the row instead.
  final ValueChanged<Map<String, dynamic>>? onSaved;

  const ApplyScreen({super.key, this.existing, this.onSaved});
  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _initial('full_name'));
  late final _phone = TextEditingController(text: _initial('phone'));
  late final _plate = TextEditingController(text: _initial('plate'));
  late final _desc = TextEditingController(text: _initial('vehicle_desc'));
  late String _type = (widget.existing?['vehicle_type'] as String?) ?? 'bajaj';
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  String _initial(String key) {
    final v = widget.existing?[key];
    if (v != null) return '$v';
    // New application: start from what they typed when signing up.
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
    return key == 'full_name' || key == 'phone' ? '${meta[key] ?? ''}' : '';
  }

  /// A new vehicle or plate has to be checked by the office again.
  bool get _needsRecheck {
    final e = widget.existing;
    if (e == null || e['status'] != 'approved') return false;
    return e['vehicle_type'] != _type ||
        '${e['plate']}'.toUpperCase() != _plate.text.trim().toUpperCase();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _plate.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final row = await DriverApi.apply(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        vehicleType: _type,
        plate: _plate.text.trim(),
        vehicleDesc: _desc.text.trim(),
      );
      if (!mounted) return;
      if (_editing) {
        Navigator.pop(context, row);
      } else {
        widget.onSaved?.call(row);
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'My details' : 'Become a driver'),
        actions: [
          if (!_editing)
            TextButton(onPressed: signOut, child: const Text('Sign out')),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (!_editing) ...[
                const FadeIn(
                  child: Text(
                    'Tell us about you and your vehicle. The Visit Gondar office checks '
                    'your details and approves you — then tourists can book you.',
                    style: TextStyle(fontSize: 15.5, height: 1.45, color: VG.muted),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const _Label('Your vehicle'),
              Row(children: [
                Expanded(child: _VehicleChoice(
                  type: 'bajaj',
                  selected: _type == 'bajaj',
                  onTap: () => setState(() => _type = 'bajaj'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _VehicleChoice(
                  type: 'taxi',
                  selected: _type == 'taxi',
                  onTap: () => setState(() => _type = 'taxi'),
                )),
              ]),
              const SizedBox(height: 22),
              const _Label('About you'),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) => (v ?? '').trim().length < 2 ? 'Type your full name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '09… or +251…',
                  prefixIcon: Icon(Icons.phone_rounded),
                  helperText: 'Riders call you on this number.',
                ),
                validator: (v) => RegExp(r'\d').allMatches(v ?? '').length < 9
                    ? 'Type a phone number riders can call'
                    : null,
              ),
              const SizedBox(height: 22),
              const _Label('Vehicle details'),
              TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Plate number',
                  hintText: 'e.g. 3-12345 AM',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Type the plate number' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _desc,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Colour and model (optional)',
                  hintText: 'e.g. Blue bajaj, TVS King',
                  prefixIcon: Icon(Icons.palette_outlined),
                  helperText: 'Helps riders find you at the pickup point.',
                ),
              ),
              if (_needsRecheck)
                Container(
                  margin: const EdgeInsets.only(top: 18),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VG.goldTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded, color: VG.brown),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'A new vehicle or plate needs the office to approve you again.',
                        style: TextStyle(color: VG.ink, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!,
                      style: const TextStyle(color: VG.danger, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_editing ? 'Save changes' : 'Send application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 12.5, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: VG.muted)),
      );
}

class _VehicleChoice extends StatelessWidget {
  final String type;
  final bool selected;
  final VoidCallback onTap;
  const _VehicleChoice({required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: selected ? VG.brown : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? VG.brown : VG.line, width: 1.5),
              boxShadow: selected
                  ? [BoxShadow(color: VG.brown.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))]
                  : const [],
            ),
            child: Column(children: [
              Icon(vehicleIcon(type), size: 38, color: selected ? VG.gold : VG.brown),
              const SizedBox(height: 6),
              Text(vehicleName(type),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : VG.ink)),
            ]),
          ),
        ),
      );
}
