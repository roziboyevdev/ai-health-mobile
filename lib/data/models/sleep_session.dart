enum SleepStageType { awake, light, deep, rem }

class SleepStage {
  SleepStage({
    this.type = SleepStageType.light,
    DateTime? startedAt,
    DateTime? endedAt,
  })  : startedAt = startedAt ?? DateTime.now(),
        endedAt = endedAt ?? DateTime.now();

  SleepStageType type;
  DateTime startedAt;
  DateTime endedAt;
}

class SleepSession {
  int id = 0;
  late String deviceId;
  late DateTime startedAt;
  late DateTime endedAt;
  int totalMinutes = 0;
  int deepMinutes = 0;
  int lightMinutes = 0;
  int remMinutes = 0;
  int awakeMinutes = 0;
  List<SleepStage> stages = [];
}
