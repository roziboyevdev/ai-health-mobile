import '../../data/models/daily_summary.dart';
import '../../data/models/device.dart';
import '../../data/models/heart_rate_record.dart';
import '../../data/models/metric_sample.dart';
import '../../data/models/sleep_session.dart';
import '../../data/models/spo2_record.dart';
import '../../data/models/step_record.dart';
import '../entities/dashboard_snapshot.dart';

abstract interface class HealthRepository {
  Future<void> upsertDevice(Device device);
  Future<Device?> connectedDevice();
  Future<List<Device>> devices();
  Future<void> markAllDisconnected();
  Future<void> recordConnectionSession({
    required String deviceId,
    required DateTime startedAt,
    DateTime? endedAt,
    String status = 'connected',
    String? errorMessage,
  });
  Future<bool> saveMetricSample(MetricSample sample);
  Future<void> saveMetricSamples(Iterable<MetricSample> samples);
  Future<void> saveHeartRate(HeartRateRecord record);
  Future<void> saveSpO2(SpO2Record record);
  Future<void> saveSteps(StepRecord record);
  Future<void> saveSleep(SleepSession session);
  Future<void> upsertDailySummary(DailySummary summary);
  Future<DashboardSnapshot> dashboardSnapshot();
  Future<Map<String, MonthMetricStats>> monthStats({int days = 30});
  Future<List<MetricSample>> metricHistory(String metricType, {int days = 30});
  Future<List<HeartRateRecord>> heartRateHistory({int days = 7});
  Future<List<SpO2Record>> spo2History({int days = 7});
  Future<List<StepRecord>> stepHistory({int days = 14});
  Future<List<SleepSession>> sleepHistory({int days = 14});
  Future<void> pruneOldData({int days = 30});
  Future<void> clearAllData();
}
