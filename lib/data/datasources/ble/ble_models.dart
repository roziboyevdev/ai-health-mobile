enum BleConnectionStateType { disconnected, scanning, connecting, connected }

class BleDevice {
  const BleDevice({
    required this.id,
    required this.name,
    this.macAddress,
    this.rssi,
  });

  final String id;
  final String name;
  final String? macAddress;
  final int? rssi;

  bool get isValdusFamily {
    final normalized = name.toLowerCase();
    return normalized.contains('vitro') ||
        normalized.contains('vanta') ||
        normalized.contains('valdus') ||
        normalized.contains('hband') ||
        normalized.contains('g-band') ||
        normalized.contains('g band') ||
        normalized.contains('gband');
  }

  factory BleDevice.fromMap(Map<dynamic, dynamic> map) {
    return BleDevice(
      id: map['id'] as String? ?? map['macAddress'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown band',
      macAddress: map['macAddress'] as String?,
      rssi: _asInt(map['rssi']),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'macAddress': macAddress,
        'rssi': rssi,
      };
}

class BleDeviceInfo {
  const BleDeviceInfo({
    required this.deviceId,
    required this.name,
    this.macAddress,
    this.firmware,
    this.model,
    this.batteryLevel,
  });

  final String deviceId;
  final String name;
  final String? macAddress;
  final String? firmware;
  final String? model;
  final int? batteryLevel;

  factory BleDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return BleDeviceInfo(
      deviceId: map['deviceId'] as String? ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'HBand',
      macAddress: map['macAddress'] as String?,
      firmware: map['firmware'] as String?,
      model: map['model'] as String?,
      batteryLevel: _asInt(map['batteryLevel']),
    );
  }
}

class BleStatus {
  const BleStatus({
    required this.bluetoothOn,
    required this.locationOn,
    required this.androidSdk,
    required this.hasScanPermission,
    required this.hasConnectPermission,
  });

  final bool bluetoothOn;
  final bool locationOn;
  final int androidSdk;
  final bool hasScanPermission;
  final bool hasConnectPermission;

  factory BleStatus.fromMap(Map<dynamic, dynamic> map) {
    return BleStatus(
      bluetoothOn: map['bluetoothOn'] == true,
      locationOn: map['locationOn'] == true,
      androidSdk: _asInt(map['androidSdk']) ?? 0,
      hasScanPermission: map['hasScanPermission'] == true,
      hasConnectPermission: map['hasConnectPermission'] == true,
    );
  }
}

class HealthSyncResult {
  const HealthSyncResult({
    this.batteryLevel,
    this.heartRate = const [],
    this.spo2 = const [],
    this.steps = const [],
    this.sleep = const [],
  });

  final int? batteryLevel;
  final List<HeartRateSample> heartRate;
  final List<SpO2Sample> spo2;
  final List<StepSample> steps;
  final List<SleepSample> sleep;

  factory HealthSyncResult.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const HealthSyncResult();
    return HealthSyncResult(
      batteryLevel: _asInt(map['batteryLevel']),
      heartRate: _asList(map['heartRate']).map(HeartRateSample.fromMap).toList(),
      spo2: _asList(map['spo2']).map(SpO2Sample.fromMap).toList(),
      steps: _asList(map['steps']).map(StepSample.fromMap).toList(),
      sleep: _asList(map['sleep']).map(SleepSample.fromMap).toList(),
    );
  }
}

class HeartRateSample {
  const HeartRateSample({required this.recordedAt, required this.bpm});

  final DateTime recordedAt;
  final int bpm;

  factory HeartRateSample.fromMap(dynamic raw) {
    final map = Map<dynamic, dynamic>.from(raw as Map);
    return HeartRateSample(
      recordedAt: DateTime.tryParse(map['recordedAt'] as String? ?? '') ?? DateTime.now(),
      bpm: _asInt(map['bpm']) ?? 0,
    );
  }
}

class SpO2Sample {
  const SpO2Sample({required this.recordedAt, required this.percentage});

  final DateTime recordedAt;
  final int percentage;

  factory SpO2Sample.fromMap(dynamic raw) {
    final map = Map<dynamic, dynamic>.from(raw as Map);
    return SpO2Sample(
      recordedAt: DateTime.tryParse(map['recordedAt'] as String? ?? '') ?? DateTime.now(),
      percentage: _asInt(map['percentage']) ?? 0,
    );
  }
}

class StepSample {
  const StepSample({
    required this.date,
    required this.steps,
    this.distanceKm = 0,
    this.calories = 0,
  });

  final DateTime date;
  final int steps;
  final double distanceKm;
  final int calories;

  factory StepSample.fromMap(dynamic raw) {
    final map = Map<dynamic, dynamic>.from(raw as Map);
    return StepSample(
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      steps: _asInt(map['steps']) ?? 0,
      distanceKm: _asDouble(map['distanceKm']) ?? 0,
      calories: _asInt(map['calories']) ?? 0,
    );
  }
}

class SleepSample {
  const SleepSample({
    required this.startedAt,
    required this.endedAt,
    this.totalMinutes = 0,
    this.deepMinutes = 0,
    this.lightMinutes = 0,
    this.remMinutes = 0,
    this.awakeMinutes = 0,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int totalMinutes;
  final int deepMinutes;
  final int lightMinutes;
  final int remMinutes;
  final int awakeMinutes;

  factory SleepSample.fromMap(dynamic raw) {
    final map = Map<dynamic, dynamic>.from(raw as Map);
    return SleepSample(
      startedAt: DateTime.tryParse(map['startedAt'] as String? ?? '') ?? DateTime.now(),
      endedAt: DateTime.tryParse(map['endedAt'] as String? ?? '') ?? DateTime.now(),
      totalMinutes: _asInt(map['totalMinutes']) ?? 0,
      deepMinutes: _asInt(map['deepMinutes']) ?? 0,
      lightMinutes: _asInt(map['lightMinutes']) ?? 0,
      remMinutes: _asInt(map['remMinutes']) ?? 0,
      awakeMinutes: _asInt(map['awakeMinutes']) ?? 0,
    );
  }
}

class RealTimeHealthData {
  const RealTimeHealthData({
    required this.recordedAt,
    this.heartRate,
    this.spo2,
    this.steps,
    this.hrv,
    this.batteryLevel,
  });

  final DateTime recordedAt;
  final int? heartRate;
  final int? spo2;
  final int? steps;
  final int? hrv;
  final int? batteryLevel;

  factory RealTimeHealthData.fromMap(Map<dynamic, dynamic> map) {
    return RealTimeHealthData(
      recordedAt: DateTime.tryParse(map['recordedAt'] as String? ?? '') ?? DateTime.now(),
      heartRate: _asInt(map['heartRate']),
      spo2: _asInt(map['spo2']),
      steps: _asInt(map['steps']),
      hrv: _asInt(map['hrv']),
      batteryLevel: _asInt(map['batteryLevel']),
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

List<dynamic> _asList(Object? value) {
  if (value is List) return value;
  return const [];
}
