import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:daftar/presentation/providers/deep_link_providers.dart';

/// Localized copy for a non-routing [DeepLinkHandleOutcome].
///
/// Returns null when the outcome navigated away and needs no message.
/// Manual code entry must never end in a silently inert button.
String? deepLinkOutcomeMessage(
  AppLocalizations l10n,
  DeepLinkHandleOutcome outcome,
) {
  return switch (outcome) {
    DeepLinkHandleRouted() => null,
    DeepLinkHandleInvalidToken() => l10n.joinWorkspaceInvalidCode,
    DeepLinkHandleAlreadyHandled() => l10n.joinWorkspaceAlreadyUsed,
    DeepLinkHandleBusy() => l10n.joinWorkspaceBusy,
    DeepLinkHandleFailed(:final failure) =>
      ErrorTranslator.message(l10n, failure),
  };
}
