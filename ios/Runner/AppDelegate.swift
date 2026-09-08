import CoreBluetooth
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let bleBridge = HBandBleBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    bleBridge.register(with: engineBridge.applicationRegistrar.messenger())
  }
}

final class HBandBleBridge: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  private var centralManager: CBCentralManager!
  private var scanSink: FlutterEventSink?
  private var connectionSink: FlutterEventSink?
  private var healthSink: FlutterEventSink?
  private var selectedPeripheral: CBPeripheral?
  private var discovered: [UUID: CBPeripheral] = [:]
  private var pendingConnectResult: FlutterResult?
  private let queue = DispatchQueue(label: "uz.aihealth.mobile.hband.queue")

  override init() {
    super.init()
    centralManager = CBCentralManager(delegate: self, queue: queue)
  }

  func register(with messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(
      name: "uz.aihealth.mobile/hband_ble",
      binaryMessenger: messenger
    ).setMethodCallHandler(handle)

    FlutterEventChannel(
      name: "uz.aihealth.mobile/hband_ble_scan",
      binaryMessenger: messenger
    ).setStreamHandler(StreamHandler { self.scanSink = $0 })

    FlutterEventChannel(
      name: "uz.aihealth.mobile/hband_ble_connection",
      binaryMessenger: messenger
    ).setStreamHandler(StreamHandler { self.connectionSink = $0 })

    FlutterEventChannel(
      name: "uz.aihealth.mobile/hband_ble_health",
      binaryMessenger: messenger
    ).setStreamHandler(StreamHandler { self.healthSink = $0 })
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    queue.async {
      switch call.method {
      case "bleStatus":
        DispatchQueue.main.async {
          result([
            "bluetoothOn": self.centralManager.state == .poweredOn,
            "locationOn": true,
            "androidSdk": 0,
            "hasScanPermission": true,
            "hasConnectPermission": true
          ])
        }

      case "isBluetoothOn":
        DispatchQueue.main.async { result(self.centralManager.state == .poweredOn) }

      case "startScan":
        guard self.centralManager.state == .poweredOn else {
          DispatchQueue.main.async {
            result(FlutterError(code: "BLE_OFF", message: "Bluetooth is not powered on.", details: nil))
          }
          return
        }
        self.discovered.removeAll()
        self.centralManager.scanForPeripherals(
          withServices: nil,
          options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        self.emitConnection("scanning")
        DispatchQueue.main.async { result(nil) }

      case "stopScan":
        self.centralManager.stopScan()
        if self.selectedPeripheral == nil {
          self.emitConnection("disconnected")
        }
        DispatchQueue.main.async { result(nil) }

      case "connect":
        let args = call.arguments as? [String: Any]
        let device = args?["device"] as? [String: Any]
        let id = device?["id"] as? String ?? device?["macAddress"] as? String ?? ""
        guard let uuid = UUID(uuidString: id), let peripheral = self.discovered[uuid] else {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "BLE_CONNECT_FAILED",
              message: "Scan again, then tap Connect. The band must still be advertising.",
              details: nil
            ))
          }
          return
        }
        self.centralManager.stopScan()
        self.emitConnection("connecting")
        self.selectedPeripheral = peripheral
        self.pendingConnectResult = result
        peripheral.delegate = self
        self.centralManager.connect(peripheral, options: nil)
        self.queue.asyncAfter(deadline: .now() + 20) {
          guard self.pendingConnectResult != nil else { return }
          self.centralManager.cancelPeripheralConnection(peripheral)
          self.failConnect(
            code: "BLE_CONNECT_TIMEOUT",
            message: "Connection timed out. Put the band in pairing mode and try again."
          )
        }

      case "disconnect":
        if let peripheral = self.selectedPeripheral {
          self.centralManager.cancelPeripheralConnection(peripheral)
        }
        self.selectedPeripheral = nil
        self.emitConnection("disconnected")
        DispatchQueue.main.async { result(nil) }

      case "connectedDeviceInfo":
        DispatchQueue.main.async { result(self.currentDeviceMap()) }

      case "readBatteryLevel":
        DispatchQueue.main.async { result(NSNull()) }

      case "syncHealthHistory":
        DispatchQueue.main.async {
          result([
            "batteryLevel": NSNull(),
            "heartRate": [],
            "spo2": [],
            "steps": [],
            "sleep": []
          ])
        }

      default:
        DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
      }
    }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state != .poweredOn {
      emitConnection("disconnected")
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    discovered[peripheral.identifier] = peripheral
    let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
    let name = advertisedName ?? peripheral.name ?? "Unknown BLE wearable"
    DispatchQueue.main.async {
      self.scanSink?([
        "id": peripheral.identifier.uuidString,
        "name": name,
        "macAddress": peripheral.identifier.uuidString,
        "rssi": RSSI.intValue
      ])
    }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    emitConnection("connected")
    let pending = pendingConnectResult
    pendingConnectResult = nil
    DispatchQueue.main.async {
      pending?(self.currentDeviceMap() ?? [
        "deviceId": peripheral.identifier.uuidString,
        "name": peripheral.name ?? "HBand",
        "macAddress": peripheral.identifier.uuidString,
        "firmware": NSNull(),
        "model": "Smart band / BLE wearable",
        "batteryLevel": NSNull()
      ])
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Error?
  ) {
    failConnect(
      code: "BLE_CONNECT_FAILED",
      message: error?.localizedDescription ?? "Could not connect to this BLE device."
    )
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    if selectedPeripheral?.identifier == peripheral.identifier {
      selectedPeripheral = nil
      emitConnection("disconnected")
    }
  }

  private func currentDeviceMap() -> [String: Any]? {
    guard let peripheral = selectedPeripheral else { return nil }
    return [
      "deviceId": peripheral.identifier.uuidString,
      "name": peripheral.name ?? "HBand",
      "macAddress": peripheral.identifier.uuidString,
      "firmware": NSNull(),
      "model": "Smart band / BLE wearable",
      "batteryLevel": NSNull()
    ]
  }

  private func failConnect(code: String, message: String) {
    let pending = pendingConnectResult
    pendingConnectResult = nil
    selectedPeripheral = nil
    emitConnection("disconnected")
    DispatchQueue.main.async {
      pending?(FlutterError(code: code, message: message, details: nil))
    }
  }

  private func emitConnection(_ state: String) {
    DispatchQueue.main.async { self.connectionSink?(state) }
  }
}

final class StreamHandler: NSObject, FlutterStreamHandler {
  private let assign: (FlutterEventSink?) -> Void

  init(_ assign: @escaping (FlutterEventSink?) -> Void) {
    self.assign = assign
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    assign(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    assign(nil)
    return nil
  }
}
