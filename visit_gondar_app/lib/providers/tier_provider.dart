import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import '../core/constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════
//  TWO KINDS OF VISITOR (proposal page 9)
//   Free     — every visitor: sites, maps, verified listings,
//              ratings, weather, SOS + safety notices.
//   Premium  — optional upgrade: Ask Gondar AI and the extras.
//  The tier is stored server-side (user_tiers) and only an admin
//  can change it; the app just reads it.
// ═══════════════════════════════════════════════════════════════
enum Tier { free, premium }

class UserTier {
  final Tier tier;
  final bool signedIn;
  final DateTime? premiumUntil;
  final bool requestPending; // asked for Premium, waiting for approval
  const UserTier({
    required this.tier,
    required this.signedIn,
    this.premiumUntil,
    this.requestPending = false,
  });

  bool get isPremium => tier == Tier.premium;
  static const guest = UserTier(tier: Tier.free, signedIn: false);
}

final userTierProvider = FutureProvider<UserTier>((ref) async {
  ref.watch(authStateProvider); // re-check on sign in / sign out
  final db = Supabase.instance.client;
  final user = db.auth.currentUser;
  // Demo mode: everyone tries Premium (see AppConstants.demoMode).
  if (AppConstants.demoMode) {
    return UserTier(tier: Tier.premium, signedIn: user != null);
  }
  if (user == null) return UserTier.guest;

  try {
    // is_premium() also covers expiry and team members.
    final premium = await db.rpc('is_premium', params: const {}) == true;
    final tierRow = await db
        .from('user_tiers')
        .select('premium_until')
        .eq('user_id', user.id)
        .maybeSingle();
    final pending = await db
        .from('premium_requests')
        .select('id')
        .eq('user_id', user.id)
        .eq('status', 'pending')
        .maybeSingle();
    return UserTier(
      tier: premium ? Tier.premium : Tier.free,
      signedIn: true,
      premiumUntil: DateTime.tryParse(
          (tierRow?['premium_until'] ?? '') as String),
      requestPending: pending != null,
    );
  } catch (_) {
    // Migration 0014 not applied yet, or offline → treat as Free.
    return const UserTier(tier: Tier.free, signedIn: true);
  }
});

/// Visitor asks for Premium; an admin approves it in the dashboard.
Future<void> requestPremium({String? note}) async {
  final db = Supabase.instance.client;
  final user = db.auth.currentUser;
  if (user == null) throw Exception('Please sign in first.');
  await db.from('premium_requests').insert({
    'user_id': user.id,
    'email': user.email,
    'note': note,
  });
}
