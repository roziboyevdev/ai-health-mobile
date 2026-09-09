import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/health_metric_ui.dart';
import '../screens/activity_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/devices_screen.dart';
import '../screens/history_screen.dart';
import '../screens/metric_detail_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
            routes: [
              GoRoute(
                path: 'metric/:type',
                builder: (context, state) {
                  return MetricDetailScreen(
                    type: HealthMetricTypeSlug.fromSlug(
                      state.pathParameters['type'],
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'activity',
                builder: (context, state) => const ActivityScreen(),
              ),
              GoRoute(
                path: 'history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/devices',
            builder: (context, state) => const DevicesScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
