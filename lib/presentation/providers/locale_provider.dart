import 'dart:async';
import 'dart:ui' as ui;

import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_provider.g.dart';

/// Manages the app locale and persists it to settings.
@riverpod
class Locale extends _$Locale {
  @override
  ui.Locale build() {
    final settings = ref.watch(appSettingsProvider).asData?.value;
    return _localeFromValue(settings?.locale);
  }

  /// Persists a new locale.
  void setLocale(ui.Locale locale) {
    final previousLocale = state;
    state = locale;
    unawaited(_persistLocale(locale, previousLocale));
  }

  /// Toggles between Arabic and English.
  void toggle() {
    setLocale(
      state.languageCode.toLowerCase() == 'ar'
          ? const ui.Locale('en')
          : const ui.Locale('ar'),
    );
  }

  Future<void> _persistLocale(
    ui.Locale locale,
    ui.Locale previousLocale,
  ) async {
    final result = await ref
        .read(settingsRepositoryProvider)
        .update(
          UpdateSettingsParams(locale: locale.languageCode.toLowerCase()),
        );

    result.fold(
      (_) => state = previousLocale,
      (updatedSettings) => state = _localeFromValue(updatedSettings.locale),
    );
  }
}

ui.Locale _localeFromValue(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'en':
      return const ui.Locale('en');
    case 'ar':
    default:
      return const ui.Locale('ar');
  }
}
