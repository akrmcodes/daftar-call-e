import 'dart:async';

import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_provider.g.dart';

/// Manages the app theme mode and persists it to settings.
@riverpod
class Theme extends _$Theme {
  @override
  ThemeMode build() {
    final settings = ref.watch(appSettingsProvider).asData?.value;
    return _themeModeFromValue(settings?.themeMode);
  }

  /// Persists a new theme mode.
  void setThemeMode(ThemeMode mode) {
    final previousMode = state;
    state = mode;
    unawaited(_persistThemeMode(mode, previousMode));
  }

  /// Toggles between dark and light themes.
  void toggle() {
    setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> _persistThemeMode(
    ThemeMode mode,
    ThemeMode previousMode,
  ) async {
    final result = await ref
        .read(settingsRepositoryProvider)
        .update(
          UpdateSettingsParams(themeMode: _themeModeToValue(mode)),
        );

    result.fold(
      (_) => state = previousMode,
      (updatedSettings) =>
          state = _themeModeFromValue(updatedSettings.themeMode),
    );
  }
}

ThemeMode _themeModeFromValue(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
    default:
      return ThemeMode.system;
  }
}

String _themeModeToValue(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}
