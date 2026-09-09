import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../localization/app_strings.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final items = [
      _NavItem('/', Icons.health_and_safety_outlined, strings.health),
      _NavItem('/devices', Icons.watch_outlined, strings.devices),
      _NavItem('/settings', Icons.tune_outlined, strings.settings),
    ];
    final index = _selectedIndex(location);
    final showNavigation = !_isDetailLocation(location);

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: showNavigation
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) => context.go(items[value].path),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final item in items)
                  NavigationDestination(icon: Icon(item.icon), label: item.label),
              ],
            )
          : null,
    );
  }

  int _selectedIndex(String value) {
    if (value.startsWith('/devices')) return 1;
    if (value.startsWith('/settings')) return 2;
    return 0;
  }

  bool _isDetailLocation(String value) {
    return value.startsWith('/metric') ||
        value.startsWith('/history') ||
        value.startsWith('/activity');
  }
}

class _NavItem {
  const _NavItem(this.path, this.icon, this.label);

  final String path;
  final IconData icon;
  final String label;
}
