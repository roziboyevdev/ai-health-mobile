import '../models/metric_sample.dart';

class RetentionPolicy {
  const RetentionPolicy({this.days = 30});

  final int days;

  bool shouldRetain(DateTime timestamp, DateTime now) {
    return !timestamp.isBefore(now.subtract(Duration(days: days)));
  }
}

class MetricStatsCalculator {
  const MetricStatsCalculator._();

  static MonthMetricStats calculate(String metricType, List<MetricSample> samples) {
    final numeric = samples.where((sample) => sample.valueNumeric != null).toList();
    if (numeric.isEmpty) {
      return MonthMetricStats(metricType: metricType, sampleCount: 0, total: 0);
    }
    final values = numeric.map((sample) => sample.valueNumeric!).toList();
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    return MonthMetricStats(
      metricType: metricType,
      sampleCount: numeric.length,
      total: total,
      average: total / numeric.length,
      min: min,
      max: max,
      latest: numeric.last.valueNumeric,
      unit: numeric.last.unit,
    );
  }
}

class MetricNormalizer {
  const MetricNormalizer._();

  static List<MetricSample> fromLivePayload({
    required String deviceId,
    required DateTime recordedAt,
    int? heartRate,
    int? spo2,
    int? steps,
    int? hrv,
    int? batteryLevel,
  }) {
    return [
      if (heartRate != null)
        MetricSample(
          deviceId: deviceId,
          metricType: 'heart_rate',
          timestamp: recordedAt,
          valueNumeric: heartRate.toDouble(),
          unit: 'bpm',
          rawPayload: {'heartRate': heartRate},
        ),
      if (spo2 != null)
        MetricSample(
          deviceId: deviceId,
          metricType: 'spo2',
          timestamp: recordedAt,
          valueNumeric: spo2.toDouble(),
          unit: '%',
          rawPayload: {'spo2': spo2},
        ),
      if (steps != null)
        MetricSample(
          deviceId: deviceId,
          metricType: 'steps',
          timestamp: recordedAt,
          valueNumeric: steps.toDouble(),
          unit: 'steps',
          rawPayload: {'steps': steps},
        ),
      if (hrv != null)
        MetricSample(
          deviceId: deviceId,
          metricType: 'hrv',
          timestamp: recordedAt,
          valueNumeric: hrv.toDouble(),
          unit: 'ms',
          rawPayload: {'hrv': hrv},
        ),
      if (batteryLevel != null)
        MetricSample(
          deviceId: deviceId,
          metricType: 'battery',
          timestamp: recordedAt,
          valueNumeric: batteryLevel.toDouble(),
          unit: '%',
          rawPayload: {'batteryLevel': batteryLevel},
        ),
    ];
  }
}
