import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/agent_turn_result.dart';
import 'package:daftar/domain/value_objects/ask_books_answer.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/presentation/providers/architecture_hud_provider.dart';
import 'package:daftar/presentation/providers/closing_agent_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const turn = AgentTurnResult(
    correlationId: '550e8400-e29b-41d4-a716-446655440000',
    sessionId: 'session-1',
    proposals: [],
    modelId: 'gemini-3.5-flash',
    toolNames: ['propose_debt'],
    latencyMs: 420,
  );

  CollectionsDeskRow row({
    required CollectionsDeskRowStatus status,
    String? smtpMessageId,
    int? smtpCode,
  }) {
    return CollectionsDeskRow(
      candidate: const CollectionsCandidate(
        contactId: 'c1',
        name: 'Amina',
        ledgerId: 'ledger',
        netBalance: -1500,
        currencyCode: 'YER',
        ageDays: 12,
        toneBand: ReminderToneBand.reminder,
      ),
      body: 'body',
      toneBand: ReminderToneBand.reminder,
      attachPdf: false,
      status: status,
      smtpMessageId: smtpMessageId,
      smtpCode: smtpCode,
    );
  }

  test('tail8 uses UUID raw last-8', () {
    expect(
      ArchitectureHudSnapshot.tail8('550e8400-e29b-41d4-a716-446655440000'),
      '55440000',
    );
  });

  test('tail8 strips Message-ID brackets and uses local-part last-8', () {
    expect(
      ArchitectureHudSnapshot.tail8('<19c8a4f0d2abcdef@gmail.com>'),
      'd2abcdef',
    );
  });

  test('tail8 returns short ids unchanged', () {
    expect(ArchitectureHudSnapshot.tail8('corr-1'), 'corr-1');
    expect(ArchitectureHudSnapshot.tail8('  '), isNull);
    expect(ArchitectureHudSnapshot.tail8(null), isNull);
  });

  test('disabled snapshot is not visible even with a turn', () {
    final snapshot = ArchitectureHudSnapshot.fromAgent(
      enabled: false,
      turnResult: turn,
    );
    expect(snapshot.visible, isFalse);
    expect(snapshot.enabled, isFalse);
  });

  test('enabled with no turn still visible and pins model id', () {
    final snapshot = ArchitectureHudSnapshot.fromAgent(enabled: true);
    expect(snapshot.visible, isTrue);
    expect(snapshot.modelId, 'gemini-3.5-flash');
    expect(snapshot.hitlStep, ArchitectureHudHitlStep.propose);
  });

  test('fromAgent copies /run echo fields', () {
    final snapshot = ArchitectureHudSnapshot.fromAgent(
      enabled: true,
      turnResult: turn,
    );
    expect(snapshot.visible, isTrue);
    expect(snapshot.modelId, 'gemini-3.5-flash');
    expect(snapshot.toolNames, ['propose_debt']);
    expect(snapshot.toolScope, ArchitectureHudToolScope.capture);
    expect(snapshot.latencyMs, 420);
    expect(snapshot.correlationId, turn.correlationId);
    expect(snapshot.smtpMessageId, isNull);
  });

  test('fromAgent uses last accepted send-batch Message-ID', () {
    final snapshot = ArchitectureHudSnapshot.fromAgent(
      enabled: true,
      turnResult: turn,
      deskRows: [
        row(
          status: CollectionsDeskRowStatus.failed,
          smtpMessageId: '<failed@gmail.com>',
          smtpCode: 550,
        ),
        row(
          status: CollectionsDeskRowStatus.sent,
          smtpMessageId: '<11111111aaaabbbb@gmail.com>',
          smtpCode: 250,
        ),
        row(
          status: CollectionsDeskRowStatus.sent,
          smtpMessageId: '<22222222ccccdddd@gmail.com>',
          smtpCode: 250,
        ),
      ],
    );
    expect(snapshot.smtpMessageId, '<22222222ccccdddd@gmail.com>');
    expect(ArchitectureHudSnapshot.tail8(snapshot.smtpMessageId), 'ccccdddd');
    expect(snapshot.deskSentCount, 2);
  });

  test('fromAgent ignores sent rows without SMTP 250 and Message-ID', () {
    final snapshot = ArchitectureHudSnapshot.fromAgent(
      enabled: true,
      turnResult: turn,
      deskRows: [
        row(
          status: CollectionsDeskRowStatus.sent,
          smtpMessageId: '<no-code@gmail.com>',
        ),
        row(
          status: CollectionsDeskRowStatus.sent,
          smtpCode: 250,
        ),
      ],
    );
    expect(snapshot.smtpMessageId, isNull);
    expect(snapshot.deskSentCount, 0);
  });

  test('resolveCallChip uses last runId and latest status', () {
    const progress = CollectionsCallProgress(
      results: [
        CollectionsCallProgressRow(
          contactId: 'a',
          status: CollectionsCallRowStatus.planned,
        ),
        CollectionsCallProgressRow(
          contactId: 'b',
          status: CollectionsCallRowStatus.ringing,
          runId: '550e8400-e29b-41d4-a716-446655440000',
        ),
        CollectionsCallProgressRow(
          contactId: 'c',
          status: CollectionsCallRowStatus.completed,
          runId: '11111111-2222-3333-4444-555566667777',
        ),
      ],
    );

    final chip = ArchitectureHudSnapshot.resolveCallChip(progress);
    expect(chip.runId, '11111111-2222-3333-4444-555566667777');
    expect(chip.status, CollectionsCallRowStatus.completed);
    expect(ArchitectureHudSnapshot.tail8(chip.runId), '66667777');
  });

  test('resolveCallChip returns planned without runId before run-batch', () {
    const progress = CollectionsCallProgress(
      results: [
        CollectionsCallProgressRow(
          contactId: 'a',
          status: CollectionsCallRowStatus.planned,
        ),
      ],
    );

    final chip = ArchitectureHudSnapshot.resolveCallChip(progress);
    expect(chip.runId, isNull);
    expect(chip.status, CollectionsCallRowStatus.planned);
  });

  test('fromAgent maps call progress to HUD fields', () {
    final snapshot = ArchitectureHudSnapshot.fromAgent(
      enabled: true,
      turnResult: turn,
      callProgress: const CollectionsCallProgress(
        results: [
          CollectionsCallProgressRow(
            contactId: 'c1',
            status: CollectionsCallRowStatus.completed,
            runId: 'call_zQn3UWw0E9hTHp1rN2R75g',
          ),
        ],
      ),
    );

    expect(snapshot.callRunId, 'call_zQn3UWw0E9hTHp1rN2R75g');
    expect(snapshot.callStatus, CollectionsCallRowStatus.completed);
    expect(ArchitectureHudSnapshot.tail8(snapshot.callRunId), '1rN2R75g');
    expect(snapshot.smtpMessageId, isNull);
  });

  test('fromAgent keeps SMTP last-8 unchanged with call chip present', () {
    final snapshot = ArchitectureHudSnapshot.fromAgent(
      enabled: true,
      turnResult: turn,
      deskRows: [
        row(
          status: CollectionsDeskRowStatus.sent,
          smtpMessageId: '<22222222ccccdddd@gmail.com>',
          smtpCode: 250,
        ),
      ],
      callProgress: const CollectionsCallProgress(
        results: [
          CollectionsCallProgressRow(
            contactId: 'c1',
            status: CollectionsCallRowStatus.ringing,
            runId: '550e8400-e29b-41d4-a716-446655440000',
          ),
        ],
      ),
    );

    expect(snapshot.smtpMessageId, '<22222222ccccdddd@gmail.com>');
    expect(ArchitectureHudSnapshot.tail8(snapshot.smtpMessageId), 'ccccdddd');
    expect(snapshot.callStatus, CollectionsCallRowStatus.ringing);
  });

  group('resolveHitlStep', () {
    test('running maps to propose', () {
      expect(
        ArchitectureHudSnapshot.resolveHitlStep(
          phase: ClosingAgentPhase.running,
          pendingConfirmableCount: 0,
          hasPendingClosingPlan: false,
          committedIds: const {},
          deskPendingCount: 0,
          collectionsDispatching: false,
        ),
        ArchitectureHudHitlStep.propose,
      );
    });

    test('pending proposal maps to confirm', () {
      expect(
        ArchitectureHudSnapshot.resolveHitlStep(
          phase: ClosingAgentPhase.ready,
          pendingConfirmableCount: 1,
          hasPendingClosingPlan: false,
          committedIds: const {},
          deskPendingCount: 0,
          collectionsDispatching: false,
        ),
        ArchitectureHudHitlStep.confirm,
      );
    });

    test('pending closing plan maps to confirm', () {
      expect(
        ArchitectureHudSnapshot.resolveHitlStep(
          phase: ClosingAgentPhase.ready,
          pendingConfirmableCount: 0,
          hasPendingClosingPlan: true,
          committedIds: const {},
          deskPendingCount: 0,
          collectionsDispatching: false,
        ),
        ArchitectureHudHitlStep.confirm,
      );
    });

    test('ritual running maps to commit', () {
      expect(
        ArchitectureHudSnapshot.resolveHitlStep(
          phase: ClosingAgentPhase.ritualRunning,
          pendingConfirmableCount: 0,
          hasPendingClosingPlan: false,
          committedIds: const {},
          deskPendingCount: 0,
          collectionsDispatching: false,
        ),
        ArchitectureHudHitlStep.commit,
      );
    });

    test('ritual desk with pending rows maps to confirm when not dispatching', () {
      expect(
        ArchitectureHudSnapshot.resolveHitlStep(
          phase: ClosingAgentPhase.ritualDesk,
          pendingConfirmableCount: 0,
          hasPendingClosingPlan: false,
          committedIds: const {'p1'},
          deskPendingCount: 2,
          collectionsDispatching: false,
        ),
        ArchitectureHudHitlStep.confirm,
      );
    });

    test('ritual desk maps to rank when dispatching or no pending rows', () {
      expect(
        ArchitectureHudSnapshot.resolveHitlStep(
          phase: ClosingAgentPhase.ritualDesk,
          pendingConfirmableCount: 0,
          hasPendingClosingPlan: false,
          committedIds: const {'p1'},
          deskPendingCount: 2,
          collectionsDispatching: true,
        ),
        ArchitectureHudHitlStep.rank,
      );
      expect(
        ArchitectureHudSnapshot.resolveHitlStep(
          phase: ClosingAgentPhase.ritualDesk,
          pendingConfirmableCount: 0,
          hasPendingClosingPlan: false,
          committedIds: const {'p1'},
          deskPendingCount: 0,
          collectionsDispatching: false,
        ),
        ArchitectureHudHitlStep.rank,
      );
    });

    test('committed ids map to commit when idle', () {
      expect(
        ArchitectureHudSnapshot.resolveHitlStep(
          phase: ClosingAgentPhase.ready,
          pendingConfirmableCount: 0,
          hasPendingClosingPlan: false,
          committedIds: const {'p1'},
          deskPendingCount: 0,
          collectionsDispatching: false,
        ),
        ArchitectureHudHitlStep.commit,
      );
    });
  });

  group('resolveToolScope', () {
    test('ask answer maps to ask', () {
      expect(
        ArchitectureHudSnapshot.resolveToolScope(
          askAnswer: const AskBooksOverdueList([]),
          toolNames: const ['propose_debt'],
        ),
        ArchitectureHudToolScope.ask,
      );
    });

    test('closing plan maps to close', () {
      expect(
        ArchitectureHudSnapshot.resolveToolScope(
          toolNames: const ['propose_closing_plan'],
        ),
        ArchitectureHudToolScope.close,
      );
    });

    test('debt maps to capture', () {
      expect(
        ArchitectureHudSnapshot.resolveToolScope(
          toolNames: const ['propose_debt'],
        ),
        ArchitectureHudToolScope.capture,
      );
    });

    test('empty maps to none', () {
      expect(
        ArchitectureHudSnapshot.resolveToolScope(),
        ArchitectureHudToolScope.none,
      );
    });
  });
}
