import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/utils/date_utils.dart';
import '../../models/daily_summary.dart';
import '../../models/device.dart';
import '../../models/metric_sample.dart';

class AppDatabase {
  AppDatabase._();

  static final instance = AppDatabase._();
  static const retentionDays = 30;

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final db = await openDatabase(
      p.join(dir.path, 'ai_health.sqlite'),
      version: 1,
      onCreate: _create,
    );
    _db = db;
    return db;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
CREATE TABLE devices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  mac_address TEXT,
  firmware TEXT,
  model TEXT,
  battery_level INTEGER,
  is_connected INTEGER NOT NULL DEFAULT 0,
  auto_reconnect INTEGER NOT NULL DEFAULT 1,
  last_seen_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''');
    await db.execute('''
CREATE TABLE device_connection_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  ended_at INTEGER,
  status TEXT NOT NULL,
  error_message TEXT
)''');
    await db.execute('''
CREATE TABLE metric_samples (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  metric_type TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  value_numeric REAL,
  value_text TEXT,
  unit TEXT,
  raw_payload TEXT,
  payload_hash TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL
)''');
    await db.execute('''
CREATE UNIQUE INDEX metric_samples_unique_sample
ON metric_samples(device_id, metric_type, timestamp, payload_hash)''');
    await db.execute('''
CREATE TABLE hourly_aggregate_summaries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  metric_type TEXT NOT NULL,
  period_start INTEGER NOT NULL,
  sample_count INTEGER NOT NULL,
  sum_value REAL NOT NULL,
  avg_value REAL,
  min_value REAL,
  max_value REAL,
  latest_value REAL,
  unit TEXT,
  updated_at INTEGER NOT NULL,
  UNIQUE(device_id, metric_type, period_start)
)''');
    await db.execute('''
CREATE TABLE daily_aggregate_summaries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  metric_type TEXT NOT NULL,
  period_start INTEGER NOT NULL,
  sample_count INTEGER NOT NULL,
  sum_value REAL NOT NULL,
  avg_value REAL,
  min_value REAL,
  max_value REAL,
  latest_value REAL,
  unit TEXT,
  updated_at INTEGER NOT NULL,
  UNIQUE(device_id, metric_type, period_start)
)''');
    await db.execute('''
CREATE TABLE heart_rate_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  recorded_at INTEGER NOT NULL,
  bpm INTEGER NOT NULL,
  is_realtime INTEGER NOT NULL DEFAULT 0,
  UNIQUE(device_id, recorded_at, bpm, is_realtime)
)''');
    await db.execute('''
CREATE TABLE spo2_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  recorded_at INTEGER NOT NULL,
  percentage INTEGER NOT NULL,
  is_realtime INTEGER NOT NULL DEFAULT 0,
  UNIQUE(device_id, recorded_at, percentage, is_realtime)
)''');
    await db.execute('''
CREATE TABLE step_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  date INTEGER NOT NULL,
  steps INTEGER NOT NULL,
  distance_km REAL NOT NULL DEFAULT 0,
  calories INTEGER NOT NULL DEFAULT 0,
  UNIQUE(device_id, date)
)''');
    await db.execute('''
CREATE TABLE sleep_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  ended_at INTEGER NOT NULL,
  total_minutes INTEGER NOT NULL,
  deep_minutes INTEGER NOT NULL DEFAULT 0,
  light_minutes INTEGER NOT NULL DEFAULT 0,
  rem_minutes INTEGER NOT NULL DEFAULT 0,
  awake_minutes INTEGER NOT NULL DEFAULT 0,
  UNIQUE(device_id, started_at, ended_at)
)''');
    await db.execute('''
CREATE TABLE daily_summaries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  date INTEGER NOT NULL,
  steps INTEGER NOT NULL DEFAULT 0,
  resting_heart_rate INTEGER,
  average_spo2 INTEGER,
  sleep_minutes INTEGER NOT NULL DEFAULT 0,
  hrv INTEGER,
  updated_at INTEGER NOT NULL,
  UNIQUE(device_id, date)
)''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  int millis(DateTime date) => date.toUtc().millisecondsSinceEpoch;
  DateTime date(int millis) => DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();

  Map<String, Object?> deviceToMap(Device device) {
    final now = DateTime.now();
    return {
      'device_id': device.deviceId,
      'name': device.name,
      'mac_address': device.macAddress,
      'firmware': device.firmware,
      'model': device.model,
      'battery_level': device.batteryLevel,
      'is_connected': device.isConnected ? 1 : 0,
      'auto_reconnect': device.autoReconnect ? 1 : 0,
      'last_seen_at': device.lastSeenAt == null ? null : millis(device.lastSeenAt!),
      'created_at': millis(device.createdAt),
      'updated_at': millis(now),
    };
  }

  Device deviceFromMap(Map<String, Object?> map) => Device()
    ..id = map['id'] as int
    ..deviceId = map['device_id'] as String
    ..name = map['name'] as String
    ..macAddress = map['mac_address'] as String?
    ..firmware = map['firmware'] as String?
    ..model = map['model'] as String?
    ..batteryLevel = map['battery_level'] as int?
    ..isConnected = (map['is_connected'] as int? ?? 0) == 1
    ..autoReconnect = (map['auto_reconnect'] as int? ?? 1) == 1
    ..lastSeenAt = _optionalDate(map['last_seen_at'])
    ..createdAt = date(map['created_at'] as int)
    ..updatedAt = date(map['updated_at'] as int);

  Map<String, Object?> metricSampleToMap(MetricSample sample) => {
        'device_id': sample.deviceId,
        'metric_type': sample.metricType,
        'timestamp': millis(sample.timestamp),
        'value_numeric': sample.valueNumeric,
        'value_text': sample.valueText,
        'unit': sample.unit,
        'raw_payload': sample.rawPayload == null ? null : jsonEncode(sample.rawPayload),
        'payload_hash': sample.payloadHash,
        'created_at': millis(sample.createdAt),
      };

  MetricSample metricSampleFromMap(Map<String, Object?> map) => MetricSample(
        id: map['id'] as int,
        deviceId: map['device_id'] as String,
        metricType: map['metric_type'] as String,
        timestamp: date(map['timestamp'] as int),
        valueNumeric: (map['value_numeric'] as num?)?.toDouble(),
        valueText: map['value_text'] as String?,
        unit: map['unit'] as String?,
        rawPayload: _decodePayload(map['raw_payload'] as String?),
        payloadHash: map['payload_hash'] as String? ?? '',
        createdAt: date(map['created_at'] as int),
      );

  Map<String, Object?> dailySummaryToMap(DailySummary summary) => {
        'device_id': summary.deviceId,
        'date': millis(AppDateUtils.startOfDay(summary.date)),
        'steps': summary.steps,
        'resting_heart_rate': summary.restingHeartRate,
        'average_spo2': summary.averageSpO2,
        'sleep_minutes': summary.sleepMinutes,
        'hrv': summary.hrv,
        'updated_at': millis(summary.updatedAt),
      };

  DailySummary dailySummaryFromMap(Map<String, Object?> map) => DailySummary()
    ..id = map['id'] as int
    ..deviceId = map['device_id'] as String
    ..date = date(map['date'] as int)
    ..steps = map['steps'] as int
    ..restingHeartRate = map['resting_heart_rate'] as int?
    ..averageSpO2 = map['average_spo2'] as int?
    ..sleepMinutes = map['sleep_minutes'] as int
    ..hrv = map['hrv'] as int?
    ..updatedAt = date(map['updated_at'] as int);

  DateTime? _optionalDate(Object? value) => value is int ? date(value) : null;

  Map<String, Object?>? _decodePayload(String? value) {
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value as Object?));
    }
    return null;
  }
}
