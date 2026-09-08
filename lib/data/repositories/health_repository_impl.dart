import 'package:collection/collection.dart';

import '../../core/utils/date_utils.dart';
import '../../domain/entities/dashboard_snapshot.dart';
import '../../domain/repositories/health_repository.dart';
import '../models/daily_summary.dart';
import '../models/device.dart';
import '../models/heart_rate_record.dart';
import '../models/sleep_session.dart';
import '../models/spo2_record.dart';
import '../models/step_record.dart';

class LocalHealthRepository implements HealthRepository {
  LocalHealthRepository._();

  static final instance = LocalHealthRepository._();

  final List<Device> _devices = [];
  final List<HeartRateRecord> _heartRates = [];
  final List<SpO2Record> _spo2 = [];
  final List<StepRecord> _steps = [];
  final List<SleepSession> _sleep = [];
  final List<DailySummary> _summaries = [];
  int _nextId = 1;

  @override
  Future<void> upsertDevice(Device device) async {
    final index = _devices.indexWhere((item) => item.deviceId == device.deviceId);
    device.updatedAt = DateTime.now();
    if (index == -1) {
      device.id = _nextId++;
      _devices.add(device);
    } else {
      device.id = _devices[index].id;
      _devices[index] = device;
    }
  }

  @override
  Future<Device?> connectedDevice() async {
    return _devices.where((device) => device.isConnected).firstOrNull;
  }

  @override
  Future<List<Device>> devices() async {
    final result = [..._devices];
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  @override
  Future<void> markAllDisconnected() async {
    for (final device in _devices) {
      device.isConnected = false;
      device.updatedAt = DateTime.now();
    }
  }

  @override
  Future<void> saveHeartRate(HeartRateRecord record) async {
    record.id = _nextId++;
    _heartRates.add(record);
  }

  @override
  Future<void> saveSpO2(SpO2Record record) async {
    record.id = _nextId++;
    _spo2.add(record);
  }

  @override
  Future<void> saveSteps(StepRecord record) async {
    record.id = _nextId++;
    final index = _steps.indexWhere(
      (item) =>
          item.deviceId == record.deviceId &&
          AppDateUtils.startOfDay(item.date) == AppDateUtils.startOfDay(record.date),
    );
    if (index == -1) {
      _steps.add(record);
    } else {
      _steps[index] = record;
    }
  }

  @override
  Future<void> saveSleep(SleepSession session) async {
    session.id = _nextId++;
    _sleep.add(session);
  }

  @override
  Future<void> upsertDailySummary(DailySummary summary) async {
    final day = AppDateUtils.startOfDay(summary.date);
    final index = _summaries.indexWhere(
      (item) => item.deviceId == summary.deviceId && AppDateUtils.startOfDay(item.date) == day,
    );
    summary.date = day;
    summary.updatedAt = DateTime.now();
    if (index == -1) {
      summary.id = _nextId++;
      _summaries.add(summary);
    } else {
      summary.id = _summaries[index].id;
      _summaries[index] = summary;
    }
  }

  @override
  Future<DashboardSnapshot> dashboardSnapshot() async {
    final today = AppDateUtils.startOfDay(DateTime.now());
    final device = await connectedDevice();
    final summary = _summaries.where((item) => AppDateUtils.startOfDay(item.date) == today).firstOrNull;
    final latestHeartRate = _latestByDate(_heartRates, (item) => item.recordedAt);
    final latestSpO2 = _latestByDate(_spo2, (item) => item.recordedAt);
    final latestSleep = _latestByDate(_sleep, (item) => item.startedAt);
    final latestSteps = _latestByDate(_steps, (item) => item.date);

    return DashboardSnapshot(
      device: device,
      summary: summary,
      latestHeartRate: latestHeartRate,
      latestSpO2: latestSpO2,
      latestSleep: latestSleep,
      latestSteps: latestSteps,
    );
  }

  @override
  Future<List<HeartRateRecord>> heartRateHistory({int days = 7}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    return _heartRates.where((item) => item.recordedAt.isAfter(since)).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }

  @override
  Future<List<SpO2Record>> spo2History({int days = 7}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    return _spo2.where((item) => item.recordedAt.isAfter(since)).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }

  @override
  Future<List<StepRecord>> stepHistory({int days = 14}) async {
    final since = AppDateUtils.startOfDay(DateTime.now().subtract(Duration(days: days)));
    return _steps.where((item) => item.date.isAfter(since) || item.date == since).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<List<SleepSession>> sleepHistory({int days = 14}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    return _sleep.where((item) => item.startedAt.isAfter(since)).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  }

  @override
  Future<void> clearAllData() async {
    _devices.clear();
    _heartRates.clear();
    _spo2.clear();
    _steps.clear();
    _sleep.clear();
    _summaries.clear();
  }

  T? _latestByDate<T>(List<T> items, DateTime Function(T item) dateOf) {
    if (items.isEmpty) return null;
    final sorted = [...items]..sort((a, b) => dateOf(b).compareTo(dateOf(a)));
    return sorted.first;
  }
}
