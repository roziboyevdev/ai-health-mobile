# AI Health Mobile

Flutter app for smart bands and BLE wearables with Riverpod, go_router, Material 3, charts, and Android/iOS platform channels.

## Requirements

- Flutter stable
- Android Studio for Android builds
- Xcode and CocoaPods for iOS builds
- A real Android or iOS device for BLE testing
- Veepoo / HBand SDK binaries from the vendor repositories or your vendor package

## Open The Project

```bash
cd "F:\Codes\AI Health\ai-health-mobile"
flutter pub get
flutter run
```

## Android SDK Setup

The Android platform channel is wired in `MainActivity.kt` and Android permissions are declared in `AndroidManifest.xml`.

Download the Android SDK from:

- https://github.com/HBandSDK/Android_Ble_SDK
- https://github.com/HBandSDK/Android_Ble_SDK/blob/master/README_EN.md

Place required SDK files in:

```text
android/app/libs/
```

The official README lists these required binary dependencies:

```text
vpbluetooth-x.x.x.aar
vpprotocol-2.x.xx.xx.aar
gson-x.x.x.jar
JL_Watch_V1.13.1_11214-release.aar
jl_rcsp_V0.7.2_527-release.aar
jl_bt_ota_V1.10.0_10931-release.aar
BmpConvert_V1.6.0_10604-release.aar
abpartool-release.aar
```

Optional Goodix upgrade files can also be placed in the same folder if your device firmware requires them:

```text
libble-0.x.aar
libcomx-0.x.jar
libdfu-1.x.jar
libfastdfu-0.x.jar
```

Gradle already includes local `*.aar` and `*.jar` files from `android/app/libs/` plus Nordic scanner/OTA and LocalBroadcast dependencies.

## iOS SDK Setup

Download the iOS SDK from:

- https://github.com/HBandSDK/iOS_Ble_SDK
- https://github.com/HBandSDK/iOS_Ble_SDK/wiki/VeepooSDK-iOS-API-Document

Add the SDK framework/source files to `ios/Runner` in Xcode:

1. Open `ios/Runner.xcworkspace`.
2. Drag the Veepoo SDK framework or source folder into the Runner target.
3. Enable `CoreBluetooth.framework` if it is not linked automatically.
4. Confirm Bluetooth usage strings exist in `ios/Runner/Info.plist`.

## Architecture

```text
lib/
  core/
    constants/
    theme/
    utils/
    errors/
  data/
    models/
    repositories/
    datasources/
      ble/
      local/
  domain/
    entities/
    repositories/
  presentation/
    providers/
    screens/
    widgets/
    router/
  main.dart
```

## BLE Channel Contract

Flutter calls `uz.aihealth.mobile/hband_ble` and listens to:

- `uz.aihealth.mobile/hband_ble_scan`
- `uz.aihealth.mobile/hband_ble_connection`
- `uz.aihealth.mobile/hband_ble_health`

All BLE operations are serialized on the Flutter side and native side because the HBand SDK warns against running multiple heavy device operations at the same time.

The scan screen uses Bluetooth Low Energy advertisements, not the classic Bluetooth pairing list. It does not filter by Veepoo or HBand name, so other nearby BLE bracelets, watches and wearables can appear too.

## Android 16 KB Page Size

New Android devices can use 16 KB memory pages. If Android shows an app compatibility warning, rebuild after dependency updates:

```bash
flutter clean
flutter pub get
flutter run
```

For release verification, inspect the APK/AAB with Android Studio APK Analyzer or `zipalign -c -P 16 -v 4`.

## Verification

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
```

The iOS build command must be run on macOS.
