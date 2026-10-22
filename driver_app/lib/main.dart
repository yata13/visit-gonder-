import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/driver_gate.dart';
import 'screens/sign_in_screen.dart';
import 'services/alerts.dart';
import 'theme.dart';
import 'widgets/common.dart';

// ═══════════════════════════════════════════════════════════════
//  VISIT GONDAR DRIVER — the app for partner bajaj and taxi drivers.
//  Same Supabase project as the tourist app: a tourist requests a
//  ride there, nearby drivers get it here, one accepts and drives.
// ═══════════════════════════════════════════════════════════════
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var ready = false;
  try {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (url.startsWith('http') && !url.contains('YOUR_') &&
        key.isNotEmpty && !key.startsWith('YOUR_')) {
      await Supabase.initialize(url: url, publishableKey: key);
      ready = true;
    }
  } catch (_) {
    // missing / empty .env — the setup screen explains what to do
  }
  await Alerts.init();
  runApp(DriverApp(ready: ready));
}

class DriverApp extends StatelessWidget {
  final bool ready;
  const DriverApp({super.key, this.ready = true});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VG Driver',
        debugShowCheckedModeBanner: false,
        theme: VG.theme,
        home: ready ? const AuthGate() : const SetupNeeded(),
      );
}

/// Signed out → sign in. Signed in → the driver's own screens.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        final user = auth.currentUser;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          child: user == null
              ? const SignInScreen(key: ValueKey('sign-in'))
              : DriverGate(key: ValueKey(user.id)),
        );
      },
    );
  }
}

class SetupNeeded extends StatelessWidget {
  const SetupNeeded({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              BrandBadge(icon: Icons.settings_rounded),
              SizedBox(height: 24),
              Text('Almost ready',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: VG.ink)),
              SizedBox(height: 12),
              Text(
                'Copy the .env file from the visit_gondar_app folder into the '
                'driver_app folder (same Supabase keys), then start the app again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.45, color: VG.muted),
              ),
            ]),
          ),
        ),
      );
}
