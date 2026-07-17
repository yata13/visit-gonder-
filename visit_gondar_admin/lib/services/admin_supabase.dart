// ═══════════════════════════════════════════════════════════════
//  AdminSupabase — single door to Supabase for the whole admin.
//  Reads the URL + anon key from .env (copy .env.example → .env).
//  Use `AdminSupabase.db` everywhere instead of creating clients.
// ═══════════════════════════════════════════════════════════════
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdminSupabase {
  static SupabaseClient get db => Supabase.instance.client;

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url:     dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }

  static User?   get currentUser => db.auth.currentUser;
  static bool    get isLoggedIn  => currentUser != null;
  static Stream<AuthState> get authStream => db.auth.onAuthStateChange;

  // Admin sign in
  static Future<void> signIn(String email, String password) async {
    await db.auth.signInWithPassword(
        email: email, password: password);
  }

  // Admin sign out
  static Future<void> signOut() async => await db.auth.signOut();
}
