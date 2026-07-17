import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  // Single instance — use SupabaseService.client everywhere
  static SupabaseClient get client => Supabase.instance.client;

  // Initialize once in main.dart
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url:    dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }

  // Current logged-in user (null if not logged in)
  static User? get currentUser => client.auth.currentUser;
  static bool  get isLoggedIn  => currentUser != null;

  // Auth state stream — listen for login/logout changes
  static Stream<AuthState> get authStream => client.auth.onAuthStateChange;
}
