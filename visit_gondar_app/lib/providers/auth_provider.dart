import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

// Current auth state
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.authStream;
});

// Current user (null if not logged in)
final currentUserProvider = Provider<User?>((ref) {
  return SupabaseService.currentUser;
});

// Is user logged in?
final isLoggedInProvider = Provider<bool>((ref) {
  return SupabaseService.isLoggedIn;
});
