import 'package:daftar/application/agent/build_collections_desk_use_case.dart';
import 'package:daftar/application/agent/collections_send_queue_use_cases.dart';
import 'package:daftar/application/agent/compose_collections_reminder_draft_use_case.dart';
import 'package:daftar/application/agent/dispatch_collections_email_use_case.dart';
import 'package:daftar/application/agent/run_closing_ritual_use_case.dart';
import 'package:daftar/core/utils/whatsapp_util.dart';
import 'package:daftar/domain/constants/collections_reminder_draft_composer.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/device_collections_statement_pdf_renderer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'closing_ritual_providers.g.dart';

/// Device-owned close-the-day orchestrator (summary → Drive → shortlist).
@Riverpod(keepAlive: true)
RunClosingRitualUseCase runClosingRitualUseCase(Ref ref) {
  return RunClosingRitualUseCase(
    getClosingDaySummaryUseCase: ref.watch(getClosingDaySummaryUseCaseProvider),
    uploadDriveBackupUseCase: ref.watch(uploadDriveBackupUseCaseProvider),
    getCollectionsCandidatesUseCase: ref.watch(
      getCollectionsCandidatesUseCaseProvider,
    ),
  );
}

/// Formats integer money then composes an Appendix C.2 draft.
@Riverpod(keepAlive: true)
ComposeCollectionsReminderDraftUseCase composeCollectionsReminderDraftUseCase(
  Ref ref,
) {
  return const ComposeCollectionsReminderDraftUseCase();
}

/// SMTP send-batch for Collections Approve.
@Riverpod(keepAlive: true)
DispatchCollectionsEmailUseCase dispatchCollectionsEmailUseCase(Ref ref) {
  return DispatchCollectionsEmailUseCase(
    prepareContactStatement: ref.watch(
      prepareContactStatementUseCaseProvider,
    ),
    pdfRenderer: DeviceCollectionsStatementPdfRenderer(
      locale: CollectionsReminderDraftComposer.normalizeLocale(
        ref.watch(appSettingsProvider).value?.locale ?? 'ar',
      ),
      resolveMerchantProfile: ref.watch(
        resolvePdfMerchantProfileUseCaseProvider,
      ),
    ),
    runtimeRepository: ref.watch(closingAgentRuntimeRepositoryProvider),
    composeDraft: ref.watch(composeCollectionsReminderDraftUseCaseProvider),
  );
}

/// Builds Collections Desk rows from a ritual snapshot.
@Riverpod(keepAlive: true)
BuildCollectionsDeskUseCase buildCollectionsDeskUseCase(Ref ref) {
  return BuildCollectionsDeskUseCase(
    settingsRepository: ref.watch(settingsRepositoryProvider),
    merchantProfileRepository: ref.watch(merchantProfileRepositoryProvider),
    composeDraft: ref.watch(composeCollectionsReminderDraftUseCaseProvider),
  );
}

/// Test seam for [WhatsAppUtil.openWhatsApp] (never silent-sends).
class CollectionsWhatsAppLauncher {
  /// Creates a launcher. [openImpl] defaults to [WhatsAppUtil.openWhatsApp].
  const CollectionsWhatsAppLauncher({this.openImpl});

  /// Optional override used in tests.
  final Future<bool> Function({required String phone, String? message})?
  openImpl;

  /// Opens WhatsApp click-to-chat with an optional prefilled body.
  Future<bool> open({required String phone, String? message}) {
    final impl = openImpl ?? WhatsAppUtil.openWhatsApp;
    return impl(phone: phone, message: message);
  }
}

/// WhatsApp click-to-chat launcher for the Collections Desk.
@Riverpod(keepAlive: true)
CollectionsWhatsAppLauncher collectionsWhatsAppOpener(Ref ref) {
  return const CollectionsWhatsAppLauncher();
}

/// Persists the in-flight Hybrid E send queue.
@Riverpod(keepAlive: true)
SaveCollectionsSendQueueUseCase saveCollectionsSendQueueUseCase(Ref ref) {
  return SaveCollectionsSendQueueUseCase(
    ref.watch(collectionsSendQueueRepositoryProvider),
  );
}

/// Loads the active or paused Hybrid E send queue.
@Riverpod(keepAlive: true)
LoadInFlightCollectionsSendQueueUseCase
loadInFlightCollectionsSendQueueUseCase(Ref ref) {
  return LoadInFlightCollectionsSendQueueUseCase(
    ref.watch(collectionsSendQueueRepositoryProvider),
  );
}

/// Marks a Hybrid E send queue completed.
@Riverpod(keepAlive: true)
CompleteCollectionsSendQueueUseCase completeCollectionsSendQueueUseCase(
  Ref ref,
) {
  return CompleteCollectionsSendQueueUseCase(
    ref.watch(collectionsSendQueueRepositoryProvider),
  );
}
