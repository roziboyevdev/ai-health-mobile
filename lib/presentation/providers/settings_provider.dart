import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/constants/app_constants.dart';

enum AppLanguage { uz, ru }

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.language = AppLanguage.uz,
    this.autoReconnect = true,
    this.syncOnConnect = true,
    this.showAllBleDevices = false,
    this.devicePassword = AppConstants.defaultDevicePassword,
  });

  final ThemeMode themeMode;
  final AppLanguage language;
  final bool autoReconnect;
  final bool syncOnConnect;
  final bool showAllBleDevices;
  final String devicePassword;

  AppSettings copyWith({
    ThemeMode? themeMode,
    AppLanguage? language,
    bool? autoReconnect,
    bool? syncOnConnect,
    bool? showAllBleDevices,
    String? devicePassword,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      syncOnConnect: syncOnConnect ?? this.syncOnConnect,
      showAllBleDevices: showAllBleDevices ?? this.showAllBleDevices,
      devicePassword: devicePassword ?? this.devicePassword,
    );
  }
}

final settingsNotifierProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsNotifierProvider.select((settings) => settings.themeMode));
});

final appLanguageProvider = Provider<AppLanguage>((ref) {
  return ref.watch(settingsNotifierProvider.select((settings) => settings.language));
});

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);

  void setLanguage(AppLanguage language) => state = state.copyWith(language: language);

  void setAutoReconnect(bool value) => state = state.copyWith(autoReconnect: value);

  void setSyncOnConnect(bool value) => state = state.copyWith(syncOnConnect: value);

  void setShowAllBleDevices(bool value) => state = state.copyWith(showAllBleDevices: value);

  void setDevicePassword(String value) {
    state = state.copyWith(
      devicePassword: value.trim().isEmpty ? AppConstants.defaultDevicePassword : value.trim(),
    );
  }
}
