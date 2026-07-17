// ═══════════════════════════════════════════════════════════════
//  AdminShell — the frame around every admin page: sidebar
//  navigation on the left, the selected screen on the right.
//  Add a new admin tab here: one _NavItem + one screen, same index.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_supabase.dart';
import '../auth/admin_login_screen.dart';
import 'dashboard_home_screen.dart';
import '../hotels/hotels_screen.dart';
import '../guides/guides_screen.dart';
import '../sites/sites_screen.dart';
import '../events/events_screen.dart';
import '../notifications/notifications_screen.dart';
import '../posts/posts_screen.dart';
import '../places/places_screen.dart';
import '../bookings/bookings_screen.dart';
import '../safety/safety_screen.dart';
import '../emergency/emergency_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_outlined,    activeIcon: Icons.dashboard,       label: 'Dashboard'),
    _NavItem(icon: Icons.hotel_outlined,         activeIcon: Icons.hotel,           label: 'Hotels'),
    _NavItem(icon: Icons.person_pin_outlined,    activeIcon: Icons.person_pin,      label: 'Guides'),
    _NavItem(icon: Icons.account_balance_outlined,activeIcon: Icons.account_balance,label: 'Sites'),
    _NavItem(icon: Icons.celebration_outlined,   activeIcon: Icons.celebration,     label: 'Events'),
    _NavItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications,   label: 'Notifications'),
    _NavItem(icon: Icons.dynamic_feed_outlined,  activeIcon: Icons.dynamic_feed,    label: 'News Feed'),
    _NavItem(icon: Icons.edit_location_outlined, activeIcon: Icons.edit_location,   label: 'Map Manager'),
    _NavItem(icon: Icons.receipt_long_outlined,  activeIcon: Icons.receipt_long,    label: 'Bookings'),
    _NavItem(icon: Icons.shield_outlined,        activeIcon: Icons.shield,           label: 'Safety'),
    _NavItem(icon: Icons.sos_outlined,           activeIcon: Icons.sos,              label: 'Emergency'),
  ];

  final List<Widget> _screens = const [
    DashboardHomeScreen(),
    HotelsAdminScreen(),
    GuidesAdminScreen(),
    SitesAdminScreen(),
    EventsAdminScreen(),
    NotificationsAdminScreen(),
    PostsAdminScreen(),
    PlacesAdminScreen(),
    BookingsAdminScreen(),
    SafetyAdminScreen(),
    EmergencyAdminScreen(),
  ];

  Future<void> _signOut() async {
    await AdminSupabase.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        // ── SIDEBAR ─────────────────────────────────────────────
        _Sidebar(
          navItems: _navItems,
          selectedIndex: _selectedIndex,
          onItemTap: (i) => setState(() => _selectedIndex = i),
          onSignOut: _signOut,
        ),

        // ── MAIN CONTENT ─────────────────────────────────────────
        Expanded(
          child: Column(children: [
            // Top bar
            _TopBar(title: _navItems[_selectedIndex].label),
            // Body
            Expanded(child: _screens[_selectedIndex]),
          ]),
        ),
      ]),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// SIDEBAR
// ────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final List<_NavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onItemTap;
  final VoidCallback onSignOut;
  const _Sidebar({
    required this.navItems,
    required this.selectedIndex,
    required this.onItemTap,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AdminColors.sidebar,
      child: Column(children: [
        // Logo area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AdminColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_city,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Visit Gondar',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
                Text('Admin',
                    style: TextStyle(color: Colors.white38,
                        fontSize: 11)),
              ],
            ),
          ]),
        ),

        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 8),

        // Nav items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: navItems.length,
            itemBuilder: (_, i) => _SidebarTile(
              item: navItems[i],
              selected: i == selectedIndex,
              onTap: () => onItemTap(i),
            ),
          ),
        ),

        const Divider(color: Colors.white12, height: 1),

        // Sign out
        Padding(
          padding: const EdgeInsets.all(12),
          child: _SidebarTile(
            item: const _NavItem(
                icon: Icons.logout,
                activeIcon: Icons.logout,
                label: 'Sign out'),
            selected: false,
            onTap: onSignOut,
            isSignOut: true,
          ),
        ),
      ]),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool isSignOut;
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
    this.isSignOut = false,
  });
  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}
class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.selected && !widget.isSignOut;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AdminColors.gold.withOpacity(0.2)
                : _hovered ? Colors.white.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active
                ? Border.all(color: AdminColors.gold.withOpacity(0.4))
                : null,
          ),
          child: Row(children: [
            Icon(
              active ? widget.item.activeIcon : widget.item.icon,
              size: 18,
              color: active
                  ? AdminColors.gold
                  : widget.isSignOut
                      ? Colors.redAccent.withOpacity(0.8)
                      : Colors.white60,
            ),
            const SizedBox(width: 10),
            Text(widget.item.label,
                style: TextStyle(
                  color: active
                      ? AdminColors.gold
                      : widget.isSignOut
                          ? Colors.redAccent.withOpacity(0.8)
                          : Colors.white70,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                )),
          ]),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// TOP BAR
// ────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});
  @override
  Widget build(BuildContext context) {
    final user = AdminSupabase.currentUser;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AdminColors.textPrimary)),
        const Spacer(),
        // User avatar chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AdminColors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AdminColors.border),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AdminColors.gold,
              child: Text(
                (user?.email?.isNotEmpty == true)
                    ? user!.email![0].toUpperCase() : 'A',
                style: const TextStyle(color: Colors.white,
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(user?.email ?? 'Admin',
                style: const TextStyle(
                    fontSize: 13, color: AdminColors.textSecondary,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// NAV ITEM model
// ────────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
