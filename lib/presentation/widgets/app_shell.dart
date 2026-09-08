import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const _items = [
    _NavItem('/', Icons.dashboard_outlined, 'Dashboard'),
    _NavItem('/devices', Icons.watch_outlined, 'Devices'),
    _NavItem('/heart', Icons.favorite_outline, 'Heart'),
    _NavItem('/sleep', Icons.bedtime_outlined, 'Sleep'),
    _NavItem('/activity', Icons.directions_walk_outlined, 'Activity'),
    _NavItem('/settings', Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _items.indexWhere((item) => item.path == location);
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (value) => context.go(_items[value].path),
        destinations: [
          for (final item in _items)
            NavigationDestination(icon: Icon(item.icon), label: item.label),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.icon, this.label);

  final String path;
  final IconData icon;
  final String label;
}
