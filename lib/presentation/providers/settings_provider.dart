import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/constants/app_constants.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.autoReconnect = true,
    this.syncOnConnect = true,
    this.devicePassword = AppConstants.defaultDevicePassword,
  });

  final ThemeMode themeMode;
  final bool autoReconnect;
  final bool syncOnConnect;
  final String devicePassword;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? autoReconnect,
    bool? syncOnConnect,
    String? devicePassword,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      syncOnConnect: syncOnConnect ?? this.syncOnConnect,
      devicePassword: devicePassword ?? this.devicePassword,
    );
  }
}

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsNotifierProvider).themeMode;
});

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);

  void setAutoReconnect(bool value) => state = state.copyWith(autoReconnect: value);

  void setSyncOnConnect(bool value) => state = state.copyWith(syncOnConnect: value);

  void setDevicePassword(String value) {
    state = state.copyWith(
      devicePassword: value.trim().isEmpty ? AppConstants.defaultDevicePassword : value.trim(),
    );
  }
}
