// ═══════════════════════════════════════════════════════════════
//  VISIT GONDAR — ADMIN DASHBOARD (Flutter Web)
//  Entry point. Connects to the same Supabase project as the
//  tourist app; admins manage hotels, guides, sites, events,
//  bookings, the news feed and safety alerts from here.
//  Run with:  flutter run -d chrome
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/admin_theme.dart';
import 'services/admin_supabase.dart';
import 'screens/auth/admin_login_screen.dart';
import 'screens/dashboard/admin_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads .env and opens the Supabase connection — must finish
  // before any screen tries to read data.
  await AdminSupabase.initialize();
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visit Gondar Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.theme,
      // Session still valid from last visit → skip the login screen.
      home: AdminSupabase.isLoggedIn
          ? const AdminShell()
          : const AdminLoginScreen(),
    );
  }
}
