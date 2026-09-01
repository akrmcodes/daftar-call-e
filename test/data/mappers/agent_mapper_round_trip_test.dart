import 'package:daftar/data/mappers/agent_outbox_item_mapper.dart';
import 'package:daftar/data/mappers/agent_session_mapper.dart';
import 'package:daftar/data/mappers/agent_turn_mapper.dart';
import 'package:daftar/data/mappers/day_journal_entry_mapper.dart';
import 'package:daftar/domain/entities/agent_outbox_item.dart' as domain;
import 'package:daftar/domain/entities/agent_session.dart' as domain;
import 'package:daftar/domain/entities/agent_turn.dart' as domain;
import 'package:daftar/domain/entities/day_journal_entry.dart' as domain;
import 'package:daftar/domain/enums/agent_outbox_status.dart';
import 'package:daftar/domain/enums/agent_session_mode.dart';
import 'package:daftar/domain/enums/agent_session_status.dart';
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/enums/agent_turn_role.dart';
import 'package:daftar/domain/enums/day_journal_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DayJournalEntry mapping', () {
    test('round-trips through model, row, and companion', () {
      final entry = domain.DayJournalEntry(
        id: 'journal-001',
        localDay: '2026-08-13',
        kind: DayJournalKind.debtConfirmed,
        payloadJson: '{"proposalId":"p1"}',
        createdAt: DateTime.utc(2026, 8, 13, 9),
        ledgerId: 'ledger-001',
        contactId: 'contact-001',
        amount: 500,
        currencyCode: 'YER',
        proposalId: 'proposal-001',
        sessionId: 'session-001',
      );

      final model = entry.toModel();

      expect(model.toDomain(), equals(entry));
      expect(model.toDrift().toDomain(), equals(entry));
      expect(entry.toDrift().toDomain(), equals(entry));
      expect(entry.toCompanion().toDomain(), equals(entry));
      expect(entry.toCompanion().toModel().toDomain(), equals(entry));
      expect(entry.toCompanion().toDrift().toDomain(), equals(entry));
    });
  });

  group('AgentSession mapping', () {
    test('round-trips through model, row, and companion', () {
      final session = domain.AgentSession(
        id: 'session-001',
        mode: AgentSessionMode.closing,
        status: AgentSessionStatus.completed,
        startedAt: DateTime.utc(2026, 8, 13, 18),
        createdAt: DateTime.utc(2026, 8, 13, 18),
        updatedAt: DateTime.utc(2026, 8, 13, 19),
        endedAt: DateTime.utc(2026, 8, 13, 19),
        correlationId: 'corr-001',
        isDeleted: true,
        syncVersion: 4,
      );

      final model = session.toModel();

      expect(model.toDomain(), equals(session));
      expect(model.toDrift().toDomain(), equals(session));
      expect(session.toDrift().toDomain(), equals(session));
      expect(session.toCompanion().toDomain(), equals(session));
      expect(session.toCompanion().toModel().toDomain(), equals(session));
      expect(session.toCompanion().toDrift().toDomain(), equals(session));
    });
  });

  group('AgentTurn mapping', () {
    test('round-trips through model, row, and companion', () {
      final turn = domain.AgentTurn(
        id: 'turn-001',
        sessionId: 'session-001',
        role: AgentTurnRole.agent,
        confirmState: AgentTurnConfirmState.pending,
        createdAt: DateTime.utc(2026, 8, 13, 18, 1),
        updatedAt: DateTime.utc(2026, 8, 13, 18, 2),
        transcript: 'Mohamed owes 500',
        proposalJson: '{"kind":"debt"}',
        proposalId: 'proposal-001',
        toolName: 'propose_debt',
        isDeleted: true,
        syncVersion: 2,
      );

      final model = turn.toModel();

      expect(model.toDomain(), equals(turn));
      expect(model.toDrift().toDomain(), equals(turn));
      expect(turn.toDrift().toDomain(), equals(turn));
      expect(turn.toCompanion().toDomain(), equals(turn));
      expect(turn.toCompanion().toModel().toDomain(), equals(turn));
      expect(turn.toCompanion().toDrift().toDomain(), equals(turn));
    });
  });

  group('AgentOutboxItem mapping', () {
    test('round-trips through model, row, and companion', () {
      final item = domain.AgentOutboxItem(
        id: 'outbox-001',
        kind: 'pending_run',
        status: AgentOutboxStatus.retrying,
        payloadJson: '{"goal":"close day"}',
        createdAt: DateTime.utc(2026, 8, 13, 10),
        updatedAt: DateTime.utc(2026, 8, 13, 11),
        attempts: 3,
        nextRetryAt: DateTime.utc(2026, 8, 13, 12),
      );

      final model = item.toModel();

      expect(model.toDomain(), equals(item));
      expect(model.toDrift().toDomain(), equals(item));
      expect(item.toDrift().toDomain(), equals(item));
      expect(item.toCompanion().toDomain(), equals(item));
      expect(item.toCompanion().toModel().toDomain(), equals(item));
      expect(item.toCompanion().toDrift().toDomain(), equals(item));
    });
  });
}
