import 'package:daftar/application/agent/compose_collections_reminder_draft_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/collections_reminder_draft_composer.dart';
import 'package:daftar/domain/repositories/merchant_profile_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:fpdart/fpdart.dart';

/// Device-owned Collections Desk rows from a [ClosingRitualResult].
///
/// Does not call Cloud Run. Empty [ClosingRitualResult.reminderSet] is
/// [Right] of an empty snapshot.
class BuildCollectionsDeskUseCase {
  /// Creates the use case.
  const BuildCollectionsDeskUseCase({
    required SettingsRepository settingsRepository,
    required MerchantProfileRepository merchantProfileRepository,
    required ComposeCollectionsReminderDraftUseCase composeDraft,
  }) : _settingsRepository = settingsRepository,
       _merchantProfileRepository = merchantProfileRepository,
       _composeDraft = composeDraft;

  final SettingsRepository _settingsRepository;
  final MerchantProfileRepository _merchantProfileRepository;
  final ComposeCollectionsReminderDraftUseCase _composeDraft;

  /// Builds ranked desk rows. `attachPdf` follows [ClosingRitualResult.pdfContacts].
  Future<Either<Failure, CollectionsDeskBuildResult>> execute(
    ClosingRitualResult ritual,
  ) async {
    if (ritual.reminderSet.isEmpty) {
      return const Right(
        CollectionsDeskBuildResult(
          rows: [],
          locale: 'ar',
          storeName: CollectionsReminderDraftComposer.fallbackStoreName,
        ),
      );
    }

    final settingsResult = await _settingsRepository.get();
    final locale = CollectionsReminderDraftComposer.normalizeLocale(
      settingsResult.fold((_) => 'ar', (settings) => settings.locale),
    );

    final profileResult = await _merchantProfileRepository.get();
    final storeName = profileResult.fold(
      (_) => CollectionsReminderDraftComposer.fallbackStoreName,
      (profile) => CollectionsReminderDraftComposer.resolveStoreName(
        profile?.storeName,
      ),
    );

    final pdfIds = {
      for (final contact in ritual.pdfContacts) contact.contactId,
    };

    final rows = [
      for (final candidate in ritual.reminderSet)
        _rowFor(
          candidate: candidate,
          locale: locale,
          storeName: storeName,
          attachPdf: pdfIds.contains(candidate.contactId),
        ),
    ];

    return Right(
      CollectionsDeskBuildResult(
        rows: rows,
        locale: locale,
        storeName: storeName,
      ),
    );
  }

  CollectionsDeskRow _rowFor({
    required CollectionsCandidate candidate,
    required String locale,
    required String storeName,
    required bool attachPdf,
  }) {
    final draft = _composeDraft.execute(
      candidate: candidate,
      tone: candidate.toneBand,
      locale: locale,
      storeName: storeName,
    );
    return CollectionsDeskRow(
      candidate: candidate,
      subject: draft.subject,
      body: draft.body,
      customerName: draft.customerName,
      storeName: draft.storeName,
      amountLine: draft.amountLine,
      ctaLine: draft.ctaLine,
      note: draft.note,
      toneBand: candidate.toneBand,
      attachPdf: attachPdf,
    );
  }
}

/// Locale, store name, and rows for the Collections Desk.
class CollectionsDeskBuildResult {
  /// Creates a build result.
  const CollectionsDeskBuildResult({
    required this.rows,
    required this.locale,
    required this.storeName,
  });

  /// Ranked reminder rows (send-set cap already applied on the ritual).
  final List<CollectionsDeskRow> rows;

  /// Normalized `ar` or `en`.
  final String locale;

  /// Merchant store name or [CollectionsReminderDraftComposer.fallbackStoreName].
  final String storeName;
}
