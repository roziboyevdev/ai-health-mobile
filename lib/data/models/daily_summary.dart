class DailySummary {
  int id = 0;
  late String deviceId;
  late DateTime date;
  int steps = 0;
  int? restingHeartRate;
  int? averageSpO2;
  int sleepMinutes = 0;
  int? hrv;
  DateTime updatedAt = DateTime.now();
}
