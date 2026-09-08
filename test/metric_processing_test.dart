import 'package:ai_health_mobile/data/models/metric_sample.dart';
import 'package:ai_health_mobile/data/services/metric_processing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes all live bracelet metrics', () {
    final samples = MetricNormalizer.fromLivePayload(
      deviceId: 'band-1',
      recordedAt: DateTime.utc(2026, 9, 8, 10),
      heartRate: 72,
      spo2: 98,
      steps: 1200,
      hrv: 44,
      batteryLevel: 85,
    );

    expect(samples.map((sample) => sample.metricType), [
      'heart_rate',
      'spo2',
      'steps',
      'hrv',
      'battery',
    ]);
  });

  test('uses stable payload hashes for duplicate prevention keys', () {
    final first = MetricSample(
      deviceId: 'band-1',
      metricType: 'heart_rate',
      timestamp: DateTime.utc(2026, 9, 8, 10),
      valueNumeric: 72,
      rawPayload: {'bpm': 72, 'source': 'live'},
    );
    final second = MetricSample(
      deviceId: 'band-1',
      metricType: 'heart_rate',
      timestamp: DateTime.utc(2026, 9, 8, 10),
      valueNumeric: 72,
      rawPayload: {'source': 'live', 'bpm': 72},
    );

    expect(first.payloadHash, second.payloadHash);
  });

  test('retains only 30 days of samples', () {
    const policy = RetentionPolicy();
    final now = DateTime.utc(2026, 9, 8);

    expect(policy.shouldRetain(DateTime.utc(2026, 8, 9), now), isTrue);
    expect(policy.shouldRetain(DateTime.utc(2026, 8, 8, 23, 59), now), isFalse);
  });

  test('calculates aggregate totals, average, min, max and latest', () {
    final stats = MetricStatsCalculator.calculate('steps', [
      MetricSample(
        deviceId: 'band-1',
        metricType: 'steps',
        timestamp: DateTime.utc(2026, 9, 6),
        valueNumeric: 1000,
        unit: 'steps',
      ),
      MetricSample(
        deviceId: 'band-1',
        metricType: 'steps',
        timestamp: DateTime.utc(2026, 9, 7),
        valueNumeric: 3000,
        unit: 'steps',
      ),
    ]);

    expect(stats.total, 4000);
    expect(stats.average, 2000);
    expect(stats.min, 1000);
    expect(stats.max, 3000);
    expect(stats.latest, 3000);
  });
}
