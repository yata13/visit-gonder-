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

  // Initialize once in main.dart
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      initError = 'Could not load the .env file. Copy .env.example to .env '
          'and fill in SUPABASE_URL and SUPABASE_ANON_KEY. ($e)';
      rethrow;
    }
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (url.isEmpty || key.isEmpty || url.contains('YOUR-PROJECT-ID')) {
      initError = 'SUPABASE_URL / SUPABASE_ANON_KEY are missing in .env '
          '(still the example values?).';
      throw StateError(initError!);
    }
    try {
      await Supabase.initialize(url: url, anonKey: key);
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
