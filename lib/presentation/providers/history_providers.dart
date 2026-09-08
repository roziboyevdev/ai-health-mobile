import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/models/heart_rate_record.dart';
import '../../data/models/sleep_session.dart';
import '../../data/models/spo2_record.dart';
import '../../data/models/step_record.dart';
import '../../domain/entities/dashboard_snapshot.dart';
import 'bluetooth_provider.dart';
import 'repository_providers.dart';

final dashboardSnapshotProvider = FutureProvider<DashboardSnapshot>((ref) {
  ref.watch(bluetoothNotifierProvider.select((state) => state.healthEpoch));
  return ref.read(healthRepositoryProvider).dashboardSnapshot();
});

final heartRateHistoryProvider = FutureProvider<List<HeartRateRecord>>((ref) {
  ref.watch(bluetoothNotifierProvider.select((state) => state.healthEpoch));
  return ref.read(healthRepositoryProvider).heartRateHistory();
});

final spo2HistoryProvider = FutureProvider<List<SpO2Record>>((ref) {
  ref.watch(bluetoothNotifierProvider.select((state) => state.healthEpoch));
  return ref.read(healthRepositoryProvider).spo2History();
});

final stepHistoryProvider = FutureProvider<List<StepRecord>>((ref) {
  ref.watch(bluetoothNotifierProvider.select((state) => state.healthEpoch));
  return ref.read(healthRepositoryProvider).stepHistory();
});

final sleepHistoryProvider = FutureProvider<List<SleepSession>>((ref) {
  ref.watch(bluetoothNotifierProvider.select((state) => state.healthEpoch));
  return ref.read(healthRepositoryProvider).sleepHistory();
});

final syncNotifierProvider = AsyncNotifierProvider<SyncNotifier, void>(SyncNotifier.new);

class SyncNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> syncNow() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(bluetoothNotifierProvider.notifier).syncHistory();
      ref.invalidate(dashboardSnapshotProvider);
      ref.invalidate(heartRateHistoryProvider);
      ref.invalidate(spo2HistoryProvider);
      ref.invalidate(stepHistoryProvider);
      ref.invalidate(sleepHistoryProvider);
    });
  }
}
