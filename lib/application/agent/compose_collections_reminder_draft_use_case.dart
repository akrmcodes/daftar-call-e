import 'package:daftar/domain/constants/collections_reminder_draft_composer.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_reminder_draft.dart';

/// Formats integer minor units then composes an Appendix C.2 draft.
class ComposeCollectionsReminderDraftUseCase {
  /// Creates the use case.
  const ComposeCollectionsReminderDraftUseCase();

  /// Returns subject + body + named params. Never uses `double` for money.
  CollectionsReminderDraft execute({
    required CollectionsCandidate candidate,
    required ReminderToneBand tone,
    required String locale,
    required String storeName,
  }) {
    return CollectionsReminderDraftComposer.compose(
      locale: locale,
      storeName: storeName,
      contactName: candidate.name,
      amountMinor: candidate.owedMinor,
      currencyCode: candidate.currencyCode,
      tone: tone,
      ageDays: candidate.ageDays,
    );
  }
}
