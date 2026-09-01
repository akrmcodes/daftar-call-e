import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/currency.dart';

/// Resolves the ISO currency code used when persisting a new record.
///
/// When multi-currency is disabled in [settings], always returns
/// the configured default currency regardless of [requested].
String effectiveCreationCurrency(AppSettings settings, String requested) {
  if (!settings.isMultiCurrencyEnabled) {
    return _normalizeCurrencyCode(settings.defaultCurrency);
  }
  return _normalizeCurrencyCode(requested);
}

/// Returns the display symbol for [code] from [builtIns], or [code] as fallback.
String symbolForCurrencyCode(String code, List<Currency> builtIns) {
  final normalized = _normalizeCurrencyCode(code);
  for (final currency in builtIns) {
    if (currency.code == normalized) {
      return currency.symbol;
    }
  }
  return normalized;
}

String _normalizeCurrencyCode(String code) {
  return code.trim().toUpperCase();
}
