import 'package:collection/collection.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/date_utils.dart';
import '../../domain/entities/dashboard_snapshot.dart';
import '../../domain/repositories/health_repository.dart';
import '../datasources/local/app_database.dart';
import '../models/daily_summary.dart';
import '../models/device.dart';
import '../models/heart_rate_record.dart';
import '../models/metric_sample.dart';
import '../models/sleep_session.dart';
import '../models/spo2_record.dart';
import '../models/step_record.dart';

class LocalHealthRepository implements HealthRepository {
  LocalHealthRepository._({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  static final instance = LocalHealthRepository._();

  final AppDatabase _database;

  @override
  Future<void> upsertDevice(Device device) async {
    final db = await _database.database;
    device.updatedAt = DateTime.now();
    await db.insert(
      'devices',
      _database.deviceToMap(device),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Device?> connectedDevice() async {
    final db = await _database.database;
    final rows = await db.query(
      'devices',
      where: 'is_connected = 1',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return rows.map(_database.deviceFromMap).firstOrNull;
  }

  @override
  Future<List<Device>> devices() async {
    final db = await _database.database;
    final rows = await db.query('devices', orderBy: 'updated_at DESC');
    return rows.map(_database.deviceFromMap).toList();
  }

  @override
  Future<void> markAllDisconnected() async {
    final db = await _database.database;
    final now = _database.millis(DateTime.now());
    await db.update('devices', {'is_connected': 0, 'updated_at': now});
    await db.update(
      'device_connection_sessions',
      {'ended_at': now, 'status': 'disconnected'},
      where: 'ended_at IS NULL',
    );
  }

  @override
  Future<void> recordConnectionSession({
    required String deviceId,
    required DateTime startedAt,
    DateTime? endedAt,
    String status = 'connected',
    String? errorMessage,
  }) async {
    final db = await _database.database;
    await db.insert('device_connection_sessions', {
      'device_id': deviceId,
      'started_at': _database.millis(startedAt),
      'ended_at': endedAt == null ? null : _database.millis(endedAt),
      'status': status,
      'error_message': errorMessage,
    });
  }

  @override
  Future<bool> saveMetricSample(MetricSample sample) async {
    final db = await _database.database;
    final id = await db.insert(
      'metric_samples',
      _database.metricSampleToMap(sample),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (id == 0) return false;
    await _refreshAggregates(sample.deviceId, sample.metricType, sample.timestamp);
    return true;
  }

  @override
  Future<void> saveMetricSamples(Iterable<MetricSample> samples) async {
    for (final sample in samples) {
      await saveMetricSample(sample);
    }
  }

  @override
  Future<List<MetricSample>> metricHistory(String metricType, {int days = 30}) async {
    final db = await _database.database;
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await db.query(
      'metric_samples',
      where: 'metric_type = ? AND timestamp >= ?',
      whereArgs: [metricType, _database.millis(since)],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_database.metricSampleFromMap).toList();
  }

  @override
  Future<void> saveHeartRate(HeartRateRecord record) async {
    final db = await _database.database;
    await db.insert(
      'heart_rate_records',
      {
        'device_id': record.deviceId,
        'recorded_at': _database.millis(record.recordedAt),
        'bpm': record.bpm,
        'is_realtime': record.isRealtime ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await saveMetricSample(
      MetricSample(
        deviceId: record.deviceId,
        metricType: 'heart_rate',
        timestamp: record.recordedAt,
        valueNumeric: record.bpm.toDouble(),
        unit: 'bpm',
        rawPayload: {'bpm': record.bpm, 'isRealtime': record.isRealtime},
      ),
    );
  }

  @override
  Future<void> saveSpO2(SpO2Record record) async {
    final db = await _database.database;
    await db.insert(
      'spo2_records',
      {
        'device_id': record.deviceId,
        'recorded_at': _database.millis(record.recordedAt),
        'percentage': record.percentage,
        'is_realtime': record.isRealtime ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await saveMetricSample(
      MetricSample(
        deviceId: record.deviceId,
        metricType: 'spo2',
        timestamp: record.recordedAt,
        valueNumeric: record.percentage.toDouble(),
        unit: '%',
        rawPayload: {'percentage': record.percentage, 'isRealtime': record.isRealtime},
      ),
    );
  }

  @override
  Future<void> saveSteps(StepRecord record) async {
    final db = await _database.database;
    final day = AppDateUtils.startOfDay(record.date);
    await db.insert(
      'step_records',
      {
        'device_id': record.deviceId,
        'date': _database.millis(day),
        'steps': record.steps,
        'distance_km': record.distanceKm,
        'calories': record.calories,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await saveMetricSamples([
      MetricSample(
        deviceId: record.deviceId,
        metricType: 'steps',
        timestamp: day,
        valueNumeric: record.steps.toDouble(),
        unit: 'steps',
        rawPayload: {'steps': record.steps},
      ),
      MetricSample(
        deviceId: record.deviceId,
        metricType: 'distance',
        timestamp: day,
        valueNumeric: record.distanceKm,
        unit: 'km',
        rawPayload: {'distanceKm': record.distanceKm},
      ),
      MetricSample(
        deviceId: record.deviceId,
        metricType: 'calories',
        timestamp: day,
        valueNumeric: record.calories.toDouble(),
        unit: 'kcal',
        rawPayload: {'calories': record.calories},
      ),
    ].where((sample) => (sample.valueNumeric ?? 0) > 0));
  }

  @override
  Future<void> saveSleep(SleepSession session) async {
    final db = await _database.database;
    await db.insert(
      'sleep_sessions',
      {
        'device_id': session.deviceId,
        'started_at': _database.millis(session.startedAt),
        'ended_at': _database.millis(session.endedAt),
        'total_minutes': session.totalMinutes,
        'deep_minutes': session.deepMinutes,
        'light_minutes': session.lightMinutes,
        'rem_minutes': session.remMinutes,
        'awake_minutes': session.awakeMinutes,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await saveMetricSamples([
      MetricSample(
        deviceId: session.deviceId,
        metricType: 'sleep_minutes',
        timestamp: session.startedAt,
        valueNumeric: session.totalMinutes.toDouble(),
        unit: 'min',
        rawPayload: {'totalMinutes': session.totalMinutes},
      ),
      MetricSample(
        deviceId: session.deviceId,
        metricType: 'deep_sleep_minutes',
        timestamp: session.startedAt,
        valueNumeric: session.deepMinutes.toDouble(),
        unit: 'min',
        rawPayload: {'deepMinutes': session.deepMinutes},
      ),
    ].where((sample) => (sample.valueNumeric ?? 0) > 0));
  }

  @override
  Future<void> upsertDailySummary(DailySummary summary) async {
    final db = await _database.database;
    summary.date = AppDateUtils.startOfDay(summary.date);
    summary.updatedAt = DateTime.now();
    await db.insert(
      'daily_summaries',
      _database.dailySummaryToMap(summary),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<DashboardSnapshot> dashboardSnapshot() async {
    await pruneOldData();
    final today = AppDateUtils.startOfDay(DateTime.now());
    final device = await connectedDevice();
    final db = await _database.database;
    final summaryRows = await db.query(
      'daily_summaries',
      where: 'date = ?',
      whereArgs: [_database.millis(today)],
      limit: 1,
    );
    return DashboardSnapshot(
      device: device,
      summary: summaryRows.map(_database.dailySummaryFromMap).firstOrNull,
      latestHeartRate: (await heartRateHistory(days: 30)).lastOrNull,
      latestSpO2: (await spo2History(days: 30)).lastOrNull,
      latestSleep: (await sleepHistory(days: 30)).lastOrNull,
      latestSteps: (await stepHistory(days: 30)).lastOrNull,
      monthStats: await monthStats(),
      lastSyncAt: await _latestSampleTime(),
    );
  }

  @override
  Future<Map<String, MonthMetricStats>> monthStats({int days = 30}) async {
    final db = await _database.database;
    final now = DateTime.now();
    final since = _database.millis(now.subtract(Duration(days: days)));
    final previousSince = _database.millis(now.subtract(Duration(days: days * 2)));
    final currentRows = await db.rawQuery('''
SELECT metric_type, COUNT(*) sample_count, SUM(value_numeric) total, AVG(value_numeric) average,
       MIN(value_numeric) min_value, MAX(value_numeric) max_value, unit
FROM metric_samples
WHERE timestamp >= ? AND value_numeric IS NOT NULL
GROUP BY metric_type, unit
''', [since]);
    final previousRows = await db.rawQuery('''
SELECT metric_type, SUM(value_numeric) total
FROM metric_samples
WHERE timestamp >= ? AND timestamp < ? AND value_numeric IS NOT NULL
GROUP BY metric_type
''', [previousSince, since]);
    final previousTotals = {
      for (final row in previousRows) row['metric_type'] as String: (row['total'] as num?)?.toDouble() ?? 0,
    };
    final latestRows = await db.rawQuery('''
SELECT metric_type, value_numeric
FROM metric_samples
WHERE timestamp >= ? AND value_numeric IS NOT NULL
ORDER BY timestamp ASC
''', [since]);
    final latest = <String, double>{};
    for (final row in latestRows) {
      latest[row['metric_type'] as String] = (row['value_numeric'] as num).toDouble();
    }
    return {
      for (final row in currentRows)
        row['metric_type'] as String: MonthMetricStats(
          metricType: row['metric_type'] as String,
          sampleCount: row['sample_count'] as int,
          total: (row['total'] as num?)?.toDouble() ?? 0,
          average: (row['average'] as num?)?.toDouble(),
          min: (row['min_value'] as num?)?.toDouble(),
          max: (row['max_value'] as num?)?.toDouble(),
          latest: latest[row['metric_type']],
          previousTotal: previousTotals[row['metric_type']],
          trendDelta: ((row['total'] as num?)?.toDouble() ?? 0) - (previousTotals[row['metric_type']] ?? 0),
          unit: row['unit'] as String?,
        ),
    };
  }

  @override
  Future<List<HeartRateRecord>> heartRateHistory({int days = 7}) async {
    final db = await _database.database;
    final rows = await db.query(
      'heart_rate_records',
      where: 'recorded_at >= ?',
      whereArgs: [_database.millis(DateTime.now().subtract(Duration(days: days)))],
      orderBy: 'recorded_at ASC',
    );
    return rows
        .map((row) => HeartRateRecord()
          ..id = row['id'] as int
          ..deviceId = row['device_id'] as String
          ..recordedAt = _database.date(row['recorded_at'] as int)
          ..bpm = row['bpm'] as int
          ..isRealtime = (row['is_realtime'] as int? ?? 0) == 1)
        .toList();
  }

  @override
  Future<List<SpO2Record>> spo2History({int days = 7}) async {
    final db = await _database.database;
    final rows = await db.query(
      'spo2_records',
      where: 'recorded_at >= ?',
      whereArgs: [_database.millis(DateTime.now().subtract(Duration(days: days)))],
      orderBy: 'recorded_at ASC',
    );
    return rows
        .map((row) => SpO2Record()
          ..id = row['id'] as int
          ..deviceId = row['device_id'] as String
          ..recordedAt = _database.date(row['recorded_at'] as int)
          ..percentage = row['percentage'] as int
          ..isRealtime = (row['is_realtime'] as int? ?? 0) == 1)
        .toList();
  }

  @override
  Future<List<StepRecord>> stepHistory({int days = 14}) async {
    final db = await _database.database;
    final since = AppDateUtils.startOfDay(DateTime.now().subtract(Duration(days: days)));
    final rows = await db.query(
      'step_records',
      where: 'date >= ?',
      whereArgs: [_database.millis(since)],
      orderBy: 'date ASC',
    );
    return rows
        .map((row) => StepRecord()
          ..id = row['id'] as int
          ..deviceId = row['device_id'] as String
          ..date = _database.date(row['date'] as int)
          ..steps = row['steps'] as int
          ..distanceKm = (row['distance_km'] as num).toDouble()
          ..calories = row['calories'] as int)
        .toList();
  }

  @override
  Future<List<SleepSession>> sleepHistory({int days = 14}) async {
    final db = await _database.database;
    final rows = await db.query(
      'sleep_sessions',
      where: 'started_at >= ?',
      whereArgs: [_database.millis(DateTime.now().subtract(Duration(days: days)))],
      orderBy: 'started_at ASC',
    );
    return rows
        .map((row) => SleepSession()
          ..id = row['id'] as int
          ..deviceId = row['device_id'] as String
          ..startedAt = _database.date(row['started_at'] as int)
          ..endedAt = _database.date(row['ended_at'] as int)
          ..totalMinutes = row['total_minutes'] as int
          ..deepMinutes = row['deep_minutes'] as int
          ..lightMinutes = row['light_minutes'] as int
          ..remMinutes = row['rem_minutes'] as int
          ..awakeMinutes = row['awake_minutes'] as int)
        .toList();
  }

  @override
  Future<void> pruneOldData({int days = AppDatabase.retentionDays}) async {
    final db = await _database.database;
    final cutoff = _database.millis(DateTime.now().subtract(Duration(days: days)));
    await db.delete('metric_samples', where: 'timestamp < ?', whereArgs: [cutoff]);
    await db.delete('hourly_aggregate_summaries', where: 'period_start < ?', whereArgs: [cutoff]);
    await db.delete('daily_aggregate_summaries', where: 'period_start < ?', whereArgs: [cutoff]);
    await db.delete('heart_rate_records', where: 'recorded_at < ?', whereArgs: [cutoff]);
    await db.delete('spo2_records', where: 'recorded_at < ?', whereArgs: [cutoff]);
    await db.delete('step_records', where: 'date < ?', whereArgs: [cutoff]);
    await db.delete('sleep_sessions', where: 'started_at < ?', whereArgs: [cutoff]);
  }

  @override
  Future<void> clearAllData() async {
    final db = await _database.database;
    for (final table in [
      'devices',
      'device_connection_sessions',
      'metric_samples',
      'hourly_aggregate_summaries',
      'daily_aggregate_summaries',
      'heart_rate_records',
      'spo2_records',
      'step_records',
      'sleep_sessions',
      'daily_summaries',
    ]) {
      await db.delete(table);
    }
  }

  Future<void> _refreshAggregates(String deviceId, String metricType, DateTime timestamp) async {
    await _refreshAggregate(deviceId, metricType, _startOfHour(timestamp), 'hourly_aggregate_summaries');
    await _refreshAggregate(deviceId, metricType, AppDateUtils.startOfDay(timestamp), 'daily_aggregate_summaries');
  }

  Future<void> _refreshAggregate(
    String deviceId,
    String metricType,
    DateTime periodStart,
    String table,
  ) async {
    final db = await _database.database;
    final periodEnd = table.startsWith('hourly')
        ? periodStart.add(const Duration(hours: 1))
        : periodStart.add(const Duration(days: 1));
    final rows = await db.rawQuery('''
SELECT COUNT(*) sample_count, SUM(value_numeric) sum_value, AVG(value_numeric) avg_value,
       MIN(value_numeric) min_value, MAX(value_numeric) max_value, unit
FROM metric_samples
WHERE device_id = ? AND metric_type = ? AND timestamp >= ? AND timestamp < ? AND value_numeric IS NOT NULL
''', [deviceId, metricType, _database.millis(periodStart), _database.millis(periodEnd)]);
    final row = rows.first;
    final count = row['sample_count'] as int;
    if (count == 0) return;
    final latestRows = await db.query(
      'metric_samples',
      columns: ['value_numeric'],
      where: 'device_id = ? AND metric_type = ? AND timestamp >= ? AND timestamp < ? AND value_numeric IS NOT NULL',
      whereArgs: [deviceId, metricType, _database.millis(periodStart), _database.millis(periodEnd)],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    await db.insert(
      table,
      {
        'device_id': deviceId,
        'metric_type': metricType,
        'period_start': _database.millis(periodStart),
        'sample_count': count,
        'sum_value': (row['sum_value'] as num?)?.toDouble() ?? 0,
        'avg_value': (row['avg_value'] as num?)?.toDouble(),
        'min_value': (row['min_value'] as num?)?.toDouble(),
        'max_value': (row['max_value'] as num?)?.toDouble(),
        'latest_value': (latestRows.firstOrNull?['value_numeric'] as num?)?.toDouble(),
        'unit': row['unit'] as String?,
        'updated_at': _database.millis(DateTime.now()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  DateTime _startOfHour(DateTime value) => DateTime(value.year, value.month, value.day, value.hour);

  Future<DateTime?> _latestSampleTime() async {
    final db = await _database.database;
    final rows = await db.rawQuery('SELECT MAX(timestamp) latest_at FROM metric_samples');
    final value = rows.firstOrNull?['latest_at'];
    return value is int ? _database.date(value) : null;
  }
}
