import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/providers/deep_link_providers.dart';
import 'package:daftar/presentation/screens/invite/deep_link_outcome_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Manual invite-code entry used to end in a silently inert button on every
/// non-routing outcome. Each one now needs localized, actionable copy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations en;
  late AppLocalizations ar;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    ar = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  test('a routed outcome needs no message', () {
    expect(
      deepLinkOutcomeMessage(en, const DeepLinkHandleOutcome.routed()),
      isNull,
    );
  });

  test('every non-routing outcome produces copy in both locales', () {
    const outcomes = <DeepLinkHandleOutcome>[
      DeepLinkHandleOutcome.invalidToken(),
      DeepLinkHandleOutcome.alreadyHandled(),
      DeepLinkHandleOutcome.busy(),
      DeepLinkHandleOutcome.failed(
        NetworkFailure('connection refused', code: 'sync_offline'),
      ),
    ];

    for (final outcome in outcomes) {
      final enMessage = deepLinkOutcomeMessage(en, outcome);
      final arMessage = deepLinkOutcomeMessage(ar, outcome);
      expect(enMessage, isNotNull, reason: '$outcome has no English copy');
      expect(arMessage, isNotNull, reason: '$outcome has no Arabic copy');
      expect(arMessage, isNot(enMessage), reason: '$outcome is untranslated');
    }
  });

  test('a transport failure never leaks the raw diagnostic string', () {
    const failure = NetworkFailure(
      'DioException: connection errored at 192.168.8.81:54321',
      code: 'sync_pull_failed',
    );

    final message = deepLinkOutcomeMessage(
      ar,
      const DeepLinkHandleOutcome.failed(failure),
    );

    expect(message, isNotNull);
    expect(message, isNot(contains('DioException')));
    expect(message, isNot(contains('192.168')));
  });
}
