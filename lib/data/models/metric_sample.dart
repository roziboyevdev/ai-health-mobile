import 'dart:convert';

class MetricSample {
  MetricSample({
    this.id = 0,
    required this.deviceId,
    required this.metricType,
    required this.timestamp,
    this.valueNumeric,
    this.valueText,
    this.unit,
    this.rawPayload,
    String? payloadHash,
    DateTime? createdAt,
  })  : payloadHash = payloadHash ?? stablePayloadHash(rawPayload),
        createdAt = createdAt ?? DateTime.now();

  int id;
  String deviceId;
  String metricType;
  DateTime timestamp;
  double? valueNumeric;
  String? valueText;
  String? unit;
  Map<String, Object?>? rawPayload;
  String payloadHash;
  DateTime createdAt;

  static String stablePayloadHash(Map<String, Object?>? payload) {
    if (payload == null || payload.isEmpty) return '';
    final normalized = _normalize(payload);
    return _fnv1a32(jsonEncode(normalized));
  }

  static Object? _normalize(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return {
        for (final entry in entries) entry.key.toString(): _normalize(entry.value),
      };
    }
    if (value is Iterable) {
      return [for (final item in value) _normalize(item)];
    }
    if (value is DateTime) return value.toUtc().toIso8601String();
    return value;
  }

  static String _fnv1a32(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class MetricAggregate {
  const MetricAggregate({
    required this.metricType,
    required this.periodStart,
    required this.sampleCount,
    required this.sum,
    this.average,
    this.min,
    this.max,
    this.latest,
    this.unit,
  });

  final String metricType;
  final DateTime periodStart;
  final int sampleCount;
  final double sum;
  final double? average;
  final double? min;
  final double? max;
  final double? latest;
  final String? unit;
}

class MonthMetricStats {
  const MonthMetricStats({
    required this.metricType,
    required this.sampleCount,
    required this.total,
    this.average,
    this.min,
    this.max,
    this.latest,
    this.previousTotal,
    this.trendDelta,
    this.unit,
  });

  final String metricType;
  final int sampleCount;
  final double total;
  final double? average;
  final double? min;
  final double? max;
  final double? latest;
  final double? previousTotal;
  final double? trendDelta;
  final String? unit;
}
