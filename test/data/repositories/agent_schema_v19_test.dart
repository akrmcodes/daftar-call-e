import 'dart:async';

import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/data/datasources/local/agent_outbox_local_ds.dart';
import 'package:daftar/data/datasources/local/agent_session_local_ds.dart';
import 'package:daftar/data/datasources/local/agent_turn_local_ds.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/contact_local_ds.dart';
import 'package:daftar/data/datasources/local/day_journal_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart'
    hide AgentSession, AgentTurn, DayJournalEntry;
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/repositories/agent_outbox_repository_impl.dart';
import 'package:daftar/data/repositories/agent_session_repository_impl.dart';
import 'package:daftar/data/repositories/agent_turn_repository_impl.dart';
import 'package:daftar/data/repositories/day_journal_repository_impl.dart';
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
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  group('Contest schema v25', () {
    late AppDatabase database;
    late DayJournalRepositoryImpl journalRepository;
    late AgentSessionRepositoryImpl sessionRepository;
    late AgentTurnRepositoryImpl turnRepository;
    late AgentOutboxRepositoryImpl outboxRepository;
    late AuditLogLocalDataSource auditLogLocalDataSource;

    setUp(() {
      DeviceIdentity.initializeForTest('agent-schema-test-device');
      database = AppDatabase(NativeDatabase.memory());
      auditLogLocalDataSource = AuditLogLocalDataSource(database);
      journalRepository = DayJournalRepositoryImpl(
        dayJournalLocalDataSource: DayJournalLocalDataSource(database),
      );
      sessionRepository = AgentSessionRepositoryImpl(
        agentSessionLocalDataSource: AgentSessionLocalDataSource(database),
        auditLogLocalDataSource: auditLogLocalDataSource,
      );
      turnRepository = AgentTurnRepositoryImpl(
        agentTurnLocalDataSource: AgentTurnLocalDataSource(database),
        auditLogLocalDataSource: auditLogLocalDataSource,
      );
      outboxRepository = AgentOutboxRepositoryImpl(
        agentOutboxLocalDataSource: AgentOutboxLocalDataSource(database),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('schemaVersion is 25 and session → turn → journal persist', () async {
      expect(database.schemaVersion, DbConstants.schemaVersion);
      expect(database.schemaVersion, 25);

      final settings = await database.select(database.appSettingsTable).getSingle();
      expect(settings.ttsMuted, isFalse);
      expect(settings.demoArchitectureHud, isFalse);

      final now = DateTime.utc(2026, 8, 13, 18);
      final session = await expectRight(
        sessionRepository.create(
          AgentSession(
            id: 'session-001',
            mode: AgentSessionMode.capture,
            status: AgentSessionStatus.active,
            startedAt: now,
            createdAt: now,
            updatedAt: now,
            correlationId: 'corr-001',
          ),
        ),
      );

      final turn = await expectRight(
        turnRepository.append(
          AgentTurn(
            id: 'turn-001',
            sessionId: session.id,
            role: AgentTurnRole.user,
            confirmState: AgentTurnConfirmState.none,
            createdAt: now,
            updatedAt: now,
            transcript: 'Mohamed owes 500',
          ),
        ),
      );

      final entry = await expectRight(
        journalRepository.append(
          DayJournalEntry(
            id: 'journal-001',
            localDay: '2026-08-13',
            kind: DayJournalKind.debtConfirmed,
            payloadJson: '{"amount":500}',
            createdAt: now,
            amount: 500,
            currencyCode: 'YER',
            sessionId: session.id,
            proposalId: turn.proposalId,
          ),
        ),
      );

      final listed = await expectRight(
        journalRepository.listByLocalDay('2026-08-13'),
      );
      expect(listed, hasLength(1));
      expect(listed.single.id, entry.id);
      expect(listed.single.amount, 500);

      final pending = await expectRight(
        outboxRepository.enqueue(
          AgentOutboxItem(
            id: 'outbox-001',
            kind: 'pending_run',
            status: AgentOutboxStatus.queued,
            payloadJson: '{"goal":"close day"}',
            createdAt: now,
            updatedAt: now,
          ),
        ),
      );
      final due = await expectRight(outboxRepository.listPending());
      expect(due.map((item) => item.id), contains(pending.id));

      final sessionLogs = await auditLogLocalDataSource.getLogsByEntity(
        'agent_session',
        session.id,
      );
      expect(sessionLogs, isNotEmpty);
      expect(sessionLogs.first.action, 'CREATE');

      final turnLogs = await auditLogLocalDataSource.getLogsByEntity(
        'agent_turn',
        turn.id,
      );
      expect(turnLogs, isNotEmpty);
      expect(turnLogs.first.action, 'CREATE');
    });

    test('contact email round-trip and eligible query requires email', () async {
      final now = DateTime.utc(2026, 8, 20);
      await database.into(database.ledgers).insert(
        LedgersCompanion.insert(
          id: 'ledger-email',
          name: 'Customers',
          type: LedgerType.customers,
          icon: 'store',
          color: '#6E6E76',
          sortOrder: 0,
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final contacts = ContactLocalDataSource(database);
      await database.into(database.contacts).insert(
        ContactModel(
          id: 'c-email',
          ledgerId: 'ledger-email',
          name: 'Has Email',
          phone: null,
          email: 'local+tag@gmail.com',
          notes: null,
          creditLimit: null,
          creditCurrency: null,
          avatarColor: '#6E6E76',
          createdAt: now,
          updatedAt: now,
        ).toDrift(),
      );
      await database.into(database.contacts).insert(
        ContactModel(
          id: 'c-phone',
          ledgerId: 'ledger-email',
          name: 'Phone Only',
          phone: '+967700000001',
          notes: null,
          creditLimit: null,
          creditCurrency: null,
          avatarColor: '#6E6E76',
          createdAt: now,
          updatedAt: now,
        ).toDrift(),
      );

      final loaded = await contacts.getContactById('c-email');
      expect(loaded?.email, 'local+tag@gmail.com');

      final eligible = await contacts.getContactsEligibleForAutomatedReminders();
      expect(eligible.map((row) => row.contactId), ['c-email']);
      expect(eligible.single.email, 'local+tag@gmail.com');
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
