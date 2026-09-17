import 'package:flutter/material.dart';
import '../services/admin_auth_service.dart';
import '../theme.dart';
import 'incidents_screen.dart';
import 'live_sessions_screen.dart';
import 'overview_screen.dart';
import 'users_screen.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _index = 0;

  static const _items = [
    (icon: Icons.dashboard_outlined, label: 'Overview'),
    (icon: Icons.report_gmailerrorred_outlined, label: 'Reports & SOS'),
    (icon: Icons.people_outline_rounded, label: 'Users'),
    (icon: Icons.share_location_outlined, label: 'Live Tracking'),
  ];

  static const _pages = [
    OverviewScreen(),
    IncidentsScreen(),
    UsersScreen(),
    LiveSessionsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 232,
            color: AppColors.sidebar,
            child: Column(
              children: [
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('SafeHer Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 28),
                for (var i = 0; i < _items.length; i++) _NavTile(
                  icon: _items[i].icon,
                  label: _items[i].label,
                  selected: _index == i,
                  onTap: () => setState(() => _index = i),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _NavTile(
                    icon: Icons.logout_rounded,
                    label: 'Sign out',
                    selected: false,
                    onTap: () => AdminAuthService.signOut(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _pages[_index]),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 18, color: selected ? AppColors.primary : Colors.white70),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: selected ? AppColors.primary : Colors.white70, fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
