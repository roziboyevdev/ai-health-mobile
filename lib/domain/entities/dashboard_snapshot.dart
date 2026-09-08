import '../../data/models/daily_summary.dart';
import '../../data/models/device.dart';
import '../../data/models/heart_rate_record.dart';
import '../../data/models/sleep_session.dart';
import '../../data/models/spo2_record.dart';
import '../../data/models/step_record.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    this.device,
    this.summary,
    this.latestHeartRate,
    this.latestSpO2,
    this.latestSleep,
    this.latestSteps,
  });

  final Device? device;
  final DailySummary? summary;
  final HeartRateRecord? latestHeartRate;
  final SpO2Record? latestSpO2;
  final SleepSession? latestSleep;
  final StepRecord? latestSteps;
}
