// ═══════════════════════════════════════════════════════════════
//  AuthService — sign up / sign in / sign out with Supabase Auth.
//  On sign-up it also creates a row in our `users` table so the
//  app has a profile (name, country, phone) to show.
// ═══════════════════════════════════════════════════════════════
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  final _auth = SupabaseService.client.auth;
  final _db   = SupabaseService.client;

  // ── SIGN UP ─────────────────────────────────────────────
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? country,
    String? phone,
  }) async {
    final res = await _auth.signUp(
      email:    email,
      password: password,
      data: {
        'full_name': fullName,
        if (country != null) 'country': country,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );

    // Create user profile in our users table
    if (res.user != null) {
      final row = {
        'id':        res.user!.id,
        'full_name': fullName,
        'language':  'en',
        if (country != null) 'country': country,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      };
      try {
        await _db.from('users').upsert(row);
      } on PostgrestException {
        // `country`/`phone` column not added yet — save without them.
        row.remove('country');
        row.remove('phone');
        await _db.from('users').upsert(row);
      }
    }
    return res;
  }

  // ── PROFILE ──────────────────────────────────────────────
  // Best-effort: name/phone/email for the signed-in user. Reads the
  // users table first, falls back to auth metadata. Never throws.
  Future<Map<String, String>> profile() async {
    final u = currentUser;
    if (u == null) return {};
    final meta = u.userMetadata ?? {};
    var name  = (meta['full_name'] ?? '').toString();
    var phone = (meta['phone'] ?? '').toString();
    try {
      final row = await _db
          .from('users')
          .select('full_name, phone')
          .eq('id', u.id)
          .maybeSingle();
      if (row != null) {
        if ((row['full_name'] ?? '').toString().isNotEmpty) {
          name = row['full_name'].toString();
        }
        if ((row['phone'] ?? '').toString().isNotEmpty) {
          phone = row['phone'].toString();
        }
      }
    } catch (_) {/* column/table may be missing — use metadata */}
    return {'name': name, 'phone': phone, 'email': u.email ?? ''};
  }

  // Save a phone number to the signed-in user's profile (used the first
  // time someone sends an SOS if they signed up before phone existed).
  Future<void> savePhone(String phone) async {
    final u = currentUser;
    if (u == null) return;
    try {
      await _auth.updateUser(UserAttributes(data: {'phone': phone}));
    } catch (_) {}
    try {
      await _db.from('users').upsert({'id': u.id, 'phone': phone});
    } catch (_) {}
  }

  // ── SIGN IN ─────────────────────────────────────────────
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithPassword(
      email:    email,
      password: password,
    );
  }

  // ── SIGN OUT ─────────────────────────────────────────────
  Future<void> signOut() async => await _auth.signOut();

  // ── RESET PASSWORD ───────────────────────────────────────
  Future<void> resetPassword(String email) async {
    await _auth.resetPasswordForEmail(email);
  }

  // ── CURRENT USER ─────────────────────────────────────────
  User? get currentUser => _auth.currentUser;
  bool  get isLoggedIn  => currentUser != null;

  // ── AUTH STATE STREAM ────────────────────────────────────
  Stream<AuthState> get authStream => _auth.onAuthStateChange;
}
