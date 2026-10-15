import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  // Single instance — use SupabaseService.client everywhere
  static SupabaseClient get client => Supabase.instance.client;

  // Why startup failed (missing .env, bad URL, …). null = connected fine.
  // main.dart keeps the app running anyway; the login screen shows this
  // so the real problem is visible instead of "Something went wrong".
  static String? initError;
  static bool get isReady => initError == null;

  // Built-in project values, used when .env is missing or empty (e.g. a
  // phone build made without the .env file). A publishable key is meant
  // to ship inside client apps — RLS protects the data, not this key.
  static const _defaultUrl = 'https://cukfcclewuqaebnhhamo.supabase.co';
  static const _defaultKey = 'sb_publishable_ujn44Z6NbBDL1vJG4xq7wA_2CEuyoIH';

  // Initialize once in main.dart
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // No .env → fall back to the built-in values below.
    }
    var url = _env('SUPABASE_URL', _defaultUrl);
    var key = _env('SUPABASE_ANON_KEY', _defaultKey);
    if (url.contains('YOUR-PROJECT-ID')) url = _defaultUrl;
    if (key.startsWith('your-')) key = _defaultKey;
    try {
      await Supabase.initialize(url: url, publishableKey: key);
    } catch (e) {
      initError = 'Supabase failed to start: $e';
      rethrow;
    }
  }

  // Demo account pre-filled on the login screen. Override in .env with
  // DEMO_EMAIL / DEMO_PASSWORD; create it with supabase/seed_demo_user.sql.
  static String get demoEmail    => _env('DEMO_EMAIL', 'demo@visitgondar.com');
  static String get demoPassword => _env('DEMO_PASSWORD', 'Demo1234!');

  static String _env(String name, String fallback) {
    if (!dotenv.isInitialized) return fallback;
    final v = dotenv.env[name];
    return (v == null || v.isEmpty) ? fallback : v;
  }

  // Current logged-in user (null if not logged in)
  static User? get currentUser => client.auth.currentUser;
  static bool  get isLoggedIn  => currentUser != null;

  // Auth state stream — listen for login/logout changes
  static Stream<AuthState> get authStream => client.auth.onAuthStateChange;
}
