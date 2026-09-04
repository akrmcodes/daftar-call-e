import 'package:daftar/core/errors/edge_error_codes.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ErrorTranslator Closing Agent auth', () {
    late AppLocalizations l10nEn;
    late AppLocalizations l10nAr;

    setUpAll(() async {
      l10nEn = await AppLocalizations.delegate.load(const Locale('en'));
      l10nAr = await AppLocalizations.delegate.load(const Locale('ar'));
    });

    test('closing_agent_forbidden never uses workspace-owner copy', () {
      const failure = AuthFailure(
        'Forbidden',
        code: 'closing_agent_forbidden',
      );

      final en = ErrorTranslator.translate(l10nEn, failure);
      expect(en.title, l10nEn.errorAuthTitle);
      expect(en.message, l10nEn.errorClosingAgentForbidden);
      expect(en.message, isNot(l10nEn.errorForbiddenMessage));

      final ar = ErrorTranslator.translate(l10nAr, failure);
      expect(ar.message, l10nAr.errorClosingAgentForbidden);
      expect(ar.message, isNot(l10nAr.errorForbiddenMessage));
    });

    test('closing_agent_unauthorized uses agent sign-in copy', () {
      const failure = AuthFailure(
        'Unauthorized',
        code: 'closing_agent_unauthorized',
      );

      final content = ErrorTranslator.translate(l10nEn, failure);
      expect(content.message, l10nEn.errorAgentIdTokenMissing);
      expect(content.message, isNot(l10nEn.errorForbiddenMessage));
    });

    test('agent_openid_grant_required uses dedicated ARB, not sign-in copy', () {
      const failure = AuthFailure(
        'upgrade',
        code: 'agent_openid_grant_required',
      );

      final en = ErrorTranslator.translate(l10nEn, failure);
      expect(en.message, l10nEn.errorAgentOpenIdGrantRequired);
      expect(en.message, isNot(l10nEn.errorAgentIdTokenMissing));
      final ar = ErrorTranslator.translate(l10nAr, failure);
      expect(ar.message, l10nAr.errorAgentOpenIdGrantRequired);
    });

    test('calle_kill_switch uses paused-calls copy', () {
      const failure = AuthFailure(
        'CALL-E kill switch',
        code: 'calle_kill_switch',
      );

      final en = ErrorTranslator.translate(l10nEn, failure);
      expect(en.title, l10nEn.errorCalleKillSwitchTitle);
      expect(en.message, l10nEn.errorCalleKillSwitch);
      expect(en.title, isNot(l10nEn.errorAuthTitle));
    });

    test('smtp_needs_human uses email title, not sign-in required', () {
      const failure = AuthFailure(
        'SMTP needs a human (App Password rejected).',
        code: 'smtp_needs_human',
      );

      final en = ErrorTranslator.translate(l10nEn, failure);
      expect(en.title, l10nEn.errorSmtpTitle);
      expect(en.message, l10nEn.errorSmtpNeedsHuman);
      expect(en.title, isNot(l10nEn.errorAuthTitle));
      final ar = ErrorTranslator.translate(l10nAr, failure);
      expect(ar.title, l10nAr.errorSmtpTitle);
      expect(ar.message, l10nAr.errorSmtpNeedsHuman);
    });

    test('smtp_sender_misconfigured does not ask to sign in', () {
      const failure = AuthFailure(
        'SMTP sender is not configured on Cloud Run.',
        code: 'smtp_sender_misconfigured',
      );

      final en = ErrorTranslator.translate(l10nEn, failure);
      expect(en.title, l10nEn.errorSmtpTitle);
      expect(en.message, l10nEn.errorSmtpSenderMisconfigured);
      expect(en.message, isNot(l10nEn.errorSmtpNeedsHuman));
    });

    test('agent_google_account_mismatch uses agent sign-in copy', () {
      const failure = AuthFailure(
        'Mismatch',
        code: 'agent_google_account_mismatch',
      );

      final content = ErrorTranslator.translate(l10nEn, failure);
      expect(content.message, l10nEn.errorAgentIdTokenMissing);
    });

    test('workspace ForbiddenFailure still uses owner copy', () {
      const failure = ForbiddenFailure('forbidden');

      final content = ErrorTranslator.translate(l10nEn, failure);
      expect(content.title, l10nEn.errorForbiddenTitle);
      expect(content.message, l10nEn.errorForbiddenMessage);
    });

    test('generic AuthFailure forbidden is not the agent path', () {
      const failure = AuthFailure(
        'Forbidden',
        code: EdgeErrorCodes.forbidden,
      );

      final content = ErrorTranslator.translate(l10nEn, failure);
      expect(content.message, l10nEn.errorForbiddenMessage);
    });

    test('currency_required uses errorCurrencyRequired', () {
      const failure = ValidationFailure(
        'Select a currency before creating this contact.',
        code: 'currency_required',
      );

      final en = ErrorTranslator.translate(l10nEn, failure);
      expect(en.message, l10nEn.errorCurrencyRequired);
      final ar = ErrorTranslator.translate(l10nAr, failure);
      expect(ar.message, l10nAr.errorCurrencyRequired);
    });
  });

  group('ErrorTranslator Closing Agent resilience', () {
    late AppLocalizations l10nEn;
    late AppLocalizations l10nAr;

    setUpAll(() async {
      l10nEn = await AppLocalizations.delegate.load(const Locale('en'));
      l10nAr = await AppLocalizations.delegate.load(const Locale('ar'));
    });

    test(
      'closing_agent_request_failed uses agent copy, not sync unavailable',
      () {
        const failure = NetworkFailure(
          'Closing Agent request failed: SocketException',
          code: 'closing_agent_request_failed',
        );

        final en = ErrorTranslator.translate(l10nEn, failure);
        expect(en.title, l10nEn.errorNetworkTitle);
        expect(en.message, l10nEn.errorClosingAgentRequestFailed);
        expect(en.message, isNot(l10nEn.errorServiceUnavailableMessage));
        expect(en.message, isNot(failure.message));

        final ar = ErrorTranslator.translate(l10nAr, failure);
        expect(ar.message, l10nAr.errorClosingAgentRequestFailed);
        expect(ar.message, isNot(l10nAr.errorServiceUnavailableMessage));
      },
    );

    test('service_unavailable stays sync-server copy', () {
      const failure = NetworkFailure(
        'unavailable',
        code: EdgeErrorCodes.serviceUnavailable,
      );

      final content = ErrorTranslator.translate(l10nEn, failure);
      expect(content.message, l10nEn.errorServiceUnavailableMessage);
      expect(content.message, isNot(l10nEn.errorClosingAgentRequestFailed));
    });

    test('contact_id_required uses errorContactUnresolved', () {
      const failure = ValidationFailure(
        'Contact id is required.',
        code: 'contact_id_required',
      );
      final content = ErrorTranslator.translate(l10nEn, failure);
      expect(content.message, l10nEn.errorContactUnresolved);
      expect(content.message, isNot(failure.message));
    });

    test('proposal_not_found uses errorNotFoundMessage', () {
      const failure = ValidationFailure(
        'Proposal turn not found.',
        code: 'proposal_not_found',
      );
      final content = ErrorTranslator.translate(l10nEn, failure);
      expect(content.message, l10nEn.errorNotFoundMessage);
      expect(content.message, isNot(failure.message));
    });

    test('proposal_already_committed uses dedicated ARB', () {
      const failure = ValidationFailure(
        'Cannot cancel an already committed proposal.',
        code: 'proposal_already_committed',
      );
      final en = ErrorTranslator.translate(l10nEn, failure);
      expect(en.message, l10nEn.errorProposalAlreadyCommitted);
      expect(en.message, isNot(failure.message));
      final ar = ErrorTranslator.translate(l10nAr, failure);
      expect(ar.message, l10nAr.errorProposalAlreadyCommitted);
    });

    test('invalid_amount_minor uses parse ARB, not Failure.message', () {
      const failure = ValidationFailure(
        'amountMinor must be a Dart int.',
        code: 'invalid_amount_minor',
      );
      final content = ErrorTranslator.translate(l10nEn, failure);
      expect(content.message, l10nEn.errorClosingAgentParseFailed);
      expect(content.message, isNot(failure.message));
    });
  });

  group('ErrorTranslator Drive unsigned', () {
    late AppLocalizations l10nEn;

    setUpAll(() async {
      l10nEn = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('google_not_signed_in is unsigned copy, not sign-in failed', () {
      expect(
        ErrorTranslator.driveFailureMessage(l10nEn, AuthFailure.notSignedIn),
        l10nEn.backupDriveNotSignedIn,
      );
      expect(
        ErrorTranslator.driveFailureMessage(l10nEn, AuthFailure.notSignedIn),
        isNot(l10nEn.backupDriveSignInFailed),
      );
    });
  });
}
