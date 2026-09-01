import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ErrorTranslator seat cap', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('uses team-full copy without upgrade language', () {
      const failure = SeatCapExceededFailure('Seat cap exceeded');

      final content = ErrorTranslator.translate(l10n, failure);

      expect(content.title, l10n.errorSeatCapTitle);
      expect(content.message, contains('2'));
      expect(content.message.toLowerCase(), isNot(contains('upgrade')));
    });
  });
}
