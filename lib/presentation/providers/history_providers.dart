import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/datasources/ble/ble_models.dart';
import '../../data/models/heart_rate_record.dart';
import '../../data/models/metric_sample.dart';
import '../../data/models/sleep_session.dart';
import '../../data/models/spo2_record.dart';
import '../../data/models/step_record.dart';
import '../../data/models/device.dart';
import '../../domain/entities/dashboard_snapshot.dart';
import 'bluetooth_provider.dart';
import 'repository_providers.dart';

final dashboardRefreshProvider = NotifierProvider<RefreshNotifier, int>(
  RefreshNotifier.new,
);
final devicesRefreshProvider = NotifierProvider<RefreshNotifier, int>(
  RefreshNotifier.new,
);
final heartRefreshProvider = NotifierProvider<RefreshNotifier, int>(
  RefreshNotifier.new,
);
final sleepRefreshProvider = NotifierProvider<RefreshNotifier, int>(
  RefreshNotifier.new,
);
final activityRefreshProvider = NotifierProvider<RefreshNotifier, int>(
  RefreshNotifier.new,
);
final metricRefreshProvider =
    NotifierProvider.family<MetricRefreshNotifier, int, String>(
      MetricRefreshNotifier.new,
    );

class RefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

class MetricRefreshNotifier extends Notifier<int> {
  MetricRefreshNotifier(String metricType);

  @override
  int build() => 0;

  void bump() => state++;
}

final dashboardSnapshotProvider = FutureProvider<DashboardSnapshot>((ref) {
  ref.watch(dashboardRefreshProvider);
  return ref.read(healthRepositoryProvider).dashboardSnapshot();
});

final heartRateHistoryProvider = FutureProvider<List<HeartRateRecord>>((ref) {
  ref.watch(heartRefreshProvider);
  return ref.read(healthRepositoryProvider).heartRateHistory();
});

final spo2HistoryProvider = FutureProvider<List<SpO2Record>>((ref) {
  ref.watch(dashboardRefreshProvider);
  return ref.read(healthRepositoryProvider).spo2History();
});

final stepHistoryProvider = FutureProvider<List<StepRecord>>((ref) {
  ref.watch(activityRefreshProvider);
  return ref.read(healthRepositoryProvider).stepHistory();
});

final sleepHistoryProvider = FutureProvider<List<SleepSession>>((ref) {
  ref.watch(sleepRefreshProvider);
  return ref.read(healthRepositoryProvider).sleepHistory();
});

final monthStatsProvider = FutureProvider<Map<String, MonthMetricStats>>((ref) {
  ref.watch(dashboardRefreshProvider);
  return ref.read(healthRepositoryProvider).monthStats();
});

final metricHistoryProvider = FutureProvider.family<List<MetricSample>, String>(
  (ref, metricType) {
    ref.watch(metricRefreshProvider(metricType));
    return ref.read(healthRepositoryProvider).metricHistory(metricType);
  },
);

final devicesHistoryProvider = FutureProvider<List<Device>>((ref) {
  ref.watch(devicesRefreshProvider);
  return ref.read(healthRepositoryProvider).devices();
});

final syncNotifierProvider = AsyncNotifierProvider<SyncNotifier, void>(
  SyncNotifier.new,
);

class SyncNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> syncNow() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final sync = await ref
          .read(bluetoothNotifierProvider.notifier)
          .syncHistory();
      _refreshFromSyncResult(sync);
    });
  }

  void _refreshFromSyncResult(HealthSyncResult sync) {
    final refreshDashboard =
        sync.batteryLevel != null ||
        sync.heartRate.isNotEmpty ||
        sync.spo2.isNotEmpty ||
        sync.steps.isNotEmpty ||
        sync.sleep.isNotEmpty;
    if (refreshDashboard) {
      ref.read(dashboardRefreshProvider.notifier).bump();
    }
    if (sync.batteryLevel != null) {
      ref.read(devicesRefreshProvider.notifier).bump();
      ref.read(metricRefreshProvider('battery').notifier).bump();
    }
    if (sync.heartRate.isNotEmpty) {
      ref.read(heartRefreshProvider.notifier).bump();
      ref.read(metricRefreshProvider('heart_rate').notifier).bump();
    }
    if (sync.spo2.isNotEmpty) {
      ref.read(metricRefreshProvider('spo2').notifier).bump();
    }
    if (sync.steps.isNotEmpty) {
      ref.read(activityRefreshProvider.notifier).bump();
      ref.read(metricRefreshProvider('steps').notifier).bump();
      ref.read(metricRefreshProvider('distance').notifier).bump();
      ref.read(metricRefreshProvider('calories').notifier).bump();
    }
    if (sync.sleep.isNotEmpty) {
      ref.read(sleepRefreshProvider.notifier).bump();
      ref.read(metricRefreshProvider('sleep_minutes').notifier).bump();
      ref.read(metricRefreshProvider('deep_sleep_minutes').notifier).bump();
    }
  }
}
