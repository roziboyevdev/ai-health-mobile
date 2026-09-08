import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import 'ble_models.dart';
import 'ble_service.dart';

class MethodChannelBleService implements BleService {
  MethodChannelBleService({
    MethodChannel? methodChannel,
    EventChannel? scanChannel,
    EventChannel? connectionChannel,
    EventChannel? healthChannel,
  })  : _methodChannel = methodChannel ?? const MethodChannel(AppConstants.bleMethodChannel),
        _scanChannel = scanChannel ?? const EventChannel(AppConstants.bleScanEventChannel),
        _connectionChannel =
            connectionChannel ?? const EventChannel(AppConstants.bleConnectionEventChannel),
        _healthChannel = healthChannel ?? const EventChannel(AppConstants.bleHealthEventChannel);

  final MethodChannel _methodChannel;
  final EventChannel _scanChannel;
  final EventChannel _connectionChannel;
  final EventChannel _healthChannel;
  Future<void> _operationQueue = Future.value();

  @override
  Stream<BleDevice> get scanResults => _scanChannel
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => BleDevice.fromMap(event as Map<dynamic, dynamic>));

  @override
  Stream<BleConnectionStateType> get connectionState => _connectionChannel
      .receiveBroadcastStream()
      .map((event) => BleConnectionStateType.values.firstWhere(
            (state) => state.name == event,
            orElse: () => BleConnectionStateType.disconnected,
          ));

  @override
  Stream<RealTimeHealthData> get realTimeHealth => _healthChannel
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => RealTimeHealthData.fromMap(event as Map<dynamic, dynamic>));

  @override
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      return true;
    }

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
      Permission.locationWhenInUse,
    ].request();
    final scan = statuses[Permission.bluetoothScan] ?? PermissionStatus.denied;
    final connect = statuses[Permission.bluetoothConnect] ?? PermissionStatus.denied;
    final location = statuses[Permission.locationWhenInUse] ?? PermissionStatus.denied;

    final scanOk = scan.isGranted || scan.isLimited;
    final connectOk = connect.isGranted || connect.isLimited;
    final locationOk = location.isGranted || location.isLimited;

    if (scanOk && connectOk) return true;
    if (locationOk) return true;

    if (scan.isPermanentlyDenied || connect.isPermanentlyDenied || location.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  @override
  Future<BleStatus> bleStatus() async {
    final result = await _invokeQueued<dynamic>('bleStatus');
    if (result is Map) {
      return BleStatus.fromMap(Map<dynamic, dynamic>.from(result));
    }
    return BleStatus.fromMap(const {});
  }

  @override
  Future<void> startScan() => _invokeQueued('startScan');

  @override
  Future<void> stopScan() => _invokeQueued('stopScan');

  @override
  Future<BleDeviceInfo> connect(BleDevice device, {String password = '0000'}) {
    return _invokeQueued<dynamic>(
      'connect',
      {'device': device.toMap(), 'password': password},
    ).then((result) => BleDeviceInfo.fromMap(Map<dynamic, dynamic>.from(result as Map)));
  }

  @override
  Future<void> disconnect() => _invokeQueued('disconnect');

  @override
  Future<BleDeviceInfo?> connectedDeviceInfo() async {
    final result = await _invokeQueued<dynamic>('connectedDeviceInfo');
    if (result is Map) {
      return BleDeviceInfo.fromMap(Map<dynamic, dynamic>.from(result));
    }
    return null;
  }

  @override
  Future<int?> readBatteryLevel() => _invokeQueued<int?>('readBatteryLevel');

  @override
  Future<HealthSyncResult> syncHealthHistory() async {
    final result = await _invokeQueued<dynamic>('syncHealthHistory');
    if (result is Map) {
      return HealthSyncResult.fromMap(Map<dynamic, dynamic>.from(result));
    }
    return const HealthSyncResult();
  }

  Future<T> _invokeQueued<T>(String method, [Object? arguments]) {
    final completer = Completer<T>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        final result = await _methodChannel.invokeMethod<dynamic>(method, arguments);
        completer.complete(result as T);
      } on PlatformException catch (error) {
        completer.completeError(
          AppException(_friendlyMessage(error), code: error.code),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  String _friendlyMessage(PlatformException error) {
    switch (error.code) {
      case 'BLE_OFF':
        return 'Bluetooth is turned off. Enable Bluetooth and try again.';
      case 'LOCATION_OFF':
        return 'Location services must be on to scan for nearby bands.';
      case 'BLE_SCAN_PERMISSION':
      case 'BLE_CONNECT_PERMISSION':
        return 'Bluetooth permissions are required. Allow them in system settings.';
      case 'BLE_PASSWORD':
        return 'The band password is incorrect. Check Settings and try again.';
      case 'BLE_CONNECT_TIMEOUT':
        return error.message ??
            'Connection timed out. Put the band in pairing mode and keep it close.';
      case 'BLE_CONNECT_FAILED':
        return error.message ??
            'Could not connect. This device may not support the Veepoo/VALDUS protocol.';
      case 'BLE_NOT_CONNECTED':
        return 'No band is connected.';
      case 'BLE_NOT_READY':
        return 'Bluetooth is not ready. Turn it on and retry.';
      default:
        return error.message ?? 'Bluetooth operation failed';
    }
  }
}
