import 'package:daftar/domain/constants/collections_reminder_draft_composer.dart';

/// CALL-E spoken locale vs merchant UI locale.
///
/// UI `ar`/`en` is email and chrome. Recipient `locale` on `calls.create` must
/// be a region-legal BCP-47 tag. US is English-only (`en-US`).
///
/// Keep in lockstep with [`agent/calls/spoken_locale.py`](../../../agent/calls/spoken_locale.py).
abstract final class CalleSpokenLocale {
  /// CALL-E English tag used for every non-Arabic-capable region.
  static const String englishBcp47 = 'en-US';

  /// J.10 rows whose CALL-E language list includes Arabic.
  static const Set<String> arabicCapableRegions = {
    'AE',
    'SA',
    'EG',
    'OM',
  };

  /// CALL-E `recipients[].locale` for [region] given merchant [uiLocale].
  static String bcp47({
    required String region,
    required String uiLocale,
  }) {
    final iso = region.trim().toUpperCase();
    final arabicUi =
        CollectionsReminderDraftComposer.normalizeLocale(uiLocale) == 'ar';
    if (arabicUi && arabicCapableRegions.contains(iso)) {
      return 'ar-$iso';
    }
    return englishBcp47;
  }

  /// C.3 composer language (`ar` / `en`) matching [bcp47].
  static String taskLanguage({
    required String region,
    required String uiLocale,
  }) {
    return bcp47(
          region: region,
          uiLocale: uiLocale,
        ).toLowerCase().startsWith('ar')
        ? 'ar'
        : 'en';
  }
}
