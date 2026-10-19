import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import '../services/realtime_alerts.dart';

// ═══════════════════════════════════════════════════════════════
//  GONDAR PASSPORT — check-in points, stories, trivia (migration
//  0010). Tourists collect a stamp at each checkpoint by entering
//  the code printed under its QR sign; the server validates it
//  through the passport_check_in() RPC, never the client.
// ═══════════════════════════════════════════════════════════════

/// Active checkpoints, in the order the admin set.
final passportCheckpointsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  // Reload as soon as the admin adds or edits a checkpoint.
  final live = RealtimeAlerts.changes
      .where((t) => t == 'passport_checkpoints')
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(live.cancel);
  final rows = await Supabase.instance.client
      .from('passport_checkpoints')
      .select()
      .eq('is_active', true)
      .order('sort_order')
      .order('created_at');
  return List<Map<String, dynamic>>.from(rows);
});

/// The signed-in visitor's check-ins: checkpoint id → time.
final myCheckinsProvider =
    FutureProvider.autoDispose<Map<String, DateTime>>((ref) async {
  ref.watch(authStateProvider); // refresh on sign in / out
  final db = Supabase.instance.client;
  final user = db.auth.currentUser;
  if (user == null) return {};
  final rows = await db
      .from('passport_checkins')
      .select('checkpoint_id, checked_in_at')
      .eq('user_id', user.id);
  return {
    for (final r in rows)
      r['checkpoint_id'].toString():
          DateTime.tryParse((r['checked_in_at'] ?? '') as String) ??
              DateTime.now(),
  };
});

/// Stories unlocked at one checkpoint.
final passportStoriesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, checkpointId) async {
  final rows = await Supabase.instance.client
      .from('passport_stories')
      .select()
      .eq('checkpoint_id', checkpointId)
      .eq('is_active', true)
      .order('sort_order');
  return List<Map<String, dynamic>>.from(rows);
});

/// Trivia questions for one checkpoint.
final passportTriviaProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, checkpointId) async {
  final rows = await Supabase.instance.client
      .from('passport_trivia')
      .select()
      .eq('checkpoint_id', checkpointId)
      .eq('is_active', true);
  return List<Map<String, dynamic>>.from(rows);
});

/// Progress summary used by Home, Passport and Me.
class PassportProgress {
  final int stamps, total, points;
  final Map<String, dynamic>? next; // first checkpoint not yet stamped
  const PassportProgress(this.stamps, this.total, this.points, this.next);
  static const empty = PassportProgress(0, 0, 0, null);
}

final passportProgressProvider =
    Provider.autoDispose<PassportProgress>((ref) {
  final cps = ref.watch(passportCheckpointsProvider).valueOrNull ?? const [];
  final mine = ref.watch(myCheckinsProvider).valueOrNull ?? const {};
  var points = 0;
  Map<String, dynamic>? next;
  for (final c in cps) {
    if (mine.containsKey(c['id'].toString())) {
      points += ((c['points'] ?? 0) as num).toInt();
    } else {
      next ??= c;
    }
  }
  final stamps = cps.where((c) => mine.containsKey(c['id'].toString())).length;
  return PassportProgress(stamps, cps.length, points, next);
});

/// Result of a check-in attempt (from the passport_check_in RPC).
class CheckInResult {
  final String nameEn, nameAm;
  final int points;
  final bool alreadyChecked;
  const CheckInResult(this.nameEn, this.nameAm, this.points,
      this.alreadyChecked);
}

Future<CheckInResult> passportCheckIn(String code) async {
  final res = await Supabase.instance.client
      .rpc('passport_check_in', params: {'p_qr_token': code.trim()});
  final m = Map<String, dynamic>.from(res as Map);
  return CheckInResult(
    (m['name_en'] ?? '') as String,
    (m['name_am'] ?? '') as String,
    ((m['points'] ?? 0) as num).toInt(),
    m['already_checked'] == true,
  );
}
