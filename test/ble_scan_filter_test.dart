import 'package:ai_health_mobile/data/datasources/ble/ble_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BleDevice device({
    required String name,
    String id = 'AA:BB',
    int? rssi = -60,
  }) {
    return BleDevice(id: id, name: name, macAddress: id, rssi: rssi);
  }

  test('keeps VALDUS family names even when far away', () {
    expect(
      device(name: 'VITRO', rssi: -90).shouldShowInScan(knownIds: {}),
      isTrue,
    );
    expect(
      device(name: 'VANTA', rssi: -88).shouldShowInScan(knownIds: {}),
      isTrue,
    );
  });

  test('keeps previously paired MAC even with a generic name', () {
    expect(
      device(name: 'Redmi Note', id: '11:22:33').shouldShowInScan(knownIds: {'11:22:33'}),
      isTrue,
    );
  });

  test('hides phones headphones and unnamed room-level BLE', () {
    expect(device(name: 'iPhone 15').shouldShowInScan(knownIds: {}), isFalse);
    expect(device(name: 'AirPods Pro').shouldShowInScan(knownIds: {}), isFalse);
    expect(
      device(name: 'Unknown BLE wearable', rssi: -70).shouldShowInScan(knownIds: {}),
      isFalse,
    );
  });

  test('keeps unnamed only when held very close', () {
    expect(
      device(name: 'Unknown BLE wearable', rssi: -48).shouldShowInScan(knownIds: {}),
      isTrue,
    );
  });
}
