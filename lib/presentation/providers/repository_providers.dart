import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/datasources/ble/ble_service.dart';
import '../../data/datasources/ble/ble_service_impl.dart';
import '../../data/repositories/ble_repository_impl.dart';
import '../../data/repositories/health_repository_impl.dart';
import '../../domain/repositories/ble_repository.dart';
import '../../domain/repositories/health_repository.dart';

final bleServiceProvider = Provider<BleService>((ref) => MethodChannelBleService());

final bleRepositoryProvider = Provider<BleRepository>((ref) {
  return BleRepositoryImpl(ref.watch(bleServiceProvider));
});

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return LocalHealthRepository.instance;
});
