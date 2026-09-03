import 'package:daftar/application/agent/compose_collections_reminder_draft_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/collections_call_task_composer.dart';
import 'package:daftar/domain/constants/collections_reminder_draft_composer.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/repositories/merchant_profile_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:fpdart/fpdart.dart';

/// Device-owned Collections Desk rows from a [ClosingRitualResult].
///
/// Does not call Cloud Run. Empty [ClosingRitualResult.shortlist] is
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

  /// Builds ranked desk rows from the full dual-rail shortlist.
  ///
  /// `attachPdf` follows [ClosingRitualResult.pdfContacts] for email-rail rows.
  Future<Either<Failure, CollectionsDeskBuildResult>> execute(
    ClosingRitualResult ritual,
  ) async {
    if (ritual.shortlist.isEmpty) {
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
      for (final candidate in ritual.shortlist)
        _rowFor(
          candidate: candidate,
          locale: locale,
          storeName: storeName,
          attachPdf: pdfIds.contains(candidate.contactId) &&
              _hasEmailRail(candidate.rail),
          includeEmailDraft: _hasEmailRail(candidate.rail),
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

  static bool _hasEmailRail(OutreachRail rail) {
    return rail == OutreachRail.email ||
        rail == OutreachRail.both ||
        rail == OutreachRail.callUnavailable;
  }

  static bool _hasCallRail(OutreachRail rail) {
    return rail == OutreachRail.call || rail == OutreachRail.both;
  }

  CollectionsDeskRow _rowFor({
    required CollectionsCandidate candidate,
    required String locale,
    required String storeName,
    required bool attachPdf,
    required bool includeEmailDraft,
  }) {
    var subject = '';
    var body = '';
    var customerName = '';
    var amountLine = '';
    var ctaLine = '';
    var note = '';

    final resolvedStore =
        CollectionsReminderDraftComposer.resolveStoreName(storeName);

    if (includeEmailDraft) {
      final draft = _composeDraft.execute(
        candidate: candidate,
        tone: candidate.toneBand,
        locale: locale,
        storeName: resolvedStore,
      );
      subject = draft.subject;
      body = draft.body;
      customerName = draft.customerName;
      amountLine = draft.amountLine;
      ctaLine = draft.ctaLine;
      note = draft.note;
    }

    var callTask = '';
    if (_hasCallRail(candidate.rail)) {
      final task = CollectionsCallTaskComposer.compose(
        locale: locale,
        storeName: resolvedStore,
        contactName: candidate.name,
        amountMinor: candidate.owedMinor,
        currencyCode: candidate.currencyCode,
      );
      callTask = task.task;
      customerName = customerName.isEmpty ? task.customerName : customerName;
      amountLine = amountLine.isEmpty ? task.amountLine : amountLine;
    }

    return CollectionsDeskRow(
      candidate: candidate,
      subject: subject,
      body: body,
      customerName: customerName,
      storeName: resolvedStore,
      amountLine: amountLine,
      ctaLine: ctaLine,
      note: note,
      callTask: callTask,
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

  /// Ranked desk rows (full dual-rail shortlist).
  final List<CollectionsDeskRow> rows;

  /// Normalized `ar` or `en`.
  final String locale;

  /// Merchant store name or [CollectionsReminderDraftComposer.fallbackStoreName].
  final String storeName;
}
