import 'dart:async';
import 'dart:typed_data';

import 'package:daftar/application/agent/answer_ask_books_use_case.dart';
import 'package:daftar/application/agent/build_collections_desk_use_case.dart';
import 'package:daftar/application/agent/collections_send_queue_use_cases.dart';
import 'package:daftar/application/agent/commit_agent_proposal_use_case.dart';
import 'package:daftar/application/agent/dispatch_collections_email_use_case.dart';
import 'package:daftar/application/agent/get_call_run_use_case.dart';
import 'package:daftar/application/agent/get_closing_day_summary_use_case.dart';
import 'package:daftar/application/agent/hydrate_agent_id_token_use_case.dart';
import 'package:daftar/application/agent/persist_collection_call_outcome_use_case.dart';
import 'package:daftar/application/agent/plan_call_batch_use_case.dart';
import 'package:daftar/application/agent/run_call_batch_use_case.dart';
import 'package:daftar/application/agent/run_closing_agent_turn_use_case.dart';
import 'package:daftar/application/agent/synthesize_agent_speech_use_case.dart';
import 'package:daftar/application/backup/upload_drive_backup_use_case.dart';
import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/application/contact/get_collections_candidates_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/connectivity_service.dart';
import 'package:daftar/core/utils/agent_speech.dart';
import 'package:daftar/core/utils/device_tts.dart';
import 'package:daftar/core/utils/native_contact_picker_service.dart';
import 'package:daftar/domain/constants/calle_device_policy.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:daftar/domain/enums/call_batch_status.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/closing_pdf_policy.dart';
import 'package:daftar/domain/enums/closing_reminder_policy.dart';
import 'package:daftar/domain/enums/closing_task_id.dart';
import 'package:daftar/domain/enums/collections_call_report_status.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/collections_send_queue_status.dart';
import 'package:daftar/domain/enums/confirm_proposal_status.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/agent_audio_clip.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/domain/value_objects/agent_speech_clip.dart';
import 'package:daftar/domain/value_objects/agent_turn_result.dart';
import 'package:daftar/domain/value_objects/ask_books_answer.dart';
import 'package:daftar/domain/value_objects/call_get_result.dart';
import 'package:daftar/domain/value_objects/call_plan_batch.dart';
import 'package:daftar/domain/value_objects/call_run_batch.dart';
import 'package:daftar/domain/value_objects/closing_day_summary.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:daftar/domain/value_objects/collection_call_persist.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/domain/value_objects/collections_queue_metrics.dart';
import 'package:daftar/domain/value_objects/collections_send_queue.dart';
import 'package:daftar/domain/value_objects/confirm_proposal_result.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/closing_agent_controller.dart';
import 'package:daftar/presentation/providers/closing_agent_state.dart';
import 'package:daftar/presentation/providers/closing_ritual_providers.dart';
import 'package:daftar/presentation/providers/connectivity_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockHydrateAgentIdTokenUseCase extends Mock
    implements HydrateAgentIdTokenUseCase {}

class MockRunClosingAgentTurnUseCase extends Mock
    implements RunClosingAgentTurnUseCase {}

class MockAnswerAskBooksUseCase extends Mock implements AnswerAskBooksUseCase {}

class MockCommitAgentProposalUseCase extends Mock
    implements CommitAgentProposalUseCase {}

class MockGetClosingDaySummaryUseCase extends Mock
    implements GetClosingDaySummaryUseCase {}

class MockUploadDriveBackupUseCase extends Mock
    implements UploadDriveBackupUseCase {}

class MockGetCollectionsCandidatesUseCase extends Mock
    implements GetCollectionsCandidatesUseCase {}

class MockBuildCollectionsDeskUseCase extends Mock
    implements BuildCollectionsDeskUseCase {}

class MockSaveCollectionsSendQueueUseCase extends Mock
    implements SaveCollectionsSendQueueUseCase {}

class MockLoadInFlightCollectionsSendQueueUseCase extends Mock
    implements LoadInFlightCollectionsSendQueueUseCase {}

class MockCompleteCollectionsSendQueueUseCase extends Mock
    implements CompleteCollectionsSendQueueUseCase {}

class MockDispatchCollectionsEmailUseCase extends Mock
    implements DispatchCollectionsEmailUseCase {}

class MockPlanCallBatchUseCase extends Mock implements PlanCallBatchUseCase {}

class MockRunCallBatchUseCase extends Mock implements RunCallBatchUseCase {}

class MockGetCallRunUseCase extends Mock implements GetCallRunUseCase {}

class MockPersistCollectionCallOutcomeUseCase extends Mock
    implements PersistCollectionCallOutcomeUseCase {}

class MockSynthesizeAgentSpeechUseCase extends Mock
    implements SynthesizeAgentSpeechUseCase {}

class MockCheckCreditLimitUseCase extends Mock
    implements CheckCreditLimitUseCase {}

void _noopDispatch(List<CollectionsDeskRow> rows) {}

final _driveBackupMetadata = BackupMetadata(
  id: 'backup-1',
  filePath: '/tmp/a.daftar',
  sizeBytes: 12,
  createdAt: DateTime.utc(2026, 8, 15),
  type: BackupType.googleDrive,
  checksum: 'abc',
);

const _planProposal = AgentProposal(
  proposalId: 'plan-1',
  tool: ProposalTool.proposeClosingPlan,
  confirmRequired: true,
  rawEnvelope: {},
  payload: AgentProposalPayload.closingPlan(steps: []),
);

const _emptySummary = ClosingDaySummary(
  localDay: '2026-08-15',
  debtCount: 0,
  paymentCount: 0,
  totals: [],
);

const _planCallFallback = CallPlanBatchRequest(
  batchId: '11111111-1111-4111-8111-111111111111',
  correlationId: '22222222-2222-4222-8222-222222222222',
  trigger: CallBatchTrigger.closeDay,
  dryRun: false,
  locale: 'en',
  recipients: [
    CallPlanRecipient(
      contactId: 'us',
      phoneE164: '+15555550100',
      region: 'US',
      locale: 'en',
      task: 'task',
      customerName: 'us',
      storeName: 'Daftar',
      amountLine: '1.00 USD',
    ),
  ],
);

const _runCallFallback = CallRunBatchRequest(
  batchId: '11111111-1111-4111-8111-111111111111',
  correlationId: '22222222-2222-4222-8222-222222222222',
  recipients: [
    CallRunRecipient(
      contactId: 'us',
      confirmHandle: 'handle-us',
    ),
  ],
);

const _queuedCallSeedFallback = CollectionCallBatchSeed(
  batchId: '11111111-1111-4111-8111-111111111111',
  correlationId: '22222222-2222-4222-8222-222222222222',
  trigger: CallBatchTrigger.closeDay,
  status: CallBatchStatus.running,
  runs: [
    CollectionCallRunSeed(
      contactId: 'us',
      region: 'US',
      locale: 'en',
      runId: 'run-us',
    ),
  ],
);

const _terminalCallWriteFallback = CollectionCallTerminalWrite(
  runId: 'run-us',
  contactId: 'us',
  rawStatus: 'completed',
  needsHuman: false,
);

CollectionsCandidate _candidate(
  String id, {
  String? email,
  OutreachRail rail = OutreachRail.email,
}) {
  return CollectionsCandidate(
    contactId: id,
    name: id,
    email: email,
    phone: '+96770000000$id',
    ledgerId: 'ledger',
    netBalance: -100,
    currencyCode: 'YER',
    ageDays: 12,
    toneBand: ReminderToneBand.reminder,
    rail: rail,
  );
}

void _dispatchRowsFallback(List<CollectionsDeskRow> rows) {}

void main() {
  late MockConnectivityService connectivity;
  late MockHydrateAgentIdTokenUseCase hydrate;
  late MockRunClosingAgentTurnUseCase runTurn;
  late MockAnswerAskBooksUseCase askBooks;
  late MockCommitAgentProposalUseCase commit;
  late MockGetClosingDaySummaryUseCase closingSummary;
  late MockUploadDriveBackupUseCase uploadBackup;
  late MockGetCollectionsCandidatesUseCase collectionsCandidates;
  late MockBuildCollectionsDeskUseCase buildDesk;
  late MockSaveCollectionsSendQueueUseCase saveQueue;
  late MockLoadInFlightCollectionsSendQueueUseCase loadQueue;
  late MockCompleteCollectionsSendQueueUseCase completeQueue;
  late MockDispatchCollectionsEmailUseCase dispatchEmail;
  late MockPlanCallBatchUseCase planCall;
  late MockRunCallBatchUseCase runCall;
  late MockGetCallRunUseCase getCall;
  late MockPersistCollectionCallOutcomeUseCase persistCall;
  late MockSynthesizeAgentSpeechUseCase synthesizeSpeech;
  late MockCheckCreditLimitUseCase checkCreditLimit;
  late List<String> openedPhones;

  setUpAll(() {
    registerFallbackValue(_planProposal);
    registerFallbackValue(_noopDispatch);
    registerFallbackValue(DateTime.utc(2026, 8, 15));
    registerFallbackValue(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [],
      ),
    );
    registerFallbackValue(
      CollectionsSendQueue(
        id: 'q',
        status: CollectionsSendQueueStatus.active,
        awaitingResume: false,
        locale: 'en',
        storeName: 'Daftar',
        ritual: const ClosingRitualResult(
          summary: _emptySummary,
          backupStatus: ClosingBackupStatus.uploaded,
          shortlist: [],
        ),
        rows: const [],
        createdAt: DateTime.utc(2026, 8, 15),
        updatedAt: DateTime.utc(2026, 8, 15),
      ),
    );
    registerFallbackValue(<CollectionsDeskRow>[]);
    registerFallbackValue(_dispatchRowsFallback);
    registerFallbackValue(_planCallFallback);
    registerFallbackValue(_runCallFallback);
    registerFallbackValue(CallBatchTrigger.closeDay);
    registerFallbackValue(_queuedCallSeedFallback);
    registerFallbackValue(_terminalCallWriteFallback);
    registerFallbackValue(
      AgentAudioClip(bytes: Uint8List.fromList(const [0])),
    );
  });

  tearDown(() {
    ClosingAgentController.ritualPulseDelay = const Duration(milliseconds: 120);
    ClosingAgentController.ritualStaggerDelay = const Duration(
      milliseconds: 140,
    );
    ClosingAgentController.callPollInitialDelay = const Duration(seconds: 60);
    ClosingAgentController.callPollInterval = const Duration(seconds: 7);
    ClosingAgentController.callPollTimeout = const Duration(minutes: 10);
    DeviceTts.debugSpeakOverride = null;
    DeviceTts.debugStopOverride = null;
    DeviceTts.debugReset();
    AgentSpeech.debugReset();
  });

  setUp(() {
    ClosingAgentController.ritualPulseDelay = Duration.zero;
    ClosingAgentController.ritualStaggerDelay = Duration.zero;
    ClosingAgentController.callPollInitialDelay = Duration.zero;
    ClosingAgentController.callPollInterval = Duration.zero;
    ClosingAgentController.callPollTimeout = Duration.zero;
    connectivity = MockConnectivityService();
    hydrate = MockHydrateAgentIdTokenUseCase();
    runTurn = MockRunClosingAgentTurnUseCase();
    askBooks = MockAnswerAskBooksUseCase();
    commit = MockCommitAgentProposalUseCase();
    closingSummary = MockGetClosingDaySummaryUseCase();
    uploadBackup = MockUploadDriveBackupUseCase();
    collectionsCandidates = MockGetCollectionsCandidatesUseCase();
    buildDesk = MockBuildCollectionsDeskUseCase();
    saveQueue = MockSaveCollectionsSendQueueUseCase();
    loadQueue = MockLoadInFlightCollectionsSendQueueUseCase();
    completeQueue = MockCompleteCollectionsSendQueueUseCase();
    dispatchEmail = MockDispatchCollectionsEmailUseCase();
    planCall = MockPlanCallBatchUseCase();
    runCall = MockRunCallBatchUseCase();
    getCall = MockGetCallRunUseCase();
    persistCall = MockPersistCollectionCallOutcomeUseCase();
    synthesizeSpeech = MockSynthesizeAgentSpeechUseCase();
    checkCreditLimit = MockCheckCreditLimitUseCase();
    openedPhones = <String>[];
    when(() => checkCreditLimit.execute(any())).thenAnswer(
      (_) async => const Right(CreditWarningLevel.none),
    );
    when(
      () => synthesizeSpeech.execute(
        text: any(named: 'text'),
        locale: any(named: 'locale'),
      ),
    ).thenAnswer(
      (_) async => const Left(
        NetworkFailure('tts unavailable', code: 'agent_tts_failed'),
      ),
    );
    when(
      () => hydrate.execute(),
    ).thenAnswer((_) async => const Right('id-token'));
    when(() => planCall.execute(any())).thenAnswer((invocation) async {
      final request =
          invocation.positionalArguments.first as CallPlanBatchRequest;
      return Right(
        CallPlanBatchResponse(
          batchId: request.batchId,
          results: [
            for (final recipient in request.recipients)
              CallPlanRowResult(
                contactId: recipient.contactId,
                phoneMasked: '+…0000',
                readyToRun: true,
                status: CallPlanRowStatus.planned,
                confirmHandle: 'handle-${recipient.contactId}',
              ),
          ],
        ),
      );
    });
    when(() => runCall.execute(any())).thenAnswer((invocation) async {
      final request =
          invocation.positionalArguments.first as CallRunBatchRequest;
      return Right(
        CallRunBatchResponse(
          batchId: request.batchId,
          needsHuman: false,
          results: [
            for (final recipient in request.recipients)
              CallRunRowResult(
                contactId: recipient.contactId,
                status: CallRunRemoteStatus.queued,
                runId: 'run-${recipient.contactId}',
              ),
          ],
        ),
      );
    });
    when(() => getCall.execute(any())).thenAnswer((invocation) async {
      final runId = invocation.positionalArguments.first as String;
      return Right(
        CallGetResult(
          runId: runId,
          status: 'completed',
          terminal: true,
          phoneMasked: '+…0000',
          needsHuman: false,
          structuredResult: const CallStructuredOutcome(
            outcome: CallRunOutcome.promised,
            promisedAmountMinor: 100,
            promisedCurrency: 'USD',
            promisedDate: '2026-09-10',
          ),
        ),
      );
    });
    when(() => persistCall.persistQueued(any())).thenAnswer(
      (_) async => const Right(unit),
    );
    when(() => persistCall.persistTerminal(any())).thenAnswer(
      (_) async => const Right(unit),
    );
    when(() => saveQueue.execute(any())).thenAnswer(
      (_) async => const Right(unit),
    );
    when(() => loadQueue.execute()).thenAnswer((_) async => const Right(null));
    when(() => completeQueue.execute(any())).thenAnswer(
      (_) async => const Right(unit),
    );
    when(
      () => buildDesk.execute(
        any(),
        trigger: any(named: 'trigger'),
        allowlistRegion: any(named: 'allowlistRegion'),
      ),
    ).thenAnswer((invocation) async {
      final ritualResult =
          invocation.positionalArguments.first as ClosingRitualResult;
      return Right(
        CollectionsDeskBuildResult(
          rows: [
            for (final candidate in ritualResult.shortlist)
              CollectionsDeskRow(
                candidate: candidate,
                body: 'body-${candidate.contactId}',
                toneBand: candidate.toneBand,
                attachPdf: ritualResult.pdfContacts.any(
                  (row) => row.contactId == candidate.contactId,
                ),
              ),
          ],
          locale: 'en',
          storeName: 'Daftar',
        ),
      );
    });
    when(
      () => connectivity.currentStatus(),
    ).thenAnswer((_) async => ConnectivityStatus.offline);
    when(
      () => commit.execute(
        proposal: any(named: 'proposal'),
        ledgerIdOverride: any(named: 'ledgerIdOverride'),
        currencyCodeOverride: any(named: 'currencyCodeOverride'),
        contactIdOverride: any(named: 'contactIdOverride'),
        nameOverride: any(named: 'nameOverride'),
        phoneOverride: any(named: 'phoneOverride'),
        ledgerNameOverride: any(named: 'ledgerNameOverride'),
        amountMinorOverride: any(named: 'amountMinorOverride'),
        createIfMissing: any(named: 'createIfMissing'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        ConfirmProposalResult(
          proposalId: 'plan-1',
          status: ConfirmProposalStatus.committed,
        ),
      ),
    );
  });

  ProviderContainer container({
    AppSettings settings = const AppSettings(),
    CalleDevicePolicy? callePolicy,
  }) {
    return ProviderContainer(
      overrides: [
        connectivityServiceProvider.overrideWith((ref) => connectivity),
        hydrateAgentIdTokenUseCaseProvider.overrideWith((ref) => hydrate),
        runClosingAgentTurnUseCaseProvider.overrideWith((ref) => runTurn),
        answerAskBooksUseCaseProvider.overrideWith((ref) => askBooks),
        commitAgentProposalUseCaseProvider.overrideWith((ref) => commit),
        getClosingDaySummaryUseCaseProvider.overrideWith(
          (ref) => closingSummary,
        ),
        uploadDriveBackupUseCaseProvider.overrideWith((ref) => uploadBackup),
        getCollectionsCandidatesUseCaseProvider.overrideWith(
          (ref) => collectionsCandidates,
        ),
        buildCollectionsDeskUseCaseProvider.overrideWith((ref) => buildDesk),
        saveCollectionsSendQueueUseCaseProvider.overrideWith(
          (ref) => saveQueue,
        ),
        loadInFlightCollectionsSendQueueUseCaseProvider.overrideWith(
          (ref) => loadQueue,
        ),
        completeCollectionsSendQueueUseCaseProvider.overrideWith(
          (ref) => completeQueue,
        ),
        dispatchCollectionsEmailUseCaseProvider.overrideWith(
          (ref) => dispatchEmail,
        ),
        planCallBatchUseCaseProvider.overrideWith((ref) => planCall),
        runCallBatchUseCaseProvider.overrideWith((ref) => runCall),
        getCallRunUseCaseProvider.overrideWith((ref) => getCall),
        persistCollectionCallOutcomeUseCaseProvider.overrideWith(
          (ref) => persistCall,
        ),
        synthesizeAgentSpeechUseCaseProvider.overrideWith(
          (ref) => synthesizeSpeech,
        ),
        checkCreditLimitUseCaseProvider.overrideWith((ref) => checkCreditLimit),
        collectionsWhatsAppOpenerProvider.overrideWith(
          (ref) => CollectionsWhatsAppLauncher(
            openImpl: ({required phone, message}) async {
              openedPhones.add(phone);
              return true;
            },
          ),
        ),
        appSettingsProvider.overrideWithValue(AsyncValue.data(settings)),
        if (callePolicy != null)
          calleDevicePolicyProvider.overrideWithValue(callePolicy),
      ],
    );
  }

  void stubAsk(AskBooksAnswer answer) {
    when(
      () => askBooks.execute(
        goalText: any(named: 'goalText'),
        forceAsk: any(named: 'forceAsk'),
        nameHint: any(named: 'nameHint'),
        lastContactId: any(named: 'lastContactId'),
      ),
    ).thenAnswer((_) async => Right(answer));
  }

  test(
    'airplane skips hydrate and /run; capture goal returns to idle',
    () async {
      final c = container();
      addTearDown(c.dispose);

      await c
          .read(closingAgentControllerProvider.notifier)
          .submitGoal(
            'Mohamed owes 500',
          );

      final state = c.read(closingAgentControllerProvider);
      expect(state.phase, ClosingAgentPhase.idle);
      expect(state.actionFailure, isA<NetworkFailure>());
      expect(state.actionFailure?.code, 'closing_agent_request_failed');
      verifyNever(() => hydrate.execute());
      verifyNever(
        () => runTurn.execute(
          goalText: any(named: 'goalText'),
          audioClip: any(named: 'audioClip'),
        ),
      );
      verifyNever(
        () => askBooks.execute(
          goalText: any(named: 'goalText'),
          forceAsk: any(named: 'forceAsk'),
          nameHint: any(named: 'nameHint'),
          lastContactId: any(named: 'lastContactId'),
        ),
      );
    },
  );

  test(
    'voice clip skips local ask and does not call /run when offline',
    () async {
      stubAsk(const AskBooksOverdueList([]));
      final c = container();
      addTearDown(c.dispose);

      await c
          .read(closingAgentControllerProvider.notifier)
          .submitVoice(
            AgentAudioClip(bytes: Uint8List.fromList(const [1, 2, 3])),
          );

      final state = c.read(closingAgentControllerProvider);
      expect(state.phase, ClosingAgentPhase.idle);
      verifyNever(
        () => askBooks.execute(
          goalText: any(named: 'goalText'),
          forceAsk: any(named: 'forceAsk'),
          nameHint: any(named: 'nameHint'),
          lastContactId: any(named: 'lastContactId'),
        ),
      );
      verifyNever(
        () => runTurn.execute(
          goalText: any(named: 'goalText'),
          audioClip: any(named: 'audioClip'),
        ),
      );
    },
  );

  test(
    'airplane keeps Drift ask answer and skips Cloud Run without failure',
    () async {
      const overdue = AskBooksOverdueList([]);
      stubAsk(overdue);

      final c = container();
      addTearDown(c.dispose);

      await c
          .read(closingAgentControllerProvider.notifier)
          .submitGoal('who is overdue');

      final state = c.read(closingAgentControllerProvider);
      expect(state.phase, ClosingAgentPhase.ready);
      expect(state.askAnswer, overdue);
      expect(state.actionFailure, isNull);
      verify(
        () => askBooks.execute(
          goalText: 'who is overdue',
          forceAsk: any(named: 'forceAsk'),
          nameHint: any(named: 'nameHint'),
          lastContactId: any(named: 'lastContactId'),
        ),
      ).called(1);
      verifyNever(() => hydrate.execute());
      verifyNever(
        () => runTurn.execute(
          goalText: any(named: 'goalText'),
          audioClip: any(named: 'audioClip'),
        ),
      );
    },
  );

  test('online ask skips hydrate and /run', () async {
    when(
      () => connectivity.currentStatus(),
    ).thenAnswer((_) async => ConnectivityStatus.online);
    const overdue = AskBooksOverdueList([]);
    stubAsk(overdue);

    final c = container();
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .submitGoal('who is overdue');

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ready);
    expect(state.askAnswer, overdue);
    expect(state.actionFailure, isNull);
    verifyNever(() => hydrate.execute());
    verifyNever(
      () => runTurn.execute(
        goalText: any(named: 'goalText'),
        audioClip: any(named: 'audioClip'),
      ),
    );
  });

  void stubRitual(ClosingRitualResult result) {
    when(
      () => closingSummary.execute(
        localDay: any(named: 'localDay'),
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) async => Right(result.summary));
    when(() => uploadBackup.call()).thenAnswer((_) async {
      return switch (result.backupStatus) {
        ClosingBackupStatus.uploaded => Right(_driveBackupMetadata),
        ClosingBackupStatus.failed => const Left(
          StorageFailure('upload failed', code: 'backup_failed'),
        ),
        ClosingBackupStatus.skippedUnsigned => const Left(
          AuthFailure('not signed in', code: 'google_not_signed_in'),
        ),
        ClosingBackupStatus.queued => const Left(
          NetworkFailure('queued', code: kBackupInProgressFailureCode),
        ),
        ClosingBackupStatus.grantRequired => const Left(
          AuthFailure('silent', code: 'silent_sign_in_failed'),
        ),
      };
    });
    when(
      () => collectionsCandidates.execute(
        asOf: any(named: 'asOf'),
        allowlist: any(named: 'allowlist'),
        allowlistRegion: any(named: 'allowlistRegion'),
        contactId: any(named: 'contactId'),
      ),
    ).thenAnswer(
      (_) async => Right(result.shortlist),
    );
  }

  test('plan confirm starts the ritual', () async {
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [],
      ),
    );
    final c = container();
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .confirm(_planProposal);

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualReport);
    expect(state.committedIds, contains('plan-1'));
    verify(
      () => closingSummary.execute(
        localDay: any(named: 'localDay'),
        now: any(named: 'now'),
      ),
    ).called(1);
    verify(() => uploadBackup.call()).called(1);
    verify(
      () => collectionsCandidates.execute(
        asOf: any(named: 'asOf'),
        allowlist: any(named: 'allowlist'),
        allowlistRegion: any(named: 'allowlistRegion'),
      ),
    ).called(1);
  });

  test('plan confirm completes ritual task graph on empty overdue', () async {
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [],
      ),
    );
    final c = container();
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .confirm(_planProposal);

    final state = c.read(closingAgentControllerProvider);
    expect(state.ritualTasksDone, contains(ClosingTaskId.presentSeal));
    expect(
      state.ritualTasksSkipped,
      contains(ClosingTaskId.openCollectionsDesk),
    );
  });

  test('empty overdue skips reminder prompts', () async {
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [],
      ),
    );
    final c = container();
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .confirm(_planProposal);

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualReport);
    expect(state.ritualPromptKind, isNull);
    expect(state.ritualResult?.shortlist, isEmpty);
  });

  test('Confirm without sending still opens the desk', () async {
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [_candidate('a'), _candidate('b')],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(_planProposal);

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualDesk);
    expect(state.sendOutreachEnabled, isFalse);
    expect(state.deskRows, hasLength(2));
    verifyNever(
      () => dispatchEmail.execute(
        rows: any(named: 'rows'),
        locale: any(named: 'locale'),
        storeName: any(named: 'storeName'),
        batchId: any(named: 'batchId'),
        correlationId: any(named: 'correlationId'),
        isRtl: any(named: 'isRtl'),
        onRows: any(named: 'onRows'),
      ),
    );
  });

  test('Confirm without sending keeps call set on the desk', () async {
    const usPhone = '+15555550100';
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          CollectionsCandidate(
            contactId: 'us',
            name: 'us',
            email: 'us@example.com',
            phone: usPhone,
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'USD',
            ageDays: 12,
            toneBand: ReminderToneBand.reminder,
            rail: OutreachRail.both,
          ),
        ],
      ),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: false,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(_planProposal);

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualDesk);
    expect(state.sendOutreachEnabled, isFalse);
    expect(state.deskCallCount, 1);
    expect(state.callConsented, isFalse);
  });

  test('send set is min(shortlist, 20) with PDF on ranked Top 5', () async {
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          for (var i = 0; i < 8; i++) _candidate('$i'),
        ],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualDesk);
    expect(state.ritualResult?.reminderPolicy, ClosingReminderPolicy.all);
    expect(state.ritualResult?.pdfPolicy, ClosingPdfPolicy.rankedTop5);
    expect(state.ritualResult?.reminderSet, hasLength(8));
    expect(state.deskRows, hasLength(8));
    expect(
      state.deskRows.take(5).every((row) => row.attachPdf),
      isTrue,
    );
    expect(
      state.deskRows.skip(5).every((row) => !row.attachPdf),
      isTrue,
    );
  });

  test('desk shows full shortlist; email send set caps at 20', () async {
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          for (var i = 0; i < 25; i++) _candidate('$i'),
        ],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    await c
        .read(closingAgentControllerProvider.notifier)
        .confirm(
          _planProposal,
          sendOutreach: true,
        );
    final state = c.read(closingAgentControllerProvider);
    expect(state.deskRows, hasLength(25));
    expect(state.ritualResult?.reminderSet, hasLength(20));
    expect(state.deskRows.take(5).every((row) => row.attachPdf), isTrue);
    expect(state.deskRows.skip(5).every((row) => !row.attachPdf), isTrue);
  });

  test('non-empty shortlist opens the Desk with attach on', () async {
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [_candidate('a'), _candidate('b')],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualDesk);
    expect(state.deskRows, hasLength(2));
    expect(state.deskRows.every((row) => row.attachPdf), isTrue);
  });

  test('skip-all desk rows shows the report', () async {
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [_candidate('a'), _candidate('b')],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.skipDeskRow('a');
    await notifier.skipDeskRow('b');

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualReport);
    expect(
      state.deskRows.every(
        (row) => row.status == CollectionsDeskRowStatus.skipped,
      ),
      isTrue,
    );
    expect(
      state.ritualResult?.queueMetrics,
      const CollectionsQueueMetrics(prepared: 2, opened: 0, skipped: 2),
    );
    verifyNever(() => completeQueue.execute(any()));
  });

  test('Start sending opens only the first pending row', () async {
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [_candidate('a'), _candidate('b')],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.startSending(sharePdf: (_) async => true);

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualDesk);
    expect(openedPhones, isEmpty);
    expect(state.deskRows.first.status, CollectionsDeskRowStatus.opened);
    expect(state.deskRows.last.status, CollectionsDeskRowStatus.pending);
    expect(state.queueStatus, CollectionsSendQueueStatus.active);
    expect(state.queueAwaitingResume, isTrue);
    verify(() => saveQueue.execute(any())).called(greaterThan(0));
  });

  test('host resume after Open does not launch another WhatsApp', () async {
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [_candidate('a'), _candidate('b')],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.startSending(sharePdf: (_) async => true);
    expect(openedPhones, isEmpty);
    expect(
      c.read(closingAgentControllerProvider).queueAwaitingResume,
      isTrue,
    );

    await notifier.onHostResumed();

    final state = c.read(closingAgentControllerProvider);
    expect(openedPhones, isEmpty);
    expect(state.queueAwaitingResume, isFalse);
    expect(state.firstPendingDeskRow?.candidate.contactId, 'b');
    expect(state.queueSendingIndex, 2);
  });

  test('pause blocks resume-advance', () async {
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [_candidate('a'), _candidate('b')],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.startSending(sharePdf: (_) async => true);
    await notifier.pauseSendQueue();
    await notifier.onHostResumed();

    final state = c.read(closingAgentControllerProvider);
    expect(state.queueStatus, CollectionsSendQueueStatus.paused);
    expect(openedPhones, isEmpty);
  });

  test('hydrate restores an in-flight queue onto the Desk', () async {
    when(() => loadQueue.execute()).thenAnswer(
      (_) async => Right(
        CollectionsSendQueue(
          id: 'q-restore',
          status: CollectionsSendQueueStatus.active,
          awaitingResume: true,
          locale: 'ar',
          storeName: 'Daftar',
          ritual: ClosingRitualResult(
            summary: _emptySummary,
            backupStatus: ClosingBackupStatus.uploaded,
            shortlist: [_candidate('a')],
            reminderPolicy: ClosingReminderPolicy.all,
          ),
          rows: [
            CollectionsDeskRow(
              candidate: _candidate('a'),
              body: 'body-a',
              toneBand: ReminderToneBand.reminder,
              attachPdf: false,
            ),
          ],
          createdAt: DateTime.utc(2026, 8, 15),
          updatedAt: DateTime.utc(2026, 8, 15),
        ),
      ),
    );
    final c = container();
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .hydrateInFlightQueue();

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualDesk);
    expect(state.queueId, 'q-restore');
    expect(state.deskRows, hasLength(1));
    expect(state.deskLocale, 'ar');
    expect(state.queueAwaitingResume, isFalse);
    expect(openedPhones, isEmpty);
    verify(() => saveQueue.execute(any())).called(1);
  });

  test('finishDesk after Start sending reports opened and skipped', () async {
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [_candidate('a'), _candidate('b')],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.startSending(sharePdf: (_) async => true);
    await notifier.finishDesk();

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualReport);
    expect(
      state.ritualResult?.queueMetrics,
      const CollectionsQueueMetrics(prepared: 2, opened: 1, skipped: 1),
    );
    verify(() => completeQueue.execute(any())).called(1);
  });

  test('finishDesk attaches call report from progress and shortlist', () async {
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          _candidate(
            'mohamed',
            email: 'm@example.com',
            rail: OutreachRail.both,
          ),
          _candidate(
            'ye',
            email: 'y@example.com',
            rail: OutreachRail.callUnavailable,
          ),
        ],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    notifier.state = notifier.state.copyWith(
      callProgress: const CollectionsCallProgress(
        results: [
          CollectionsCallProgressRow(
            contactId: 'mohamed',
            status: CollectionsCallRowStatus.completed,
            runId: 'call_GfN-BQcGMORm2NkgSfxdIw',
            outcome: CallRunOutcome.promised,
            promisedAmountMinor: 50000,
            promisedCurrency: 'USD',
            promisedDate: '2026-09-15',
          ),
        ],
      ),
    );
    await notifier.finishDesk();

    final report = c
        .read(closingAgentControllerProvider)
        .ritualResult
        ?.callReport;
    expect(report?.rows, hasLength(2));
    expect(report?.rows.first.contactId, 'mohamed');
    expect(report?.rows.first.hasDisplayPromise, isTrue);
    expect(report?.rows.first.promisedAmountMinor, 50000);
    expect(
      report?.rows.last.status,
      CollectionsCallReportStatus.callUnavailable,
    );
  });

  test('share-sheet cancel does not mark the row opened', () async {
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [_candidate('a'), _candidate('b')],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.startSending(sharePdf: (_) async => false);

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualDesk);
    expect(state.deskRows.first.status, CollectionsDeskRowStatus.pending);
    expect(openedPhones, isEmpty);
  });

  test('queue persist Left surfaces actionFailure', () async {
    when(() => saveQueue.execute(any())).thenAnswer(
      (_) async => const Left(
        DatabaseFailure('persist failed', code: 'queue_save_failed'),
      ),
    );
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [_candidate('a'), _candidate('b')],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.startSending(sharePdf: (_) async => true);

    final state = c.read(closingAgentControllerProvider);
    expect(state.actionFailure, isA<DatabaseFailure>());
    expect(state.actionFailure?.code, 'queue_save_failed');
    verify(() => saveQueue.execute(any())).called(greaterThan(0));
  });

  test('Open while paused does not set awaitingResume', () async {
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [_candidate('a'), _candidate('b'), _candidate('c')],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.startSending(sharePdf: (_) async => true);
    await notifier.pauseSendQueue();
    await notifier.openDeskRow(
      contactId: 'b',
      sharePdf: (_) async => true,
    );

    final state = c.read(closingAgentControllerProvider);
    expect(state.queueStatus, CollectionsSendQueueStatus.paused);
    expect(state.queueAwaitingResume, isFalse);
    expect(
      state.deskRows.firstWhere((row) => row.candidate.contactId == 'b').status,
      CollectionsDeskRowStatus.opened,
    );
    expect(state.deskRows.last.status, CollectionsDeskRowStatus.pending);
  });

  test(
    'Approve & send uses dispatch metrics and never opens WhatsApp',
    () async {
      when(
        () => dispatchEmail.execute(
          rows: any(named: 'rows'),
          locale: any(named: 'locale'),
          storeName: any(named: 'storeName'),
          batchId: any(named: 'batchId'),
          correlationId: any(named: 'correlationId'),
          isRtl: any(named: 'isRtl'),
          onRows: any(named: 'onRows'),
        ),
      ).thenAnswer((invocation) async {
        final rows =
            invocation.namedArguments[#rows]! as List<CollectionsDeskRow>;
        final onRows =
            invocation.namedArguments[#onRows]
                as void Function(List<CollectionsDeskRow>)?;
        final sent = [
          for (final row in rows)
            row.copyWith(
              status: CollectionsDeskRowStatus.sent,
              smtpCode: 250,
              smtpMessageId: '<mid@gmail.com>',
            ),
        ];
        onRows?.call(sent);
        return Right(
          DispatchCollectionsEmailResult(
            rows: sent,
            metrics: CollectionsQueueMetrics.fromRows(sent),
          ),
        );
      });
      stubRitual(
        ClosingRitualResult(
          summary: _emptySummary,
          backupStatus: ClosingBackupStatus.uploaded,
          shortlist: [_candidate('a'), _candidate('b')],
        ),
      );
      final c = container();
      addTearDown(c.dispose);
      final notifier = c.read(closingAgentControllerProvider.notifier);

      await notifier.confirm(_planProposal, sendOutreach: true);
      await notifier.approveAndSend();

      final state = c.read(closingAgentControllerProvider);
      expect(state.phase, ClosingAgentPhase.ritualReport);
      expect(openedPhones, isEmpty);
      expect(
        state.ritualResult?.queueMetrics,
        const CollectionsQueueMetrics(
          prepared: 2,
          opened: 0,
          skipped: 0,
          sent: 2,
        ),
      );
      expect(state.isQueueInFlight, isFalse);
      final saved =
          verify(() => saveQueue.execute(captureAny())).captured.single
              as CollectionsSendQueue;
      expect(saved.status, CollectionsSendQueueStatus.completed);
      expect(saved.batchId, isNotNull);
    },
  );

  test('Approve send-set metrics cover all 8 rows not Top 5 only', () async {
    late List<CollectionsDeskRow> dispatched;
    when(
      () => dispatchEmail.execute(
        rows: any(named: 'rows'),
        locale: any(named: 'locale'),
        storeName: any(named: 'storeName'),
        batchId: any(named: 'batchId'),
        correlationId: any(named: 'correlationId'),
        isRtl: any(named: 'isRtl'),
        onRows: any(named: 'onRows'),
      ),
    ).thenAnswer((invocation) async {
      dispatched =
          invocation.namedArguments[#rows]! as List<CollectionsDeskRow>;
      final onRows =
          invocation.namedArguments[#onRows]
              as void Function(List<CollectionsDeskRow>)?;
      final sent = [
        for (final row in dispatched)
          row.copyWith(
            status: CollectionsDeskRowStatus.sent,
            smtpCode: 250,
            smtpMessageId: '<mid@gmail.com>',
          ),
      ];
      onRows?.call(sent);
      return Right(
        DispatchCollectionsEmailResult(
          rows: sent,
          metrics: CollectionsQueueMetrics.fromRows(sent),
        ),
      );
    });
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          for (var i = 0; i < 8; i++) _candidate('$i'),
        ],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );

    final desk = c.read(closingAgentControllerProvider);
    expect(desk.deskRows, hasLength(8));
    expect(desk.deskRows.take(5).every((row) => row.attachPdf), isTrue);
    expect(desk.deskRows.skip(5).every((row) => !row.attachPdf), isTrue);

    await notifier.approveAndSend();

    final state = c.read(closingAgentControllerProvider);
    expect(dispatched, hasLength(8));
    expect(dispatched.take(5).every((row) => row.attachPdf), isTrue);
    expect(dispatched.skip(5).every((row) => !row.attachPdf), isTrue);
    expect(state.phase, ClosingAgentPhase.ritualReport);
    expect(openedPhones, isEmpty);
    expect(
      state.ritualResult?.queueMetrics,
      const CollectionsQueueMetrics(
        prepared: 8,
        opened: 0,
        skipped: 0,
        sent: 8,
      ),
    );
  });

  test('Confirm and Call hits plan then run then GET', () async {
    const usPhone = '+15555550100';
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          CollectionsCandidate(
            contactId: 'us',
            name: 'us',
            email: 'us@example.com',
            phone: usPhone,
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'USD',
            ageDays: 12,
            toneBand: ReminderToneBand.reminder,
            rail: OutreachRail.both,
          ),
        ],
      ),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.confirmAndCall();

    final state = c.read(closingAgentControllerProvider);
    expect(state.callConsented, isTrue);
    expect(state.callProgress?.total, 1);
    expect(
      state.callProgress?.results.single.status,
      CollectionsCallRowStatus.completed,
    );
    verify(() => planCall.execute(any())).called(1);
    verify(() => runCall.execute(any())).called(1);
    verify(() => getCall.execute('run-us')).called(1);
    verifyNever(
      () => dispatchEmail.execute(
        rows: any(named: 'rows'),
        locale: any(named: 'locale'),
        storeName: any(named: 'storeName'),
        batchId: any(named: 'batchId'),
        correlationId: any(named: 'correlationId'),
        isRtl: any(named: 'isRtl'),
        onRows: any(named: 'onRows'),
      ),
    );
  });

  test(
    'Confirm and Call completed without outcome has no error sheet',
    () async {
      const usPhone = '+15555550100';
      when(() => getCall.execute(any())).thenAnswer((invocation) async {
        final runId = invocation.positionalArguments.first as String;
        return Right(
          CallGetResult(
            runId: runId,
            status: 'completed',
            terminal: true,
            taskCompleted: true,
            phoneMasked: '+…0000',
            needsHuman: true,
          ),
        );
      });
      stubRitual(
        const ClosingRitualResult(
          summary: _emptySummary,
          backupStatus: ClosingBackupStatus.uploaded,
          shortlist: [
            CollectionsCandidate(
              contactId: 'us',
              name: 'us',
              email: 'us@example.com',
              phone: usPhone,
              ledgerId: 'ledger',
              netBalance: -100,
              currencyCode: 'USD',
              ageDays: 12,
              toneBand: ReminderToneBand.reminder,
              rail: OutreachRail.both,
            ),
          ],
        ),
      );
      final c = container(
        callePolicy: const CalleDevicePolicy(
          allowDial: true,
          allowlist: {usPhone},
          allowlistRegion: 'US',
        ),
      );
      addTearDown(c.dispose);
      final notifier = c.read(closingAgentControllerProvider.notifier);

      await notifier.confirm(
        _planProposal,
        sendOutreach: true,
      );
      await notifier.confirmAndCall();

      final state = c.read(closingAgentControllerProvider);
      expect(state.actionFailure, isNull);
      expect(
        state.callProgress?.results.single.status,
        CollectionsCallRowStatus.completed,
      );
    },
  );

  test('Confirm and Call omits YE from plan-batch', () async {
    const usPhone = '+15555550100';
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          CollectionsCandidate(
            contactId: 'us',
            name: 'us',
            email: 'us@example.com',
            phone: usPhone,
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'USD',
            ageDays: 12,
            toneBand: ReminderToneBand.reminder,
            rail: OutreachRail.both,
          ),
          CollectionsCandidate(
            contactId: 'ye',
            name: 'ye',
            email: 'ye@example.com',
            phone: '+967771234567',
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'YER',
            ageDays: 20,
            toneBand: ReminderToneBand.firm,
            rail: OutreachRail.callUnavailable,
          ),
        ],
      ),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.confirmAndCall();

    final planCaptured = verify(() => planCall.execute(captureAny())).captured;
    expect(planCaptured, hasLength(1));
    final request = planCaptured.single as CallPlanBatchRequest;
    expect(request.recipients, hasLength(1));
    expect(request.recipients.single.contactId, 'us');
  });

  test(
    'Arabic deskLocale on US Confirm and Call sends en-US and English C.3',
    () async {
      const usPhone = '+15555550100';
      when(
        () => buildDesk.execute(
          any(),
          trigger: any(named: 'trigger'),
          allowlistRegion: any(named: 'allowlistRegion'),
        ),
      ).thenAnswer((invocation) async {
        final ritualResult =
            invocation.positionalArguments.first as ClosingRitualResult;
        return Right(
          CollectionsDeskBuildResult(
            rows: [
              for (final candidate in ritualResult.shortlist)
                CollectionsDeskRow(
                  candidate: candidate,
                  body: 'body-${candidate.contactId}',
                  customerName: candidate.name,
                  storeName: 'Daftar',
                  amountLine: '1.00 \$',
                  callTask: 'اتصل بـ${candidate.name} نيابةً عن Daftar.',
                  toneBand: candidate.toneBand,
                  attachPdf: false,
                ),
            ],
            locale: 'ar',
            storeName: 'Daftar',
          ),
        );
      });
      stubRitual(
        const ClosingRitualResult(
          summary: _emptySummary,
          backupStatus: ClosingBackupStatus.uploaded,
          shortlist: [
            CollectionsCandidate(
              contactId: 'us',
              name: 'Mohamed',
              email: 'us@example.com',
              phone: usPhone,
              ledgerId: 'ledger',
              netBalance: -100,
              currencyCode: 'USD',
              ageDays: 12,
              toneBand: ReminderToneBand.reminder,
              rail: OutreachRail.both,
            ),
          ],
        ),
      );
      final c = container(
        callePolicy: const CalleDevicePolicy(
          allowDial: true,
          allowlist: {usPhone},
          allowlistRegion: 'US',
        ),
      );
      addTearDown(c.dispose);
      final notifier = c.read(closingAgentControllerProvider.notifier);

      await notifier.confirm(
        _planProposal,
        sendOutreach: true,
      );
      await notifier.confirmAndCall();

      final state = c.read(closingAgentControllerProvider);
      expect(state.deskLocale, 'ar');
      expect(state.actionFailure, isNull);
      final planCaptured = verify(
        () => planCall.execute(captureAny()),
      ).captured;
      final request = planCaptured.single as CallPlanBatchRequest;
      expect(request.locale, 'ar');
      expect(request.recipients.single.locale, 'en-US');
      expect(request.recipients.single.task, contains('Call Mohamed'));
      expect(request.recipients.single.task, isNot(contains('اتصل')));
    },
  );

  test(
    'approveAndSend still dispatches YE after Confirm and Call omits YE',
    () async {
      const usPhone = '+15555550100';
      late List<CollectionsDeskRow> dispatched;
      when(
        () => dispatchEmail.execute(
          rows: any(named: 'rows'),
          locale: any(named: 'locale'),
          storeName: any(named: 'storeName'),
          batchId: any(named: 'batchId'),
          correlationId: any(named: 'correlationId'),
          isRtl: any(named: 'isRtl'),
          onRows: any(named: 'onRows'),
        ),
      ).thenAnswer((invocation) async {
        dispatched = List<CollectionsDeskRow>.from(
          invocation.namedArguments[#rows]! as List<CollectionsDeskRow>,
        );
        final onRows =
            invocation.namedArguments[#onRows]
                as void Function(List<CollectionsDeskRow>)?;
        final sent = [
          for (final row in dispatched)
            row.copyWith(
              status: CollectionsDeskRowStatus.sent,
              smtpCode: 250,
              smtpMessageId: '<mid@gmail.com>',
            ),
        ];
        onRows?.call(sent);
        return Right(
          DispatchCollectionsEmailResult(
            rows: sent,
            metrics: CollectionsQueueMetrics.fromRows(sent),
          ),
        );
      });
      stubRitual(
        const ClosingRitualResult(
          summary: _emptySummary,
          backupStatus: ClosingBackupStatus.uploaded,
          shortlist: [
            CollectionsCandidate(
              contactId: 'us',
              name: 'us',
              email: 'us@example.com',
              phone: usPhone,
              ledgerId: 'ledger',
              netBalance: -100,
              currencyCode: 'USD',
              ageDays: 12,
              toneBand: ReminderToneBand.reminder,
              rail: OutreachRail.both,
            ),
            CollectionsCandidate(
              contactId: 'ye',
              name: 'ye',
              email: 'ye@example.com',
              phone: '+967771234567',
              ledgerId: 'ledger',
              netBalance: -100,
              currencyCode: 'YER',
              ageDays: 20,
              toneBand: ReminderToneBand.firm,
              rail: OutreachRail.callUnavailable,
            ),
          ],
        ),
      );
      final c = container(
        callePolicy: const CalleDevicePolicy(
          allowDial: true,
          allowlist: {usPhone},
          allowlistRegion: 'US',
        ),
      );
      addTearDown(c.dispose);
      final notifier = c.read(closingAgentControllerProvider.notifier);

      await notifier.confirm(
        _planProposal,
        sendOutreach: true,
      );
      await notifier.confirmAndCall();

      final planCaptured = verify(
        () => planCall.execute(captureAny()),
      ).captured;
      final planRequest = planCaptured.last as CallPlanBatchRequest;
      expect(planRequest.recipients, hasLength(1));
      expect(planRequest.recipients.single.contactId, 'us');

      await notifier.approveAndSend();

      expect(
        dispatched.map((row) => row.candidate.contactId),
        containsAll(['us', 'ye']),
      );
    },
  );

  test(
    'commitDeskOutreach both queues approveAndSend after call terminal',
    () async {
      const usPhone = '+15555550100';
      var dispatchCount = 0;
      when(
        () => dispatchEmail.execute(
          rows: any(named: 'rows'),
          locale: any(named: 'locale'),
          storeName: any(named: 'storeName'),
          batchId: any(named: 'batchId'),
          correlationId: any(named: 'correlationId'),
          isRtl: any(named: 'isRtl'),
          onRows: any(named: 'onRows'),
        ),
      ).thenAnswer((invocation) async {
        dispatchCount += 1;
        final rows = List<CollectionsDeskRow>.from(
          invocation.namedArguments[#rows]! as List<CollectionsDeskRow>,
        );
        final onRows =
            invocation.namedArguments[#onRows]
                as void Function(List<CollectionsDeskRow>)?;
        final sent = [
          for (final row in rows)
            row.copyWith(
              status: CollectionsDeskRowStatus.sent,
              smtpCode: 250,
              smtpMessageId: '<mid@gmail.com>',
            ),
        ];
        onRows?.call(sent);
        return Right(
          DispatchCollectionsEmailResult(
            rows: sent,
            metrics: CollectionsQueueMetrics.fromRows(sent),
          ),
        );
      });
      stubRitual(
        const ClosingRitualResult(
          summary: _emptySummary,
          backupStatus: ClosingBackupStatus.uploaded,
          shortlist: [
            CollectionsCandidate(
              contactId: 'us',
              name: 'us',
              email: 'us@example.com',
              phone: usPhone,
              ledgerId: 'ledger',
              netBalance: -100,
              currencyCode: 'USD',
              ageDays: 12,
              toneBand: ReminderToneBand.reminder,
              rail: OutreachRail.both,
            ),
            CollectionsCandidate(
              contactId: 'ye',
              name: 'ye',
              email: 'ye@example.com',
              phone: '+967771234567',
              ledgerId: 'ledger',
              netBalance: -100,
              currencyCode: 'YER',
              ageDays: 20,
              toneBand: ReminderToneBand.firm,
              rail: OutreachRail.callUnavailable,
            ),
          ],
        ),
      );
      final c = container(
        callePolicy: const CalleDevicePolicy(
          allowDial: true,
          allowlist: {usPhone},
          allowlistRegion: 'US',
        ),
      );
      addTearDown(c.dispose);
      final notifier = c.read(closingAgentControllerProvider.notifier);

      await notifier.confirm(
        _planProposal,
        sendOutreach: true,
      );
      await notifier.commitDeskOutreach(call: true, send: true);

      expect(dispatchCount, 1);
      final state = c.read(closingAgentControllerProvider);
      expect(state.pendingSendAfterCall, isFalse);
      expect(state.phase, ClosingAgentPhase.ritualReport);
    },
  );

  test('no_answer holds pending SMTP until HITL retry completes', () async {
    const usPhone = '+15555550100';
    var dispatchCount = 0;
    when(() => getCall.execute(any())).thenAnswer((invocation) async {
      final runId = invocation.positionalArguments.first as String;
      return Right(
        CallGetResult(
          runId: runId,
          status: 'completed',
          terminal: true,
          phoneMasked: '+…0000',
          needsHuman: false,
          structuredResult: const CallStructuredOutcome(
            outcome: CallRunOutcome.noAnswer,
          ),
        ),
      );
    });
    when(
      () => dispatchEmail.execute(
        rows: any(named: 'rows'),
        locale: any(named: 'locale'),
        storeName: any(named: 'storeName'),
        batchId: any(named: 'batchId'),
        correlationId: any(named: 'correlationId'),
        isRtl: any(named: 'isRtl'),
        onRows: any(named: 'onRows'),
      ),
    ).thenAnswer((invocation) async {
      dispatchCount += 1;
      final rows = List<CollectionsDeskRow>.from(
        invocation.namedArguments[#rows]! as List<CollectionsDeskRow>,
      );
      final onRows =
          invocation.namedArguments[#onRows]
              as void Function(List<CollectionsDeskRow>)?;
      final sent = [
        for (final row in rows)
          row.copyWith(
            status: CollectionsDeskRowStatus.sent,
            smtpCode: 250,
            smtpMessageId: '<mid@gmail.com>',
          ),
      ];
      onRows?.call(sent);
      return Right(
        DispatchCollectionsEmailResult(
          rows: sent,
          metrics: CollectionsQueueMetrics.fromRows(sent),
        ),
      );
    });
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          CollectionsCandidate(
            contactId: 'us',
            name: 'us',
            email: 'us@example.com',
            phone: usPhone,
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'USD',
            ageDays: 12,
            toneBand: ReminderToneBand.reminder,
            rail: OutreachRail.both,
          ),
        ],
      ),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.commitDeskOutreach(call: true, send: true);

    expect(dispatchCount, 0);
    expect(c.read(closingAgentControllerProvider).pendingSendAfterCall, isTrue);
    expect(c.read(closingAgentControllerProvider).callRetryOfferCount, 1);
    expect(
      c.read(closingAgentControllerProvider).phase,
      ClosingAgentPhase.ritualDesk,
    );

    await notifier.retryUnansweredCalls();

    expect(dispatchCount, 1);
    final state = c.read(closingAgentControllerProvider);
    expect(state.pendingSendAfterCall, isFalse);
    expect(state.callRetryOfferCount, 0);
    expect(state.phase, ClosingAgentPhase.ritualReport);
  });

  test('Confirm and Call kill switch 403 is needsHuman', () async {
    const usPhone = '+15555550100';
    when(() => runCall.execute(any())).thenAnswer(
      (_) async => const Left(
        AuthFailure('CALL-E kill switch', code: 'calle_kill_switch'),
      ),
    );
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          CollectionsCandidate(
            contactId: 'us',
            name: 'us',
            email: 'us@example.com',
            phone: usPhone,
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'USD',
            ageDays: 12,
            toneBand: ReminderToneBand.reminder,
            rail: OutreachRail.both,
          ),
        ],
      ),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.confirmAndCall();

    final state = c.read(closingAgentControllerProvider);
    expect(state.callConsented, isTrue);
    expect(state.actionFailure?.code, 'calle_kill_switch');
    expect(
      state.callProgress?.results.single.status,
      CollectionsCallRowStatus.failed,
    );
    verify(() => planCall.execute(any())).called(1);
    verify(() => runCall.execute(any())).called(1);
    verifyNever(() => getCall.execute(any()));
  });

  test('Confirm and Call device kill switch does not HTTP', () async {
    const usPhone = '+15555550100';
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          CollectionsCandidate(
            contactId: 'us',
            name: 'us',
            email: 'us@example.com',
            phone: usPhone,
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'USD',
            ageDays: 12,
            toneBand: ReminderToneBand.reminder,
            rail: OutreachRail.both,
          ),
        ],
      ),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: false,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.confirmAndCall();

    final state = c.read(closingAgentControllerProvider);
    expect(state.callConsented, isFalse);
    expect(state.actionFailure?.code, 'calle_kill_switch');
    expect(
      state.callProgress?.results.single.status,
      CollectionsCallRowStatus.failed,
    );
    verifyNever(() => planCall.execute(any()));
    verifyNever(() => runCall.execute(any()));
  });

  test('Confirm and Call retries once on invalidHandle', () async {
    const usPhone = '+15555550100';
    var runCalls = 0;
    when(() => runCall.execute(any())).thenAnswer((invocation) async {
      runCalls += 1;
      final request =
          invocation.positionalArguments.first as CallRunBatchRequest;
      if (runCalls == 1) {
        return Right(
          CallRunBatchResponse(
            batchId: request.batchId,
            needsHuman: true,
            results: [
              for (final recipient in request.recipients)
                CallRunRowResult(
                  contactId: recipient.contactId,
                  status: CallRunRemoteStatus.rejected,
                  reason: CallRejectReason.invalidHandle,
                ),
            ],
          ),
        );
      }
      return Right(
        CallRunBatchResponse(
          batchId: request.batchId,
          needsHuman: false,
          results: [
            for (final recipient in request.recipients)
              CallRunRowResult(
                contactId: recipient.contactId,
                status: CallRunRemoteStatus.queued,
                runId: 'run-${recipient.contactId}',
              ),
          ],
        ),
      );
    });
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          CollectionsCandidate(
            contactId: 'us',
            name: 'us',
            email: 'us@example.com',
            phone: usPhone,
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'USD',
            ageDays: 12,
            toneBand: ReminderToneBand.reminder,
            rail: OutreachRail.both,
          ),
        ],
      ),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.confirmAndCall();

    final state = c.read(closingAgentControllerProvider);
    expect(
      state.callProgress?.results.single.status,
      CollectionsCallRowStatus.completed,
    );
    verify(() => planCall.execute(any())).called(2);
    verify(() => runCall.execute(any())).called(2);
    verify(() => getCall.execute('run-us')).called(1);
  });

  test(
    'HITL retry after no_answer runs plan then run with attempt 1',
    () async {
      const usPhone = '+15555550100';
      when(() => getCall.execute(any())).thenAnswer((invocation) async {
        final runId = invocation.positionalArguments.first as String;
        return Right(
          CallGetResult(
            runId: runId,
            status: 'completed',
            terminal: true,
            phoneMasked: '+…0000',
            needsHuman: false,
            structuredResult: const CallStructuredOutcome(
              outcome: CallRunOutcome.noAnswer,
            ),
          ),
        );
      });
      final attempts = <int>[];
      when(() => runCall.execute(any())).thenAnswer((invocation) async {
        final request =
            invocation.positionalArguments.first as CallRunBatchRequest;
        attempts.add(request.attempt);
        return Right(
          CallRunBatchResponse(
            batchId: request.batchId,
            needsHuman: false,
            results: [
              for (final recipient in request.recipients)
                CallRunRowResult(
                  contactId: recipient.contactId,
                  status: CallRunRemoteStatus.queued,
                  runId: 'run-${recipient.contactId}',
                ),
            ],
          ),
        );
      });
      stubRitual(
        const ClosingRitualResult(
          summary: _emptySummary,
          backupStatus: ClosingBackupStatus.uploaded,
          shortlist: [
            CollectionsCandidate(
              contactId: 'us',
              name: 'us',
              email: 'us@example.com',
              phone: usPhone,
              ledgerId: 'ledger',
              netBalance: -100,
              currencyCode: 'USD',
              ageDays: 12,
              toneBand: ReminderToneBand.reminder,
              rail: OutreachRail.both,
            ),
          ],
        ),
      );
      final c = container(
        callePolicy: const CalleDevicePolicy(
          allowDial: true,
          allowlist: {usPhone},
          allowlistRegion: 'US',
        ),
      );
      addTearDown(c.dispose);
      final notifier = c.read(closingAgentControllerProvider.notifier);

      await notifier.confirm(
        _planProposal,
        sendOutreach: true,
      );
      await notifier.confirmAndCall();

      expect(c.read(closingAgentControllerProvider).callRetryOfferCount, 1);
      await notifier.retryUnansweredCalls();

      expect(attempts, [0, 1]);
      verify(() => planCall.execute(any())).called(2);
      verify(() => runCall.execute(any())).called(2);
      verify(() => getCall.execute('run-us')).called(2);
    },
  );

  test('promised outcome does not offer HITL retry', () async {
    const usPhone = '+15555550100';
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          CollectionsCandidate(
            contactId: 'us',
            name: 'us',
            email: 'us@example.com',
            phone: usPhone,
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'USD',
            ageDays: 12,
            toneBand: ReminderToneBand.reminder,
            rail: OutreachRail.both,
          ),
        ],
      ),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.confirmAndCall();

    final state = c.read(closingAgentControllerProvider);
    expect(state.callRetryOfferCount, 0);
  });

  test('second HITL retry no-ops after one retry', () async {
    const usPhone = '+15555550100';
    when(() => getCall.execute(any())).thenAnswer((invocation) async {
      final runId = invocation.positionalArguments.first as String;
      return Right(
        CallGetResult(
          runId: runId,
          status: 'completed',
          terminal: true,
          phoneMasked: '+…0000',
          needsHuman: false,
          structuredResult: const CallStructuredOutcome(
            outcome: CallRunOutcome.voicemail,
          ),
        ),
      );
    });
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          CollectionsCandidate(
            contactId: 'us',
            name: 'us',
            email: 'us@example.com',
            phone: usPhone,
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'USD',
            ageDays: 12,
            toneBand: ReminderToneBand.reminder,
            rail: OutreachRail.both,
          ),
        ],
      ),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.confirmAndCall();
    await notifier.retryUnansweredCalls();

    expect(c.read(closingAgentControllerProvider).callRetryOfferCount, 0);

    clearInteractions(planCall);
    clearInteractions(runCall);
    await notifier.retryUnansweredCalls();

    verifyNever(() => planCall.execute(any()));
    verifyNever(() => runCall.execute(any()));
  });

  test('Confirm and Call poll timeout does not run-batch again', () async {
    const usPhone = '+15555550100';
    when(() => getCall.execute(any())).thenAnswer((invocation) async {
      final runId = invocation.positionalArguments.first as String;
      return Right(
        CallGetResult(
          runId: runId,
          status: 'in_progress',
          terminal: false,
          phoneMasked: '+…0000',
          needsHuman: false,
        ),
      );
    });
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          CollectionsCandidate(
            contactId: 'us',
            name: 'us',
            email: 'us@example.com',
            phone: usPhone,
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'USD',
            ageDays: 12,
            toneBand: ReminderToneBand.reminder,
            rail: OutreachRail.both,
          ),
        ],
      ),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.confirmAndCall();

    final state = c.read(closingAgentControllerProvider);
    expect(state.actionFailure?.code, 'calle_poll_timeout');
    expect(
      state.callProgress?.results.single.status,
      CollectionsCallRowStatus.failed,
    );
    verify(() => runCall.execute(any())).called(1);
    verify(
      () => persistCall.persistTerminal(
        any(
          that: predicate<CollectionCallTerminalWrite>(
            (write) => write.rawStatus == 'timeout' && write.needsHuman,
          ),
        ),
      ),
    ).called(1);
  });

  test(
    'Confirm and Call GET network failure clears after terminal GET',
    () async {
      const usPhone = '+15555550100';
      var getCalls = 0;
      ClosingAgentController.callPollTimeout = const Duration(minutes: 10);
      when(() => getCall.execute(any())).thenAnswer((invocation) async {
        getCalls += 1;
        final runId = invocation.positionalArguments.first as String;
        if (getCalls == 1) {
          return const Left(
            NetworkFailure('offline', code: 'closing_agent_request_failed'),
          );
        }
        return Right(
          CallGetResult(
            runId: runId,
            status: 'completed',
            terminal: true,
            phoneMasked: '+…0000',
            needsHuman: false,
            structuredResult: const CallStructuredOutcome(
              outcome: CallRunOutcome.promised,
              promisedAmountMinor: 100,
              promisedCurrency: 'USD',
              promisedDate: '2026-09-10',
            ),
          ),
        );
      });
      stubRitual(
        const ClosingRitualResult(
          summary: _emptySummary,
          backupStatus: ClosingBackupStatus.uploaded,
          shortlist: [
            CollectionsCandidate(
              contactId: 'us',
              name: 'us',
              email: 'us@example.com',
              phone: usPhone,
              ledgerId: 'ledger',
              netBalance: -100,
              currencyCode: 'USD',
              ageDays: 12,
              toneBand: ReminderToneBand.reminder,
              rail: OutreachRail.both,
            ),
          ],
        ),
      );
      final c = container(
        callePolicy: const CalleDevicePolicy(
          allowDial: true,
          allowlist: {usPhone},
          allowlistRegion: 'US',
        ),
      );
      addTearDown(c.dispose);
      final notifier = c.read(closingAgentControllerProvider.notifier);

      await notifier.confirm(
        _planProposal,
        sendOutreach: true,
      );
      await notifier.confirmAndCall();

      final state = c.read(closingAgentControllerProvider);
      expect(state.actionFailure, isNull);
      expect(getCalls, greaterThan(1));
      verify(() => runCall.execute(any())).called(1);
      verify(() => persistCall.persistQueued(any())).called(1);
    },
  );

  test(
    'Confirm and Call persistTerminal Left surfaces database failure',
    () async {
      const usPhone = '+15555550100';
      when(() => persistCall.persistTerminal(any())).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('write failed', code: 'database_failure'),
        ),
      );
      stubRitual(
        const ClosingRitualResult(
          summary: _emptySummary,
          backupStatus: ClosingBackupStatus.uploaded,
          shortlist: [
            CollectionsCandidate(
              contactId: 'us',
              name: 'us',
              email: 'us@example.com',
              phone: usPhone,
              ledgerId: 'ledger',
              netBalance: -100,
              currencyCode: 'USD',
              ageDays: 12,
              toneBand: ReminderToneBand.reminder,
              rail: OutreachRail.both,
            ),
          ],
        ),
      );
      final c = container(
        callePolicy: const CalleDevicePolicy(
          allowDial: true,
          allowlist: {usPhone},
          allowlistRegion: 'US',
        ),
      );
      addTearDown(c.dispose);
      final notifier = c.read(closingAgentControllerProvider.notifier);

      await notifier.confirm(
        _planProposal,
        sendOutreach: true,
      );
      await notifier.confirmAndCall();

      final state = c.read(closingAgentControllerProvider);
      expect(state.actionFailure, isA<DatabaseFailure>());
      verify(() => runCall.execute(any())).called(1);
      verify(() => persistCall.persistTerminal(any())).called(1);
    },
  );

  test('Confirm and Call keeps planned until first GET', () async {
    const usPhone = '+15555550100';
    var getCalls = 0;
    ClosingAgentController.callPollTimeout = const Duration(minutes: 10);
    when(() => getCall.execute(any())).thenAnswer((invocation) async {
      getCalls += 1;
      final runId = invocation.positionalArguments.first as String;
      if (getCalls == 1) {
        return Right(
          CallGetResult(
            runId: runId,
            status: 'planned',
            terminal: false,
            phoneMasked: '+…0000',
            needsHuman: false,
          ),
        );
      }
      return Right(
        CallGetResult(
          runId: runId,
          status: 'completed',
          terminal: true,
          phoneMasked: '+…0000',
          needsHuman: false,
          structuredResult: const CallStructuredOutcome(
            outcome: CallRunOutcome.promised,
            promisedAmountMinor: 100,
            promisedCurrency: 'USD',
            promisedDate: '2026-09-10',
          ),
        ),
      );
    });
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          CollectionsCandidate(
            contactId: 'us',
            name: 'us',
            email: 'us@example.com',
            phone: usPhone,
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'USD',
            ageDays: 12,
            toneBand: ReminderToneBand.reminder,
            rail: OutreachRail.both,
          ),
        ],
      ),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.confirmAndCall();

    final state = c.read(closingAgentControllerProvider);
    expect(
      state.callProgress?.results.single.status,
      CollectionsCallRowStatus.completed,
    );
    expect(getCalls, greaterThan(1));
  });

  test('finishDesk invalidates stale poll timeout', () async {
    const usPhone = '+15555550100';
    ClosingAgentController.callPollInterval = const Duration(milliseconds: 20);
    ClosingAgentController.callPollTimeout = const Duration(minutes: 10);
    when(() => getCall.execute(any())).thenAnswer((invocation) async {
      final runId = invocation.positionalArguments.first as String;
      return Right(
        CallGetResult(
          runId: runId,
          status: 'in_progress',
          terminal: false,
          phoneMasked: '+…0000',
          needsHuman: false,
        ),
      );
    });
    stubRitual(
      const ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [
          CollectionsCandidate(
            contactId: 'us',
            name: 'us',
            email: 'us@example.com',
            phone: usPhone,
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'USD',
            ageDays: 12,
            toneBand: ReminderToneBand.reminder,
            rail: OutreachRail.both,
          ),
        ],
      ),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    unawaited(notifier.confirmAndCall());
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await notifier.finishDesk();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final state = c.read(closingAgentControllerProvider);
    expect(state.actionFailure?.code, isNot('calle_poll_timeout'));
    expect(state.phase, ClosingAgentPhase.ritualReport);
  });

  test(
    'SMTP preflight failure still opens desk when call set exists',
    () async {
      const usPhone = '+15555550100';
      when(() => hydrate.execute()).thenAnswer(
        (_) async => const Left(
          AuthFailure('silent', code: 'silent_sign_in_failed'),
        ),
      );
      stubRitual(
        const ClosingRitualResult(
          summary: _emptySummary,
          backupStatus: ClosingBackupStatus.uploaded,
          shortlist: [
            CollectionsCandidate(
              contactId: 'us',
              name: 'us',
              email: 'us@example.com',
              phone: usPhone,
              ledgerId: 'ledger',
              netBalance: -100,
              currencyCode: 'USD',
              ageDays: 12,
              toneBand: ReminderToneBand.reminder,
              rail: OutreachRail.both,
            ),
          ],
        ),
      );
      final c = container(
        callePolicy: const CalleDevicePolicy(
          allowDial: false,
          allowlist: {usPhone},
          allowlistRegion: 'US',
        ),
      );
      addTearDown(c.dispose);

      await c
          .read(closingAgentControllerProvider.notifier)
          .confirm(
            _planProposal,
            sendOutreach: true,
          );

      final state = c.read(closingAgentControllerProvider);
      expect(state.phase, ClosingAgentPhase.ritualDesk);
      expect(state.ritualDeskPreflightPending, isFalse);
      expect(state.actionFailure, isA<AuthFailure>());
      expect(state.deskCallCount, 1);
    },
  );

  test('SMTP preflight failure blocks desk when call set is empty', () async {
    when(() => hydrate.execute()).thenAnswer(
      (_) async => const Left(
        AuthFailure('silent', code: 'silent_sign_in_failed'),
      ),
    );
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [_candidate('a')],
      ),
    );
    final c = container();
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .confirm(
          _planProposal,
          sendOutreach: true,
        );

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualRunning);
    expect(state.ritualDeskPreflightPending, isTrue);
    expect(state.actionFailure, isA<AuthFailure>());
  });

  test('Confirm without calling leaves SMTP available', () async {
    when(
      () => dispatchEmail.execute(
        rows: any(named: 'rows'),
        locale: any(named: 'locale'),
        storeName: any(named: 'storeName'),
        batchId: any(named: 'batchId'),
        correlationId: any(named: 'correlationId'),
        isRtl: any(named: 'isRtl'),
        onRows: any(named: 'onRows'),
      ),
    ).thenAnswer((invocation) async {
      final rows =
          invocation.namedArguments[#rows]! as List<CollectionsDeskRow>;
      final onRows =
          invocation.namedArguments[#onRows]
              as void Function(List<CollectionsDeskRow>)?;
      final sent = [
        for (final row in rows)
          row.copyWith(
            status: CollectionsDeskRowStatus.sent,
            smtpCode: 250,
          ),
      ];
      onRows?.call(sent);
      return Right(
        DispatchCollectionsEmailResult(
          rows: sent,
          metrics: CollectionsQueueMetrics.fromRows(sent),
        ),
      );
    });
    stubRitual(
      ClosingRitualResult(
        summary: _emptySummary,
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [_candidate('a'), _candidate('b')],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.confirm(
      _planProposal,
      sendOutreach: true,
    );
    await notifier.confirmWithoutCalling();
    await notifier.approveAndSend();

    verify(
      () => dispatchEmail.execute(
        rows: any(named: 'rows'),
        locale: any(named: 'locale'),
        storeName: any(named: 'storeName'),
        batchId: any(named: 'batchId'),
        correlationId: any(named: 'correlationId'),
        isRtl: any(named: 'isRtl'),
        onRows: any(named: 'onRows'),
      ),
    ).called(1);
    expect(c.read(closingAgentControllerProvider).callConsented, isFalse);
  });

  test(
    'Approve mixed valid + missing email never opens WhatsApp or share-sheet',
    () async {
      when(
        () => dispatchEmail.execute(
          rows: any(named: 'rows'),
          locale: any(named: 'locale'),
          storeName: any(named: 'storeName'),
          batchId: any(named: 'batchId'),
          correlationId: any(named: 'correlationId'),
          isRtl: any(named: 'isRtl'),
          onRows: any(named: 'onRows'),
        ),
      ).thenAnswer((invocation) async {
        final rows =
            invocation.namedArguments[#rows]! as List<CollectionsDeskRow>;
        final onRows =
            invocation.namedArguments[#onRows]
                as void Function(List<CollectionsDeskRow>)?;
        final updated = [
          for (final row in rows)
            row.copyWith(
              status: row.candidate.email == null
                  ? CollectionsDeskRowStatus.failed
                  : CollectionsDeskRowStatus.sent,
              smtpCode: row.candidate.email == null ? null : 250,
              smtpMessageId: row.candidate.email == null
                  ? null
                  : '<mid@gmail.com>',
            ),
        ];
        onRows?.call(updated);
        return Right(
          DispatchCollectionsEmailResult(
            rows: updated,
            metrics: CollectionsQueueMetrics.fromRows(updated),
          ),
        );
      });
      stubRitual(
        ClosingRitualResult(
          summary: _emptySummary,
          backupStatus: ClosingBackupStatus.uploaded,
          shortlist: [
            _candidate('a', email: 'a@example.com'),
            _candidate('b'),
          ],
        ),
      );
      final c = container();
      addTearDown(c.dispose);
      final notifier = c.read(closingAgentControllerProvider.notifier);

      await notifier.confirm(_planProposal, sendOutreach: true);
      await notifier.approveAndSend();

      final state = c.read(closingAgentControllerProvider);
      expect(openedPhones, isEmpty);
      expect(state.isQueueInFlight, isFalse);
      expect(
        state.ritualResult?.queueMetrics,
        const CollectionsQueueMetrics(
          prepared: 2,
          opened: 0,
          skipped: 0,
          sent: 1,
          failed: 1,
        ),
      );
    },
  );

  test(
    'SMTP persist marks queue completed so sticky cannot revive after batchId clear',
    () async {
      when(
        () => dispatchEmail.execute(
          rows: any(named: 'rows'),
          locale: any(named: 'locale'),
          storeName: any(named: 'storeName'),
          batchId: any(named: 'batchId'),
          correlationId: any(named: 'correlationId'),
          isRtl: any(named: 'isRtl'),
          onRows: any(named: 'onRows'),
        ),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('unreachable')),
      );
      stubRitual(
        ClosingRitualResult(
          summary: _emptySummary,
          backupStatus: ClosingBackupStatus.uploaded,
          shortlist: [_candidate('a', email: 'a@example.com')],
        ),
      );
      final c = container();
      addTearDown(c.dispose);
      final notifier = c.read(closingAgentControllerProvider.notifier);

      await notifier.confirm(_planProposal, sendOutreach: true);
      await notifier.approveAndSend();

      final state = c.read(closingAgentControllerProvider);
      expect(state.phase, ClosingAgentPhase.ritualDesk);
      expect(state.queueStatus, CollectionsSendQueueStatus.completed);
      expect(state.isQueueInFlight, isFalse);
      expect(openedPhones, isEmpty);
    },
  );

  test('hydrate skips SMTP queues with batchId', () async {
    when(() => loadQueue.execute()).thenAnswer(
      (_) async => Right(
        CollectionsSendQueue(
          id: 'q-smtp',
          status: CollectionsSendQueueStatus.active,
          awaitingResume: true,
          locale: 'ar',
          storeName: 'Daftar',
          ritual: ClosingRitualResult(
            summary: _emptySummary,
            backupStatus: ClosingBackupStatus.uploaded,
            shortlist: [_candidate('a')],
            reminderPolicy: ClosingReminderPolicy.top5,
          ),
          rows: [
            CollectionsDeskRow(
              candidate: _candidate('a'),
              body: 'body-a',
              toneBand: ReminderToneBand.reminder,
              attachPdf: true,
            ),
          ],
          createdAt: DateTime.utc(2026, 8, 15),
          updatedAt: DateTime.utc(2026, 8, 15),
          batchId: '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    final c = container();
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .hydrateInFlightQueue();

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, isNot(ClosingAgentPhase.ritualDesk));
    expect(state.queueId, isNull);
    expect(openedPhones, isEmpty);
  });

  test('ready turn speaks narrative when TTS is not muted', () async {
    when(
      () => connectivity.currentStatus(),
    ).thenAnswer((_) async => ConnectivityStatus.online);
    when(
      () => runTurn.execute(
        goalText: any(named: 'goalText'),
        audioClip: any(named: 'audioClip'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        AgentTurnResult(
          correlationId: 'corr',
          sessionId: 'sess',
          proposals: [],
          narrative: 'Mohamed owes 500 for sugar',
        ),
      ),
    );
    final spoken = <String>[];
    final done = Completer<void>();
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken.add(text);
      done.complete();
    };
    final c = container(settings: const AppSettings(locale: 'en'));
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .submitGoal('Mohamed owes 500 for sugar');
    await done.future.timeout(const Duration(seconds: 2));

    expect(spoken, ['Mohamed owes 500 for sugar']);
    expect(
      c.read(closingAgentControllerProvider).phase,
      ClosingAgentPhase.ready,
    );
  });

  test('muted settings skip narrative TTS', () async {
    when(
      () => connectivity.currentStatus(),
    ).thenAnswer((_) async => ConnectivityStatus.online);
    when(
      () => runTurn.execute(
        goalText: any(named: 'goalText'),
        audioClip: any(named: 'audioClip'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        AgentTurnResult(
          correlationId: 'corr',
          sessionId: 'sess',
          proposals: [],
          narrative: 'Mohamed owes 500 for sugar',
        ),
      ),
    );
    var spoken = 0;
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken += 1;
    };
    final c = container(
      settings: const AppSettings(ttsMuted: true, locale: 'en'),
    );
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .submitGoal('Mohamed owes 500 for sugar');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(spoken, 0);
  });

  test('cloud TTS clip is played instead of DeviceTts', () async {
    when(
      () => connectivity.currentStatus(),
    ).thenAnswer((_) async => ConnectivityStatus.online);
    when(
      () => runTurn.execute(
        goalText: any(named: 'goalText'),
        audioClip: any(named: 'audioClip'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        AgentTurnResult(
          correlationId: 'corr',
          sessionId: 'sess',
          proposals: [],
          narrative: 'Mohamed owes 500 for sugar',
        ),
      ),
    );
    when(
      () => synthesizeSpeech.execute(
        text: any(named: 'text'),
        locale: any(named: 'locale'),
      ),
    ).thenAnswer(
      (_) async => Right(
        AgentSpeechClip(bytes: Uint8List.fromList(const [1, 2, 3])),
      ),
    );
    final played = <int>[];
    final done = Completer<void>();
    AgentSpeech.debugPlayOverride = (bytes, {required mimeType}) async {
      played.add(bytes.length);
      done.complete();
    };
    var deviceSpoken = 0;
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      deviceSpoken += 1;
    };
    final c = container(settings: const AppSettings(locale: 'en'));
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .submitGoal('Mohamed owes 500 for sugar');
    await done.future.timeout(const Duration(seconds: 2));

    expect(played, [3]);
    expect(deviceSpoken, 0);
  });

  test('new turn stops in-flight TTS', () async {
    var stops = 0;
    DeviceTts.debugStopOverride = () async {
      stops += 1;
    };
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {};
    final c = container();
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .submitGoal('Mohamed owes 500');

    expect(stops, 1);
  });

  test('contact pick deny sets banner; cancel does not', () {
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier)
      ..applyContactPickOutcome(
        'proposal-1',
        const NativeContactCancelled(),
      );
    expect(
      c.read(closingAgentControllerProvider).contactsPermissionDenied,
      isFalse,
    );

    notifier.applyContactPickOutcome(
      'proposal-1',
      const NativeContactDenied(),
    );
    expect(
      c.read(closingAgentControllerProvider).contactsPermissionDenied,
      isTrue,
    );

    notifier.applyContactPickOutcome(
      'proposal-1',
      const NativeContactPicked(
        NativeContactPickResult(name: 'Sami', phone: '967771234567'),
      ),
    );
    final state = c.read(closingAgentControllerProvider);
    expect(state.contactsPermissionDenied, isFalse);
    expect(state.nameByProposal['proposal-1'], 'Sami');
    expect(state.phoneByProposal['proposal-1'], '967771234567');
  });

  test('confirmable proposals skip narrative TTS', () async {
    when(
      () => connectivity.currentStatus(),
    ).thenAnswer((_) async => ConnectivityStatus.online);
    when(
      () => runTurn.execute(
        goalText: any(named: 'goalText'),
        audioClip: any(named: 'audioClip'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        AgentTurnResult(
          correlationId: 'corr',
          sessionId: 'sess',
          proposals: [
            AgentProposal(
              proposalId: 'd1',
              tool: ProposalTool.proposeDebt,
              confirmRequired: true,
              rawEnvelope: {},
              payload: AgentProposalPayload.debt(
                contactHint: 'Mohamed',
                amountMinor: 500,
                currencyCode: 'YER',
                contactId: 'c1',
              ),
            ),
          ],
          narrative: 'You asked me to register Mohamed for 500',
        ),
      ),
    );
    var spoken = 0;
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken += 1;
    };
    final c = container(settings: const AppSettings(locale: 'en'));
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .submitGoal('Mohamed owes 500');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(spoken, 0);
  });

  test('closing plan speaks plan-ready and not Gemini narrative', () async {
    when(
      () => connectivity.currentStatus(),
    ).thenAnswer((_) async => ConnectivityStatus.online);
    when(
      () => runTurn.execute(
        goalText: any(named: 'goalText'),
        audioClip: any(named: 'audioClip'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        AgentTurnResult(
          correlationId: 'corr',
          sessionId: 'sess',
          proposals: [_planProposal],
          narrative:
              'Step one count the books. Step two back up Drive. Step three age accounts.',
        ),
      ),
    );
    final spoken = <String>[];
    final done = Completer<void>();
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken.add(text);
      if (!done.isCompleted) {
        done.complete();
      }
    };
    final c = container(settings: const AppSettings(locale: 'en'));
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .submitGoal('close my day');
    await done.future.timeout(const Duration(seconds: 2));

    expect(spoken, hasLength(1));
    expect(spoken.single, contains("Today's closing plan is ready"));
    expect(spoken.single, isNot(contains('Step one')));
    expect(spoken.single, isNot(contains('age accounts')));
  });

  test('muted settings skip plan-ready TTS', () async {
    when(
      () => connectivity.currentStatus(),
    ).thenAnswer((_) async => ConnectivityStatus.online);
    when(
      () => runTurn.execute(
        goalText: any(named: 'goalText'),
        audioClip: any(named: 'audioClip'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        AgentTurnResult(
          correlationId: 'corr',
          sessionId: 'sess',
          proposals: [_planProposal],
          narrative: 'Step one count the books.',
        ),
      ),
    );
    var spoken = 0;
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken += 1;
    };
    final c = container(
      settings: const AppSettings(ttsMuted: true, locale: 'en'),
    );
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .submitGoal('close my day');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(spoken, 0);
  });

  test('ask answer from parse_goal skips narrative TTS', () async {
    when(
      () => connectivity.currentStatus(),
    ).thenAnswer((_) async => ConnectivityStatus.online);
    when(
      () => runTurn.execute(
        goalText: any(named: 'goalText'),
        audioClip: any(named: 'audioClip'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        AgentTurnResult(
          correlationId: 'corr',
          sessionId: 'sess',
          proposals: [
            AgentProposal(
              proposalId: 'ask-1',
              tool: ProposalTool.parseGoal,
              confirmRequired: false,
              rawEnvelope: {},
              payload: AgentProposalPayload.parseGoal(goalClass: 'ask'),
            ),
          ],
          narrative: 'Let me look that up for you',
        ),
      ),
    );
    stubAsk(
      const AskBooksNamedBalance(
        AskBooksBalanceRow(
          contactId: 'c1',
          contactName: 'Mohamed',
          netBalance: -500,
          currencyCode: 'YER',
        ),
      ),
    );
    var spoken = 0;
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken += 1;
    };
    final c = container(settings: const AppSettings(locale: 'en'));
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .submitGoal('hello there');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(spoken, 0);
    expect(
      c.read(closingAgentControllerProvider).askAnswer,
      isA<AskBooksNamedBalance>(),
    );
  });

  test('speak in Arabic sets a session speech override', () async {
    when(
      () => connectivity.currentStatus(),
    ).thenAnswer((_) async => ConnectivityStatus.online);
    when(
      () => runTurn.execute(
        goalText: any(named: 'goalText'),
        audioClip: any(named: 'audioClip'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        AgentTurnResult(
          correlationId: 'corr',
          sessionId: 'sess',
          proposals: [],
          narrative: 'OK',
        ),
      ),
    );
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {};
    final c = container(settings: const AppSettings(locale: 'en'));
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.submitGoal('speak in Arabic');
    expect(
      c.read(closingAgentControllerProvider).speechLocaleOverride,
      'ar',
    );

    notifier.resetSpeechSession();
    expect(
      c.read(closingAgentControllerProvider).speechLocaleOverride,
      isNull,
    );
  });

  test('Arabic coffee does not switch speech locale', () async {
    when(
      () => connectivity.currentStatus(),
    ).thenAnswer((_) async => ConnectivityStatus.online);
    when(
      () => runTurn.execute(
        goalText: any(named: 'goalText'),
        audioClip: any(named: 'audioClip'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        AgentTurnResult(
          correlationId: 'corr',
          sessionId: 'sess',
          proposals: [],
          narrative: 'Arabic coffee',
        ),
      ),
    );
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {};
    final c = container(settings: const AppSettings(locale: 'en'));
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .submitGoal('Arabic coffee for Mohamed');
    expect(
      c.read(closingAgentControllerProvider).speechLocaleOverride,
      isNull,
    );
  });

  test('resume clears contacts banner when OS grant is restored', () async {
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier)
      ..applyContactPickOutcome(
        'proposal-1',
        const NativeContactDenied(permanentlyDenied: true),
      );
    expect(
      c.read(closingAgentControllerProvider).contactsPermissionDenied,
      isTrue,
    );

    await notifier.onHostResumed(
      hasContactsReadPermission: () async => true,
    );
    expect(
      c.read(closingAgentControllerProvider).contactsPermissionDenied,
      isFalse,
    );
  });

  test('resume clears mic-denied banner when OS grant is restored', () async {
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier)
      ..showMicBanner(ClosingMicBannerKind.permissionDenied);

    await notifier.onHostResumed(
      hasMicrophonePermission: () async => true,
    );
    expect(c.read(closingAgentControllerProvider).micBannerKind, isNull);
  });

  test('resume keeps mic-denied banner when still denied', () async {
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier)
      ..showMicBanner(ClosingMicBannerKind.permissionDenied);

    await notifier.onHostResumed(
      hasMicrophonePermission: () async => false,
    );
    expect(
      c.read(closingAgentControllerProvider).micBannerKind,
      ClosingMicBannerKind.permissionDenied,
    );
  });

  test('hold-hint mic banner auto-dismisses', () async {
    final c = container();
    addTearDown(c.dispose);
    c
        .read(closingAgentControllerProvider.notifier)
        .showMicBanner(
          ClosingMicBannerKind.holdHint,
        );

    expect(
      c.read(closingAgentControllerProvider).micBannerKind,
      ClosingMicBannerKind.holdHint,
    );

    await Future<void>.delayed(ClosingAgentController.holdHintVisible);

    expect(c.read(closingAgentControllerProvider).micBannerKind, isNull);
  });

  test('resume does not clear hold-hint mic banner', () async {
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier)
      ..showMicBanner(ClosingMicBannerKind.holdHint);

    await notifier.onHostResumed(
      hasMicrophonePermission: () async => true,
    );
    expect(
      c.read(closingAgentControllerProvider).micBannerKind,
      ClosingMicBannerKind.holdHint,
    );
  });

  group('confirmCaptureBundle', () {
    const ledgerProposal = AgentProposal(
      proposalId: 'ledger-1',
      tool: ProposalTool.proposeCreateLedger,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.createLedger(name: 'Shop'),
    );

    const contactProposal = AgentProposal(
      proposalId: 'contact-1',
      tool: ProposalTool.proposeCreateContact,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.createContact(name: 'Mohamed'),
    );

    const debtProposal = AgentProposal(
      proposalId: 'debt-1',
      tool: ProposalTool.proposeDebt,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.debt(
        contactHint: 'Mohamed',
        amountMinor: 40000,
        currencyCode: 'YER',
      ),
    );

    Future<void> seedCompoundTurn(ProviderContainer c) async {
      final notifier = c.read(closingAgentControllerProvider.notifier);
      notifier.state = notifier.state.copyWith(
        phase: ClosingAgentPhase.ready,
        turnResult: const AgentTurnResult(
          correlationId: 'corr',
          sessionId: 'sess',
          proposals: [debtProposal, contactProposal, ledgerProposal],
        ),
      );
    }

    test('commits ledger then contact then debt with threaded ids', () async {
      final commits = <AgentProposal>[];
      final ledgerOverrides = <String?>[];
      final contactOverrides = <String?>[];
      final createIfMissingFlags = <bool>[];

      when(
        () => commit.execute(
          proposal: any(named: 'proposal'),
          ledgerIdOverride: any(named: 'ledgerIdOverride'),
          currencyCodeOverride: any(named: 'currencyCodeOverride'),
          contactIdOverride: any(named: 'contactIdOverride'),
          nameOverride: any(named: 'nameOverride'),
          phoneOverride: any(named: 'phoneOverride'),
          ledgerNameOverride: any(named: 'ledgerNameOverride'),
          amountMinorOverride: any(named: 'amountMinorOverride'),
          createIfMissing: any(named: 'createIfMissing'),
        ),
      ).thenAnswer((invocation) async {
        final proposal =
            invocation.namedArguments[const Symbol('proposal')]
                as AgentProposal;
        commits.add(proposal);
        ledgerOverrides.add(
          invocation.namedArguments[const Symbol('ledgerIdOverride')]
              as String?,
        );
        contactOverrides.add(
          invocation.namedArguments[const Symbol('contactIdOverride')]
              as String?,
        );
        createIfMissingFlags.add(
          invocation.namedArguments[const Symbol('createIfMissing')] as bool,
        );
        final entityId = switch (proposal.tool) {
          ProposalTool.proposeCreateLedger => 'ledger-new',
          ProposalTool.proposeCreateContact => 'contact-new',
          ProposalTool.proposeDebt => 'txn-1',
          _ => null,
        };
        return Right(
          ConfirmProposalResult(
            proposalId: proposal.proposalId,
            status: ConfirmProposalStatus.committed,
            entityId: entityId,
          ),
        );
      });

      final c = container();
      addTearDown(c.dispose);
      await seedCompoundTurn(c);

      await c
          .read(closingAgentControllerProvider.notifier)
          .confirmCaptureBundle(
            const [ledgerProposal, contactProposal, debtProposal],
          );

      expect(commits.map((p) => p.proposalId), [
        'ledger-1',
        'contact-1',
        'debt-1',
      ]);
      expect(ledgerOverrides[1], 'ledger-new');
      expect(contactOverrides[2], 'contact-new');
      expect(createIfMissingFlags[2], isFalse);
      final state = c.read(closingAgentControllerProvider);
      expect(state.committedIds, {
        'ledger-1',
        'contact-1',
        'debt-1',
      });
      expect(state.confirmingProposalId, isNull);
    });

    test('failure on contact leaves ledger committed', () async {
      var callCount = 0;
      when(
        () => commit.execute(
          proposal: any(named: 'proposal'),
          ledgerIdOverride: any(named: 'ledgerIdOverride'),
          currencyCodeOverride: any(named: 'currencyCodeOverride'),
          contactIdOverride: any(named: 'contactIdOverride'),
          nameOverride: any(named: 'nameOverride'),
          phoneOverride: any(named: 'phoneOverride'),
          ledgerNameOverride: any(named: 'ledgerNameOverride'),
          amountMinorOverride: any(named: 'amountMinorOverride'),
          createIfMissing: any(named: 'createIfMissing'),
        ),
      ).thenAnswer((invocation) async {
        callCount += 1;
        final proposal =
            invocation.namedArguments[const Symbol('proposal')]
                as AgentProposal;
        if (callCount == 1) {
          return Right(
            ConfirmProposalResult(
              proposalId: proposal.proposalId,
              status: ConfirmProposalStatus.committed,
              entityId: 'ledger-new',
            ),
          );
        }
        return const Left(
          ValidationFailure('Select a currency', code: 'currency_required'),
        );
      });

      final c = container();
      addTearDown(c.dispose);
      await seedCompoundTurn(c);

      await c
          .read(closingAgentControllerProvider.notifier)
          .confirmCaptureBundle(
            const [ledgerProposal, contactProposal, debtProposal],
          );

      final state = c.read(closingAgentControllerProvider);
      expect(state.committedIds, {'ledger-1'});
      expect(state.actionFailure?.code, 'currency_required');
      expect(state.confirmingProposalId, isNull);
      verify(
        () => commit.execute(
          proposal: any(named: 'proposal'),
          ledgerIdOverride: any(named: 'ledgerIdOverride'),
          currencyCodeOverride: any(named: 'currencyCodeOverride'),
          contactIdOverride: any(named: 'contactIdOverride'),
          nameOverride: any(named: 'nameOverride'),
          phoneOverride: any(named: 'phoneOverride'),
          ledgerNameOverride: any(named: 'ledgerNameOverride'),
          amountMinorOverride: any(named: 'amountMinorOverride'),
          createIfMissing: any(named: 'createIfMissing'),
        ),
      ).called(2);
    });

    test(
      'ignores stale ledger picks when bundle creates a new ledger',
      () async {
        final ledgerOverrides = <String?>[];

        when(
          () => commit.execute(
            proposal: any(named: 'proposal'),
            ledgerIdOverride: any(named: 'ledgerIdOverride'),
            currencyCodeOverride: any(named: 'currencyCodeOverride'),
            contactIdOverride: any(named: 'contactIdOverride'),
            nameOverride: any(named: 'nameOverride'),
            phoneOverride: any(named: 'phoneOverride'),
            ledgerNameOverride: any(named: 'ledgerNameOverride'),
            amountMinorOverride: any(named: 'amountMinorOverride'),
            createIfMissing: any(named: 'createIfMissing'),
          ),
        ).thenAnswer((invocation) async {
          final proposal =
              invocation.namedArguments[const Symbol('proposal')]
                  as AgentProposal;
          ledgerOverrides.add(
            invocation.namedArguments[const Symbol('ledgerIdOverride')]
                as String?,
          );
          final entityId = switch (proposal.tool) {
            ProposalTool.proposeCreateLedger => 'ledger-new',
            ProposalTool.proposeCreateContact => 'contact-new',
            ProposalTool.proposeDebt => 'txn-1',
            _ => null,
          };
          return Right(
            ConfirmProposalResult(
              proposalId: proposal.proposalId,
              status: ConfirmProposalStatus.committed,
              entityId: entityId,
            ),
          );
        });

        final c = container();
        addTearDown(c.dispose);
        await seedCompoundTurn(c);
        c.read(closingAgentControllerProvider.notifier).state = c
            .read(closingAgentControllerProvider)
            .copyWith(
              ledgerIdByProposal: {
                'contact-1': 'stale-ledger-id',
                'debt-1': 'stale-ledger-id',
              },
            );

        await c
            .read(closingAgentControllerProvider.notifier)
            .confirmCaptureBundle(
              const [ledgerProposal, contactProposal, debtProposal],
            );

        expect(ledgerOverrides[1], 'ledger-new');
        expect(ledgerOverrides[2], 'ledger-new');
        expect(ledgerOverrides, isNot(contains('stale-ledger-id')));
      },
    );
  });

  test('openCreditLimitDesk does not call plan-batch', () async {
    const usPhone = '+15555550100';
    when(
      () => collectionsCandidates.execute(
        asOf: any(named: 'asOf'),
        allowlist: any(named: 'allowlist'),
        allowlistRegion: any(named: 'allowlistRegion'),
        contactId: 'us',
      ),
    ).thenAnswer(
      (_) async => const Right([
        CollectionsCandidate(
          contactId: 'us',
          name: 'us',
          email: 'us@example.com',
          phone: usPhone,
          ledgerId: 'ledger',
          netBalance: -100,
          currencyCode: 'USD',
          ageDays: 12,
          toneBand: ReminderToneBand.reminder,
          rail: OutreachRail.both,
        ),
      ]),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);

    await c
        .read(closingAgentControllerProvider.notifier)
        .openCreditLimitDesk(
          'us',
        );

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualDesk);
    expect(state.callBatchTrigger, CallBatchTrigger.creditLimit);
    expect(state.sendOutreachEnabled, isTrue);
    verifyNever(() => planCall.execute(any()));
    verifyNever(() => runCall.execute(any()));
  });

  test(
    'credit-limit dismissCreditLimitSession returns idle not ritual report',
    () async {
      const usPhone = '+15555550100';
      when(
        () => collectionsCandidates.execute(
          asOf: any(named: 'asOf'),
          allowlist: any(named: 'allowlist'),
          allowlistRegion: any(named: 'allowlistRegion'),
          contactId: 'us',
        ),
      ).thenAnswer(
        (_) async => const Right([
          CollectionsCandidate(
            contactId: 'us',
            name: 'us',
            email: 'us@example.com',
            phone: usPhone,
            ledgerId: 'ledger',
            netBalance: -100,
            currencyCode: 'USD',
            ageDays: 12,
            toneBand: ReminderToneBand.reminder,
            rail: OutreachRail.both,
          ),
        ]),
      );
      final c = container(
        callePolicy: const CalleDevicePolicy(
          allowDial: true,
          allowlist: {usPhone},
          allowlistRegion: 'US',
        ),
      );
      addTearDown(c.dispose);
      final notifier = c.read(closingAgentControllerProvider.notifier);

      await notifier.openCreditLimitDesk('us');
      await notifier.dismissCreditLimitSession();

      final state = c.read(closingAgentControllerProvider);
      expect(state.phase, ClosingAgentPhase.idle);
      expect(state.ritualResult, isNull);
      expect(state.callBatchTrigger, CallBatchTrigger.closeDay);
    },
  );

  test('credit-limit confirmAndCall sends creditLimit trigger', () async {
    const usPhone = '+15555550100';
    CallPlanBatchRequest? capturedPlan;
    when(() => planCall.execute(any())).thenAnswer((invocation) async {
      capturedPlan =
          invocation.positionalArguments.first as CallPlanBatchRequest;
      return const Right(
        CallPlanBatchResponse(
          batchId: 'batch-1',
          results: [
            CallPlanRowResult(
              contactId: 'us',
              phoneMasked: '+…0100',
              readyToRun: true,
              status: CallPlanRowStatus.planned,
              confirmHandle: 'handle-us',
            ),
          ],
        ),
      );
    });
    when(
      () => collectionsCandidates.execute(
        asOf: any(named: 'asOf'),
        allowlist: any(named: 'allowlist'),
        allowlistRegion: any(named: 'allowlistRegion'),
        contactId: 'us',
      ),
    ).thenAnswer(
      (_) async => const Right([
        CollectionsCandidate(
          contactId: 'us',
          name: 'us',
          email: 'us@example.com',
          phone: usPhone,
          ledgerId: 'ledger',
          netBalance: -100,
          currencyCode: 'USD',
          ageDays: 12,
          toneBand: ReminderToneBand.reminder,
          rail: OutreachRail.both,
        ),
      ]),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.openCreditLimitDesk('us');
    await notifier.confirmAndCall();

    expect(capturedPlan?.trigger, CallBatchTrigger.creditLimit);
  });

  test('credit-limit finishDesk keeps session active', () async {
    const usPhone = '+15555550100';
    when(
      () => collectionsCandidates.execute(
        asOf: any(named: 'asOf'),
        allowlist: any(named: 'allowlist'),
        allowlistRegion: any(named: 'allowlistRegion'),
        contactId: 'us',
      ),
    ).thenAnswer(
      (_) async => const Right([
        CollectionsCandidate(
          contactId: 'us',
          name: 'us',
          email: 'us@example.com',
          phone: usPhone,
          ledgerId: 'ledger',
          netBalance: -100,
          currencyCode: 'USD',
          ageDays: 12,
          toneBand: ReminderToneBand.reminder,
          rail: OutreachRail.both,
        ),
      ]),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.openCreditLimitDesk('us');
    await notifier.finishDesk();

    final state = c.read(closingAgentControllerProvider);
    expect(state.phase, ClosingAgentPhase.ritualDesk);
    expect(state.callBatchTrigger, CallBatchTrigger.creditLimit);
    expect(state.isCreditLimitCallSessionActive, isTrue);
  });

  test('credit-limit session terminal when all rows complete', () async {
    const usPhone = '+15555550100';
    when(
      () => collectionsCandidates.execute(
        asOf: any(named: 'asOf'),
        allowlist: any(named: 'allowlist'),
        allowlistRegion: any(named: 'allowlistRegion'),
        contactId: 'us',
      ),
    ).thenAnswer(
      (_) async => const Right([
        CollectionsCandidate(
          contactId: 'us',
          name: 'us',
          email: 'us@example.com',
          phone: usPhone,
          ledgerId: 'ledger',
          netBalance: -100,
          currencyCode: 'USD',
          ageDays: 12,
          toneBand: ReminderToneBand.reminder,
          rail: OutreachRail.both,
        ),
      ]),
    );
    final c = container(
      callePolicy: const CalleDevicePolicy(
        allowDial: true,
        allowlist: {usPhone},
        allowlistRegion: 'US',
      ),
    );
    addTearDown(c.dispose);
    final notifier = c.read(closingAgentControllerProvider.notifier);

    await notifier.openCreditLimitDesk('us');
    notifier.state = notifier.state.copyWith(
      callProgress: const CollectionsCallProgress(
        results: [
          CollectionsCallProgressRow(
            contactId: 'us',
            status: CollectionsCallRowStatus.completed,
            runId: 'run-12345678',
          ),
        ],
      ),
    );

    final state = c.read(closingAgentControllerProvider);
    expect(state.creditLimitCallSessionTerminal, isTrue);
    expect(state.creditLimitSessionContactId, 'us');
  });
}
