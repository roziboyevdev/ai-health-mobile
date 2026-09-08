class Device {
  int id = 0;
  late String deviceId;
  late String name;
  String? macAddress;
  String? firmware;
  String? model;
  int? batteryLevel;
  bool isConnected = false;
  bool autoReconnect = true;
  DateTime? lastSeenAt;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}
