import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'apply_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  Waiting for the Visit Gondar office to approve the driver (or
//  the account is paused). The gate watches the row live, so this
//  page turns into the home screen by itself once approved.
// ═══════════════════════════════════════════════════════════════
class PendingScreen extends StatelessWidget {
  final Map<String, dynamic> profile;
  final ValueChanged<Map<String, dynamic>> onProfile;
  const PendingScreen({super.key, required this.profile, required this.onProfile});

  Future<void> _edit(BuildContext context) async {
    final row = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ApplyScreen(existing: profile)),
    );
    if (row != null) onProfile(row);
  }

  @override
  Widget build(BuildContext context) {
    final paused = profile['status'] == 'suspended';
    final type = profile['vehicle_type'] as String?;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VG Driver'),
        actions: [TextButton(onPressed: signOut, child: const Text('Sign out'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
          children: [
            FadeIn(
              child: Center(
                child: BrandBadge(
                  icon: paused ? Icons.pause_circle_outline_rounded : Icons.hourglass_top_rounded,
                  color: paused ? VG.danger : VG.brown,
                ),
              ),
            ),
            const SizedBox(height: 22),
            FadeIn(
              delay: 80,
              child: Text(
                paused ? 'Your account is paused' : 'Application received',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: VG.ink),
              ),
            ),
            const SizedBox(height: 10),
            FadeIn(
              delay: 140,
              child: Text(
                paused
                    ? 'The Visit Gondar office has paused your driver account. '
                      'Please call or visit the office to talk about it.'
                    : 'The Visit Gondar office checks your details and approves you, '
                      'usually within a day. This page opens the app by itself '
                      'when you are approved.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15.5, height: 1.45, color: VG.muted),
              ),
            ),
            if (!paused) ...[
              const SizedBox(height: 16),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                LiveDot(color: VG.gold),
                SizedBox(width: 8),
                Text('Waiting for approval',
                    style: TextStyle(fontWeight: FontWeight.w700, color: VG.brown)),
              ]),
            ],
            const SizedBox(height: 24),
            FadeIn(
              delay: 200,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                  child: Column(children: [
                    InfoRow(icon: Icons.badge_outlined, label: 'Name', value: '${profile['full_name'] ?? ''}'),
                    InfoRow(icon: Icons.phone_rounded, label: 'Phone', value: '${profile['phone'] ?? ''}'),
                    InfoRow(icon: vehicleIcon(type), label: 'Vehicle', value: vehicleName(type)),
                    InfoRow(icon: Icons.pin_outlined, label: 'Plate', value: '${profile['plate'] ?? ''}'),
                    if ((profile['vehicle_desc'] ?? '').toString().isNotEmpty)
                      InfoRow(icon: Icons.palette_outlined, label: 'Looks like', value: '${profile['vehicle_desc']}'),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit my details'),
            ),
          ],
        ),
      ),
    );
  }
}
