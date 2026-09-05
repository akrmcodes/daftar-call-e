import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/edge_error_codes.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/localized_error_content.dart';

/// Maps domain failures and unexpected errors to localized, user-safe copy.
///
/// Raw exception strings, stack traces, and [Failure.message] English
/// diagnostics are never shown to the user.
abstract final class ErrorTranslator {
  static LocalizedErrorContent translate(
    AppLocalizations l10n,
    Object error,
  ) {
    if (error is Failure) {
      return _fromFailure(l10n, error);
    }

    return LocalizedErrorContent(
      title: l10n.errorGenericTitle,
      message: l10n.errorGenericMessage,
    );
  }

  /// Short message for inline error states (lists, banners).
  static String message(AppLocalizations l10n, Object error) {
    return translate(l10n, error).message;
  }

  /// Sign-in flow: distinguishes Google failures from Auth Bridge / sync server.
  static String signInFailureMessage(AppLocalizations l10n, Failure failure) {
    if (failure is NetworkFailure) {
      return l10n.syncAuthBridgeFailed;
    }
    if (failure is AuthFailure) {
      return switch (failure.code) {
        'sync_auth_failed' ||
        'sync_bridge_blocked' ||
        'sync_id_token_missing' => l10n.syncAuthBridgeFailed,
        _ => message(l10n, failure),
      };
    }
    return message(l10n, failure);
  }

  /// Drive backup / OAuth grant flows.
  static String driveFailureMessage(AppLocalizations l10n, Failure failure) {
    if (failure is QuotaExceededFailure) {
      return l10n.backupDriveQuotaExceeded;
    }
    if (failure is NetworkFailure) {
      return l10n.backupDriveOffline;
    }
    if (failure is AuthFailure) {
      return switch (failure.code) {
        'google_not_signed_in' => l10n.backupDriveNotSignedIn,
        'silent_sign_in_failed' ||
        'drive_auth_client_failed' => l10n.backupDriveSignInFailed,
        'drive_refresh_token_revoked' ||
        'drive_scopes_not_authorized' => l10n.backupDriveAuthExpired,
        'drive_offline_grant_failed' => l10n.backupDriveOfflineGrantFailed,
        'canceled' => l10n.errorAuthMessage,
        _ => message(l10n, failure),
      };
    }
    return message(l10n, failure);
  }

  /// Activation code redemption.
  static String activationFailureMessage(
    AppLocalizations l10n,
    Object error,
  ) {
    if (error is! Failure) {
      return l10n.activationErrorInvalid;
    }
    if (error is AuthFailure) {
      return switch (error.code) {
        'invalid_offline_code' ||
        'invalid_token' ||
        'empty_code' ||
        'activation_error' => l10n.activationErrorInvalid,
        _ => message(l10n, error),
      };
    }
    return message(l10n, error);
  }

  static LocalizedErrorContent _fromFailure(
    AppLocalizations l10n,
    Failure failure,
  ) {
    if (failure is ValidationFailure) {
      return _validation(l10n, failure);
    }
    if (failure is InvalidAmountFailure) {
      return LocalizedErrorContent(
        title: l10n.errorInvalidAmountTitle,
        message: l10n.errorInvalidAmountMessage,
      );
    }
    if (failure is DatabaseFailure) {
      return LocalizedErrorContent(
        title: l10n.errorDatabaseTitle,
        message: l10n.errorDatabaseMessage,
      );
    }
    if (failure is ForbiddenFailure) {
      return LocalizedErrorContent(
        title: l10n.errorForbiddenTitle,
        message: l10n.errorForbiddenMessage,
      );
    }
    if (failure is NetworkFailure) {
      final networkMessage = switch (failure.code) {
        'closing_agent_request_failed' => l10n.errorClosingAgentRequestFailed,
        'whatsapp_open_failed' => l10n.collectionsDeskWhatsAppFailed,
        _ => edgeCodeMessage(l10n, failure.code) ?? l10n.errorNetworkMessage,
      };
      return LocalizedErrorContent(
        title: l10n.errorNetworkTitle,
        message: networkMessage,
      );
    }
    if (failure is StorageFullFailure) {
      return LocalizedErrorContent(
        title: l10n.errorStorageFullTitle,
        message: l10n.errorStorageFullMessage,
      );
    }
    if (failure is StorageFailure) {
      return LocalizedErrorContent(
        title: l10n.errorStorageTitle,
        message: l10n.errorStorageMessage,
      );
    }
    if (failure is AuthFailure) {
      return _auth(l10n, failure);
    }
    if (failure is QuotaExceededFailure) {
      return LocalizedErrorContent(
        title: l10n.errorQuotaExceededTitle,
        message: l10n.backupDriveQuotaExceeded,
      );
    }
    if (failure is RateLimitedFailure) {
      return _rateLimited(l10n, failure);
    }
    if (failure is SeatCapExceededFailure) {
      return LocalizedErrorContent(
        title: l10n.errorSeatCapTitle,
        message: l10n.errorSeatCapMessage(failure.maxWorkers),
      );
    }
    if (failure is LimitExceededFailure) {
      return _limitExceeded(l10n, failure);
    }
    if (failure is FreeTierLimitReachedFailure) {
      return _freeTierLimit(l10n, failure);
    }

    return LocalizedErrorContent(
      title: l10n.errorGenericTitle,
      message: l10n.errorGenericMessage,
    );
  }

  /// Localized copy for a stable Edge Function error code.
  ///
  /// Branching on the code — never on the server's English `error` text —
  /// is what keeps a raw diagnostic from reaching a merchant when the
  /// backend rewords a message.
  static String? edgeCodeMessage(AppLocalizations l10n, String? code) {
    return switch (code) {
      EdgeErrorCodes.forbidden => l10n.errorForbiddenMessage,
      EdgeErrorCodes.unauthorized => l10n.errorAuthMessage,
      EdgeErrorCodes.invalidRequest => l10n.errorInvalidRequestMessage,
      EdgeErrorCodes.invalidAction => l10n.errorInvalidActionMessage,
      EdgeErrorCodes.notFound => l10n.errorNotFoundMessage,
      EdgeErrorCodes.methodNotAllowed ||
      EdgeErrorCodes.internalError => l10n.errorServerMessage,
      EdgeErrorCodes.conflict => l10n.errorConflictMessage,
      EdgeErrorCodes.seatCapExceeded => l10n.errorSeatCapMessage(
        AppConstants.maxWorkerSeats,
      ),
      EdgeErrorCodes.deviceCapExceeded => l10n.errorDeviceCapMessage,
      EdgeErrorCodes.syncEventCapExceeded => l10n.errorSyncEventCapMessage,
      EdgeErrorCodes.deviceRegistrationFailed =>
        l10n.syncReportDeviceRegistrationFailed,
      EdgeErrorCodes.usageCounterWriteFailed => l10n.errorServerMessage,
      EdgeErrorCodes.rateLimited => l10n.errorRateLimitedMessage,
      EdgeErrorCodes.serviceUnavailable => l10n.errorServiceUnavailableMessage,
      _ => null,
    };
  }

  static LocalizedErrorContent _validation(
    AppLocalizations l10n,
    ValidationFailure failure,
  ) {
    final edgeMessage = edgeCodeMessage(l10n, failure.code);
    if (edgeMessage != null) {
      return LocalizedErrorContent(
        title: l10n.errorValidationTitle,
        message: edgeMessage,
      );
    }

    final message = switch (failure.code) {
      'contact_name_required' || 'ledger_name_required' => l10n.nameRequired,
      'contact_name_exists' => l10n.errorContactNameExists,
      'contact_email_invalid' => l10n.contactEmailInvalid,
      'collections_email_cap' => l10n.errorCollectionsEmailCap,
      'transaction_amount_invalid' => l10n.invalidAmount,
      'transaction_currency_required' => l10n.amountRequired,
      'transaction_contact_required' => l10n.errorValidationMessage,
      'restore_checksum_mismatch' => l10n.backupRestoreFailed,
      'restore_invalid_format' => l10n.backupRestoreFailed,
      'csv_import_preflight_mapping_incomplete' =>
        l10n.csvImportBlockingFailureTitle,
      'goal_text_required' => l10n.errorGoalTextRequired,
      'proposal_in_flight' => l10n.errorProposalInFlight,
      'contact_unresolved' || 'contact_id_required' =>
        l10n.errorContactUnresolved,
      'pdf_fetch_failed' => l10n.pdfFetchFailed,
      'pdf_render_failed' => l10n.pdfRenderFailed,
      'pdf_save_failed' => l10n.pdfSaveFailed,
      'pdf_share_failed' => l10n.pdfShareFailed,
      'pdf_timeout' => l10n.pdfTimeout,
      'ledger_required' => l10n.errorLedgerRequired,
      'currency_required' => l10n.errorCurrencyRequired,
      'proposal_not_found' || 'proposal_id_required' =>
        l10n.errorNotFoundMessage,
      'proposal_already_committed' => l10n.errorProposalAlreadyCommitted,
      'invalid_proposal_id' ||
      'invalid_proposal_tool' ||
      'unknown_proposal_tool' ||
      'invalid_proposal_payload' ||
      'invalid_confirm_required' ||
      'invalid_amount_minor' => l10n.errorClosingAgentParseFailed,
      _ => l10n.errorValidationMessage,
    };

    return LocalizedErrorContent(
      title: l10n.errorValidationTitle,
      message: message,
    );
  }

  static LocalizedErrorContent _auth(
    AppLocalizations l10n,
    AuthFailure failure,
  ) {
    if (failure.code == 'smtp_needs_human' ||
        failure.code == 'smtp_sender_misconfigured') {
      return LocalizedErrorContent(
        title: l10n.errorSmtpTitle,
        message: failure.code == 'smtp_sender_misconfigured'
            ? l10n.errorSmtpSenderMisconfigured
            : l10n.errorSmtpNeedsHuman,
      );
    }
    if (failure.code == 'credit_limit_no_outreach') {
      return LocalizedErrorContent(
        title: l10n.notificationWarningTitle,
        message: l10n.errorCreditLimitNoOutreach,
      );
    }
    if (failure.code == 'calle_kill_switch') {
      return LocalizedErrorContent(
        title: l10n.errorCalleKillSwitchTitle,
        message: l10n.errorCalleKillSwitch,
      );
    }
    if (failure.code == 'calle_poll_timeout') {
      return LocalizedErrorContent(
        title: l10n.errorCallePollTimeoutTitle,
        message: l10n.errorCallePollTimeout,
      );
    }
    if (failure.code == 'calle_needs_human') {
      return LocalizedErrorContent(
        title: l10n.errorCalleNeedsHumanTitle,
        message: l10n.errorCalleNeedsHuman,
      );
    }

    final message = switch (failure.code) {
      'canceled' => l10n.errorAuthMessage,
      'sync_auth_failed' ||
      'sync_bridge_blocked' ||
      'sync_id_token_missing' => l10n.syncAuthBridgeFailed,
      'agent_id_token_missing' ||
      'agent_google_account_mismatch' ||
      'closing_agent_unauthorized' => l10n.errorAgentIdTokenMissing,
      'agent_openid_grant_required' => l10n.errorAgentOpenIdGrantRequired,
      'closing_agent_forbidden' => l10n.errorClosingAgentForbidden,
      'unauthorized' => l10n.errorAuthMessage,
      _ => edgeCodeMessage(l10n, failure.code) ?? l10n.errorAuthMessage,
    };

    return LocalizedErrorContent(
      title: l10n.errorAuthTitle,
      message: message,
    );
  }

  static LocalizedErrorContent _rateLimited(
    AppLocalizations l10n,
    RateLimitedFailure failure,
  ) {
    final retrySeconds = failure.retryAfterSeconds;
    final message = retrySeconds != null && retrySeconds > 0
        ? l10n.errorRateLimitedMessageWithRetry(
            _formatRetryMinutes(retrySeconds),
          )
        : l10n.errorRateLimitedMessage;

    return LocalizedErrorContent(
      title: l10n.errorRateLimitedTitle,
      message: message,
    );
  }

  static int _formatRetryMinutes(int retrySeconds) {
    final minutes = (retrySeconds / 60).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  static LocalizedErrorContent _limitExceeded(
    AppLocalizations l10n,
    LimitExceededFailure failure,
  ) {
    final message = switch (failure.featureKey) {
      AppConstants.featureUnlimitedLedgers => l10n.maxLedgersReached,
      _ => l10n.limitReachedSubtitle,
    };

    return LocalizedErrorContent(
      title: l10n.limitReachedTitle,
      message: message,
    );
  }

  static LocalizedErrorContent _freeTierLimit(
    AppLocalizations l10n,
    FreeTierLimitReachedFailure failure,
  ) {
    final message = switch (failure.featureKey) {
      AppConstants.featureUnlimitedLedgers => l10n.maxLedgersReached,
      _ => l10n.limitReachedSubtitle,
    };

    return LocalizedErrorContent(
      title: l10n.limitReachedTitle,
      message: message,
    );
  }
}
