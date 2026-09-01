import 'dart:async';

import 'package:daftar/application/agent/append_agent_turn_use_case.dart';
import 'package:daftar/application/agent/append_day_journal_entry_use_case.dart';
import 'package:daftar/application/agent/complete_agent_session_use_case.dart';
import 'package:daftar/application/agent/enqueue_agent_outbox_item_use_case.dart';
import 'package:daftar/application/agent/list_day_journal_entries_use_case.dart';
import 'package:daftar/application/agent/list_pending_agent_outbox_use_case.dart';
import 'package:daftar/application/agent/start_agent_session_use_case.dart';
import 'package:daftar/application/agent/update_agent_turn_confirm_state_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/agent_outbox_item.dart';
import 'package:daftar/domain/entities/agent_session.dart';
import 'package:daftar/domain/entities/agent_turn.dart';
import 'package:daftar/domain/entities/day_journal_entry.dart';
import 'package:daftar/domain/enums/agent_outbox_status.dart';
import 'package:daftar/domain/enums/agent_session_mode.dart';
import 'package:daftar/domain/enums/agent_session_status.dart';
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/enums/agent_turn_role.dart';
import 'package:daftar/domain/enums/day_journal_kind.dart';
import 'package:daftar/domain/repositories/agent_outbox_repository.dart';
import 'package:daftar/domain/repositories/agent_session_repository.dart';
import 'package:daftar/domain/repositories/agent_turn_repository.dart';
import 'package:daftar/domain/repositories/day_journal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockDayJournalRepository extends Mock implements DayJournalRepository {}

class MockAgentSessionRepository extends Mock
    implements AgentSessionRepository {}

class MockAgentTurnRepository extends Mock implements AgentTurnRepository {}

class MockAgentOutboxRepository extends Mock implements AgentOutboxRepository {}

void main() {
  late MockDayJournalRepository journalRepository;
  late MockAgentSessionRepository sessionRepository;
  late MockAgentTurnRepository turnRepository;
  late MockAgentOutboxRepository outboxRepository;

  setUpAll(() {
    registerFallbackValue(
      DayJournalEntry(
        id: 'fallback-journal-id',
        localDay: '2026-08-13',
        kind: DayJournalKind.note,
        payloadJson: '{}',
        createdAt: DateTime.utc(2026, 8, 13),
      ),
    );
    registerFallbackValue(
      AgentSession(
        id: 'fallback-session-id',
        mode: AgentSessionMode.capture,
        status: AgentSessionStatus.active,
        startedAt: DateTime.utc(2026, 8, 13),
        createdAt: DateTime.utc(2026, 8, 13),
        updatedAt: DateTime.utc(2026, 8, 13),
      ),
    );
    registerFallbackValue(
      AgentTurn(
        id: 'fallback-turn-id',
        sessionId: 'fallback-session-id',
        role: AgentTurnRole.user,
        confirmState: AgentTurnConfirmState.none,
        createdAt: DateTime.utc(2026, 8, 13),
        updatedAt: DateTime.utc(2026, 8, 13),
      ),
    );
    registerFallbackValue(
      AgentOutboxItem(
        id: 'fallback-outbox-id',
        kind: 'pending_run',
        status: AgentOutboxStatus.queued,
        payloadJson: '{}',
        createdAt: DateTime.utc(2026, 8, 13),
        updatedAt: DateTime.utc(2026, 8, 13),
      ),
    );
    registerFallbackValue(AgentSessionStatus.completed);
    registerFallbackValue(AgentTurnConfirmState.confirmed);
  });

  setUp(() {
    journalRepository = MockDayJournalRepository();
    sessionRepository = MockAgentSessionRepository();
    turnRepository = MockAgentTurnRepository();
    outboxRepository = MockAgentOutboxRepository();
  });

  group('AppendDayJournalEntryUseCase', () {
    test('rejects invalid localDay', () async {
      final useCase = AppendDayJournalEntryUseCase(journalRepository);
      final result = await useCase.execute(
        localDay: '13-08-2026',
        kind: DayJournalKind.note,
        payloadJson: '{}',
      );

      expect(result.getLeft().toNullable()?.code, 'invalid_local_day');
      verifyNever(() => journalRepository.append(any()));
    });

    test('rejects negative amount', () async {
      final useCase = AppendDayJournalEntryUseCase(journalRepository);
      final result = await useCase.execute(
        localDay: '2026-08-13',
        kind: DayJournalKind.debtConfirmed,
        payloadJson: '{}',
        amount: -1,
      );

      expect(result.getLeft().toNullable()?.code, 'invalid_journal_amount');
      verifyNever(() => journalRepository.append(any()));
    });

    test('appends on happy path', () async {
      final useCase = AppendDayJournalEntryUseCase(journalRepository);
      when(() => journalRepository.append(any())).thenAnswer((
        invocation,
      ) async {
        return Right(invocation.positionalArguments.first as DayJournalEntry);
      });

      final result = await expectRight(
        useCase.execute(
          localDay: '2026-08-13',
          kind: DayJournalKind.debtConfirmed,
          payloadJson: '{"ok":true}',
          amount: 500,
          currencyCode: 'yer',
        ),
      );

      expect(result.localDay, '2026-08-13');
      expect(result.amount, 500);
      expect(result.currencyCode, 'YER');
      expect(result.id, isNotEmpty);
    });
  });

  group('ListDayJournalEntriesUseCase', () {
    test('rejects invalid localDay', () async {
      final useCase = ListDayJournalEntriesUseCase(journalRepository);
      final result = await useCase.execute('2026/08/13');
      expect(result.getLeft().toNullable()?.code, 'invalid_local_day');
      verifyNever(() => journalRepository.listByLocalDay(any()));
    });

    test('lists on happy path', () async {
      final useCase = ListDayJournalEntriesUseCase(journalRepository);
      when(
        () => journalRepository.listByLocalDay('2026-08-13'),
      ).thenAnswer((_) async => const Right(<DayJournalEntry>[]));

      final result = await expectRight(useCase.execute('2026-08-13'));
      expect(result, isEmpty);
    });
  });

  group('StartAgentSessionUseCase', () {
    test('creates an active session', () async {
      final useCase = StartAgentSessionUseCase(sessionRepository);
      when(() => sessionRepository.create(any())).thenAnswer((
        invocation,
      ) async {
        return Right(invocation.positionalArguments.first as AgentSession);
      });

      final result = await expectRight(
        useCase.execute(
          mode: AgentSessionMode.closing,
          correlationId: ' corr-1 ',
        ),
      );

      expect(result.status, AgentSessionStatus.active);
      expect(result.mode, AgentSessionMode.closing);
      expect(result.correlationId, 'corr-1');
    });
  });

  group('CompleteAgentSessionUseCase', () {
    test('rejects empty session id', () async {
      final useCase = CompleteAgentSessionUseCase(sessionRepository);
      final result = await useCase.execute(sessionId: '  ');
      expect(result.getLeft().toNullable()?.code, 'session_id_required');
    });

    test('rejects active status', () async {
      final useCase = CompleteAgentSessionUseCase(sessionRepository);
      final result = await useCase.execute(
        sessionId: 'session-1',
        status: AgentSessionStatus.active,
      );
      expect(result.getLeft().toNullable()?.code, 'invalid_session_status');
    });

    test('completes on happy path', () async {
      final useCase = CompleteAgentSessionUseCase(sessionRepository);
      final completed = AgentSession(
        id: 'session-1',
        mode: AgentSessionMode.capture,
        status: AgentSessionStatus.completed,
        startedAt: DateTime.utc(2026, 8, 13),
        createdAt: DateTime.utc(2026, 8, 13),
        updatedAt: DateTime.utc(2026, 8, 13, 1),
        endedAt: DateTime.utc(2026, 8, 13, 1),
      );
      when(
        () => sessionRepository.complete(
          sessionId: any(named: 'sessionId'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) async => Right(completed));

      final result = await expectRight(
        useCase.execute(sessionId: 'session-1'),
      );
      expect(result.status, AgentSessionStatus.completed);
    });
  });

  group('AppendAgentTurnUseCase', () {
    test('rejects empty session id', () async {
      final useCase = AppendAgentTurnUseCase(turnRepository);
      final result = await useCase.execute(
        sessionId: '',
        role: AgentTurnRole.user,
      );
      expect(result.getLeft().toNullable()?.code, 'session_id_required');
    });

    test('appends on happy path', () async {
      final useCase = AppendAgentTurnUseCase(turnRepository);
      when(() => turnRepository.append(any())).thenAnswer((invocation) async {
        return Right(invocation.positionalArguments.first as AgentTurn);
      });

      final result = await expectRight(
        useCase.execute(
          sessionId: 'session-1',
          role: AgentTurnRole.tool,
          toolName: 'propose_debt',
          confirmState: AgentTurnConfirmState.pending,
        ),
      );
      expect(result.sessionId, 'session-1');
      expect(result.toolName, 'propose_debt');
    });
  });

  group('UpdateAgentTurnConfirmStateUseCase', () {
    test('rejects empty turn id', () async {
      final useCase = UpdateAgentTurnConfirmStateUseCase(turnRepository);
      final result = await useCase.execute(
        turnId: ' ',
        confirmState: AgentTurnConfirmState.confirmed,
      );
      expect(result.getLeft().toNullable()?.code, 'turn_id_required');
    });

    test('updates on happy path', () async {
      final useCase = UpdateAgentTurnConfirmStateUseCase(turnRepository);
      final updated = AgentTurn(
        id: 'turn-1',
        sessionId: 'session-1',
        role: AgentTurnRole.agent,
        confirmState: AgentTurnConfirmState.confirmed,
        createdAt: DateTime.utc(2026, 8, 13),
        updatedAt: DateTime.utc(2026, 8, 13, 1),
      );
      when(
        () => turnRepository.updateConfirmState(
          turnId: any(named: 'turnId'),
          confirmState: any(named: 'confirmState'),
        ),
      ).thenAnswer((_) async => Right(updated));

      final result = await expectRight(
        useCase.execute(
          turnId: 'turn-1',
          confirmState: AgentTurnConfirmState.confirmed,
        ),
      );
      expect(result.confirmState, AgentTurnConfirmState.confirmed);
    });
  });

  group('EnqueueAgentOutboxItemUseCase', () {
    test('rejects empty kind', () async {
      final useCase = EnqueueAgentOutboxItemUseCase(outboxRepository);
      final result = await useCase.execute(kind: ' ', payloadJson: '{}');
      expect(result.getLeft().toNullable()?.code, 'outbox_kind_required');
    });

    test('enqueues on happy path', () async {
      final useCase = EnqueueAgentOutboxItemUseCase(outboxRepository);
      when(() => outboxRepository.enqueue(any())).thenAnswer((
        invocation,
      ) async {
        return Right(invocation.positionalArguments.first as AgentOutboxItem);
      });

      final result = await expectRight(
        useCase.execute(kind: 'pending_run', payloadJson: '{"ok":true}'),
      );
      expect(result.kind, 'pending_run');
      expect(result.status, AgentOutboxStatus.queued);
    });
  });

  group('ListPendingAgentOutboxUseCase', () {
    test('returns repository result', () async {
      final useCase = ListPendingAgentOutboxUseCase(outboxRepository);
      when(
        () => outboxRepository.listPending(),
      ).thenAnswer((_) async => const Right(<AgentOutboxItem>[]));

      final result = await expectRight(useCase.execute());
      expect(result, isEmpty);
    });
  });
}

Future<T> expectRight<T>(FutureOr<Either<Failure, T>> futureOrResult) async {
  final result = await futureOrResult;
  return result.fold(
    (failure) => fail('Expected Right but got Left($failure)'),
    (value) => value,
  );
}
