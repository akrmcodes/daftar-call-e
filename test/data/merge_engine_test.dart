import 'dart:convert';

import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/datasources/local/merge_engine_local_ds.dart';
import 'package:daftar/data/models/sync_operation_model.dart';
import 'package:daftar/domain/enums/conflict_type.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MergeEngineLocalDs mergeEngine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    mergeEngine = MergeEngineLocalDs(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ════════════════════════════════════════════════════════════════════
  // HELPER FUNCTIONS
  // ════════════════════════════════════════════════════════════════════

  SyncOperationModel createOp({
    required String id,
    required String entityType,
    required String entityId,
    required String action,
    String? fieldDeltas,
    String deviceId = 'device-A',
    String role = 'owner',
    int opSeq = 1,
    DateTime? serverUpdatedAt,
  }) {
    return SyncOperationModel(
      id: id,
      entityType: entityType,
      entityId: entityId,
      action: action,
      fieldDeltas: fieldDeltas,
      deviceId: deviceId,
      role: role,
      localTimestamp: DateTime.utc(2026, 7),
      serverUpdatedAt: serverUpdatedAt ?? DateTime.utc(2026, 7, 1, 12),
      opSeq: opSeq,
    );
  }

  Future<void> seedLedger({
    String id = 'ledger-1',
    String name = 'Test Ledger',
    bool isDeleted = false,
    DateTime? updatedAt,
  }) async {
    await db.into(db.ledgers).insert(
      LedgersCompanion.insert(
        id: id,
        name: name,
        type: LedgerType.customers,
        icon: 'store',
        color: '#6E6E76',
        sortOrder: 0,
        isDeleted: Value(isDeleted),
        updatedAt: Value(updatedAt ?? DateTime.utc(2026, 7, 1, 10)),
      ),
    );
  }

  Future<void> seedContact({
    String id = 'contact-1',
    String ledgerId = 'ledger-1',
    String name = 'Test Contact',
    bool isDeleted = false,
    DateTime? updatedAt,
  }) async {
    await db.into(db.contacts).insert(
      ContactsCompanion.insert(
        id: id,
        ledgerId: ledgerId,
        name: name,
        avatarColor: '#6E6E76',
        isDeleted: Value(isDeleted),
        updatedAt: Value(updatedAt ?? DateTime.utc(2026, 7, 1, 10)),
      ),
    );
  }

  Future<void> seedTransaction({
    String id = 'txn-1',
    String contactId = 'contact-1',
    TransactionType type = TransactionType.debt,
    int amount = 1000,
    String currency = 'YER',
    bool isDeleted = false,
    DateTime? updatedAt,
  }) async {
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: id,
        contactId: contactId,
        type: type,
        amount: amount,
        currency: currency,
        transactionDate: DateTime.utc(2026, 7),
        isDeleted: Value(isDeleted),
        updatedAt: Value(updatedAt ?? DateTime.utc(2026, 7, 1, 10)),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // TEST GROUP 1: IDEMPOTENCY
  // ════════════════════════════════════════════════════════════════════

  group('Idempotency guard', () {
    test('duplicate op is skipped on retry', () async {
      await seedLedger();

      final op = createOp(
        id: 'op-1',
        entityType: 'ledger',
        entityId: 'ledger-1',
        action: 'UPDATE',
        fieldDeltas: jsonEncode({'name': 'Updated Name'}),
      );

      // First application.
      final result1 = await mergeEngine.applyRemoteOps([op]);
      expect(result1.applied, 1);
      expect(result1.skipped, 0);

      // Retry — should be skipped.
      final result2 = await mergeEngine.applyRemoteOps([op]);
      expect(result2.applied, 0);
      expect(result2.skipped, 1);

      // Verify entity was only updated once.
      final ledger = await (db.select(db.ledgers)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();
      expect(ledger.name, 'Updated Name');
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // TEST GROUP 2: FIELD-LEVEL LWW
  // ════════════════════════════════════════════════════════════════════

  group('Field-level LWW merge', () {
    test('two devices editing different fields — both succeed', () async {
      await seedLedger(updatedAt: DateTime.utc(2026, 7, 1, 10));

      // Device A edits name.
      final opA = createOp(
        id: 'op-A',
        entityType: 'ledger',
        entityId: 'ledger-1',
        action: 'UPDATE',
        fieldDeltas: jsonEncode({'name': 'Name from A'}),
        serverUpdatedAt: DateTime.utc(2026, 7, 1, 11),
      );

      // Device B edits icon.
      final opB = createOp(
        id: 'op-B',
        entityType: 'ledger',
        entityId: 'ledger-1',
        action: 'UPDATE',
        fieldDeltas: jsonEncode({'icon': 'shop'}),
        deviceId: 'device-B',
        serverUpdatedAt: DateTime.utc(2026, 7, 1, 11, 0, 1),
        opSeq: 2,
      );

      await mergeEngine.applyRemoteOps([opA, opB]);

      final ledger = await (db.select(db.ledgers)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();

      expect(ledger.name, 'Name from A');
      expect(ledger.icon, 'shop');
    });

    test('remote newer timestamp wins per-field', () async {
      await seedLedger(
        name: 'Original',
        updatedAt: DateTime.utc(2026, 7, 1, 10),
      );

      final op = createOp(
        id: 'op-1',
        entityType: 'ledger',
        entityId: 'ledger-1',
        action: 'UPDATE',
        fieldDeltas: jsonEncode({'name': 'Remote Name'}),
        serverUpdatedAt: DateTime.utc(2026, 7, 1, 12),
      );

      await mergeEngine.applyRemoteOps([op]);

      final ledger = await (db.select(db.ledgers)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();
      expect(ledger.name, 'Remote Name');
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // TEST GROUP 3: DELETE-VS-EDIT SURVIVAL
  // ════════════════════════════════════════════════════════════════════

  group('Modification > Deletion safety rule', () {
    test('edit on deleted entity — entity un-deleted', () async {
      await seedLedger(isDeleted: true);

      final op = createOp(
        id: 'op-1',
        entityType: 'ledger',
        entityId: 'ledger-1',
        action: 'UPDATE',
        fieldDeltas: jsonEncode({'name': 'Resurrected'}),
        serverUpdatedAt: DateTime.utc(2026, 7, 1, 12),
      );

      final result = await mergeEngine.applyRemoteOps([op]);

      final ledger = await (db.select(db.ledgers)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();

      expect(ledger.isDeleted, false, reason: 'Edit must un-delete the entity');
      expect(ledger.name, 'Resurrected');
      expect(result.auditNotes, isNotEmpty,
          reason: 'Must produce an audit note about un-deletion');
    });

    test('remote delete when local has newer edit — conflict surfaced', () async {
      // Local entity was recently edited.
      await seedLedger(
        updatedAt: DateTime.utc(2026, 7, 1, 14),
      );

      // Remote sends a delete with older timestamp.
      final op = createOp(
        id: 'op-1',
        entityType: 'ledger',
        entityId: 'ledger-1',
        action: 'DELETE',
        serverUpdatedAt: DateTime.utc(2026, 7, 1, 12),
      );

      final result = await mergeEngine.applyRemoteOps([op]);

      // Entity should NOT be deleted — local edit is newer.
      final ledger = await (db.select(db.ledgers)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();
      expect(ledger.isDeleted, false);

      // Conflict should be surfaced and persisted for Sync Report / Stage 9.
      expect(result.conflicts, hasLength(1));
      expect(result.conflicts.first.conflictType, ConflictType.deleteVsEdit);

      final persisted = await mergeEngine.getUnresolvedConflicts();
      expect(persisted, hasLength(1));
      expect(persisted.first.conflictType, ConflictType.deleteVsEdit);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // TEST GROUP 4: CONCURRENT TRANSACTION INSERTS (ALWAYS ADDITIVE)
  // ════════════════════════════════════════════════════════════════════

  group('Concurrent transaction inserts', () {
    test('two devices insert different transactions — both kept', () async {
      await seedLedger();
      await seedContact();

      // Device A creates transaction 1.
      final opA = createOp(
        id: 'op-A',
        entityType: 'transaction',
        entityId: 'txn-A',
        action: 'CREATE',
        fieldDeltas: jsonEncode({
          'contactId': 'contact-1',
          'type': 'debt',
          'amount': 5000,
          'currency': 'YER',
          'transactionDate': '2026-07-01T00:00:00.000Z',
        }),
      );

      // Device B creates transaction 2.
      final opB = createOp(
        id: 'op-B',
        entityType: 'transaction',
        entityId: 'txn-B',
        action: 'CREATE',
        fieldDeltas: jsonEncode({
          'contactId': 'contact-1',
          'type': 'payment',
          'amount': 2000,
          'currency': 'YER',
          'transactionDate': '2026-07-01T00:00:00.000Z',
        }),
        deviceId: 'device-B',
        opSeq: 2,
      );

      final result = await mergeEngine.applyRemoteOps([opA, opB]);

      expect(result.applied, 2);
      expect(result.conflicts, isEmpty,
          reason: 'Transaction inserts must NEVER conflict');

      // Both transactions exist.
      final txns = await db.select(db.transactions).get();
      expect(txns, hasLength(2));

      // Balance was recalculated.
      expect(result.recalculatedContactIds, contains('contact-1'));

      // Verify balance: 5000 debt, 2000 payment, net = -3000.
      final balances = await (db.select(db.contactBalances)
            ..where((t) => t.contactId.equals('contact-1')))
          .get();
      expect(balances, hasLength(1));
      expect(balances.first.totalDebt, 5000);
      expect(balances.first.totalPayment, 2000);
      expect(balances.first.netBalance, -3000);
    });

    test('duplicate transaction CREATE is idempotent', () async {
      await seedLedger();
      await seedContact();
      await seedTransaction(id: 'txn-existing');

      final op = createOp(
        id: 'op-1',
        entityType: 'transaction',
        entityId: 'txn-existing',
        action: 'CREATE',
        fieldDeltas: jsonEncode({
          'contactId': 'contact-1',
          'type': 'debt',
          'amount': 1000,
          'currency': 'YER',
        }),
      );

      await mergeEngine.applyRemoteOps([op]);

      // Should apply (recording the op) but not duplicate the transaction.
      final txns = await db.select(db.transactions).get();
      expect(txns, hasLength(1));
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // TEST GROUP 5: BALANCE RECALCULATION (FINANCIAL INTEGRITY)
  // ════════════════════════════════════════════════════════════════════

  group('Balance recalculation', () {
    test('balance derived from transaction set — never merged arithmetically', () async {
      await seedLedger();
      await seedContact();

      // Seed two existing transactions.
      await seedTransaction(amount: 3000);
      await seedTransaction(
        id: 'txn-2',
        type: TransactionType.payment,
      );

      // Remote adds a third transaction.
      final op = createOp(
        id: 'op-1',
        entityType: 'transaction',
        entityId: 'txn-3',
        action: 'CREATE',
        fieldDeltas: jsonEncode({
          'contactId': 'contact-1',
          'type': 'payment',
          'amount': 500,
          'currency': 'YER',
          'transactionDate': '2026-07-01T00:00:00.000Z',
        }),
      );

      await mergeEngine.applyRemoteOps([op]);

      // Balance should be recalculated from all 3 txns.
      final balances = await (db.select(db.contactBalances)
            ..where((t) => t.contactId.equals('contact-1')))
          .get();

      expect(balances, hasLength(1));
      expect(balances.first.totalDebt, 3000);
      expect(balances.first.totalPayment, 1500); // 1000 + 500
      expect(balances.first.netBalance, -1500); // 1500 - 3000
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // TEST GROUP 6: TIEBREAKER (Owner > Editor > lowest deviceId)
  // ════════════════════════════════════════════════════════════════════

  group('Deterministic tiebreaker', () {
    test('owner role wins over editor at same timestamp', () async {
      final localUpdatedAt = DateTime.utc(2026, 7, 1, 12);
      await seedLedger(name: 'Editor Name', updatedAt: localUpdatedAt);

      // Owner op at the exact same timestamp.
      final op = createOp(
        id: 'op-1',
        entityType: 'ledger',
        entityId: 'ledger-1',
        action: 'UPDATE',
        fieldDeltas: jsonEncode({'name': 'Owner Name'}),
        serverUpdatedAt: localUpdatedAt,
      );

      await mergeEngine.applyRemoteOps([op]);

      final ledger = await (db.select(db.ledgers)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();

      expect(ledger.name, 'Owner Name',
          reason: 'Owner should win over editor at same timestamp');
    });

    test('same role — lower remote deviceId wins', () async {
      final ts = DateTime.utc(2026, 7, 1, 12);
      await seedLedger(name: 'Local Name', updatedAt: ts);

      final engine = MergeEngineLocalDs(
        db,
        localDeviceId: 'device-Z',
      );

      final op = createOp(
        id: 'op-tie',
        entityType: 'ledger',
        entityId: 'ledger-1',
        action: 'UPDATE',
        fieldDeltas: jsonEncode({'name': 'Remote Name'}),
        role: 'editor',
        serverUpdatedAt: ts,
      );

      await engine.applyRemoteOps([op]);

      final ledger = await (db.select(db.ledgers)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();
      expect(ledger.name, 'Remote Name');
    });

    test('same role — higher remote deviceId loses to local', () async {
      final ts = DateTime.utc(2026, 7, 1, 12);
      await seedLedger(name: 'Local Name', updatedAt: ts);

      final engine = MergeEngineLocalDs(
        db,
        localDeviceId: 'device-A',
      );

      final op = createOp(
        id: 'op-tie-2',
        entityType: 'ledger',
        entityId: 'ledger-1',
        action: 'UPDATE',
        fieldDeltas: jsonEncode({'name': 'Remote Name'}),
        deviceId: 'device-Z',
        role: 'editor',
        serverUpdatedAt: ts,
      );

      await engine.applyRemoteOps([op]);

      final ledger = await (db.select(db.ledgers)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();
      expect(ledger.name, 'Local Name');
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // TEST GROUP 7: CONCURRENT CREATE CONFLICT
  // ════════════════════════════════════════════════════════════════════

  group('Concurrent create conflict', () {
    test('two devices create same entity ID — conflict surfaced', () async {
      // Seed the entity locally (simulating local create).
      await seedContact(id: 'contact-X', name: 'Local Contact');

      // Remote also created the same entity.
      final op = createOp(
        id: 'op-1',
        entityType: 'contact',
        entityId: 'contact-X',
        action: 'CREATE',
        fieldDeltas: jsonEncode({
          'name': 'Remote Contact',
          'ledgerId': 'ledger-1',
          'avatarColor': '#FF0000',
        }),
      );

      final result = await mergeEngine.applyRemoteOps([op]);

      expect(result.conflicts, hasLength(1));
      expect(
        result.conflicts.first.conflictType,
        ConflictType.concurrentCreate,
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // TEST GROUP 8: CONTACT MERGE
  // ════════════════════════════════════════════════════════════════════

  group('Contact merge', () {
    test('remote update on non-existent contact surfaces gap conflict', () async {
      await seedLedger();

      final op = createOp(
        id: 'op-1',
        entityType: 'contact',
        entityId: 'new-contact',
        action: 'UPDATE',
        fieldDeltas: jsonEncode({
          'name': 'New Contact',
          'ledgerId': 'ledger-1',
          'avatarColor': '#AA00FF',
          'phone': '+967123456',
        }),
      );

      final result = await mergeEngine.applyRemoteOps([op]);
      expect(result.conflicts, hasLength(1));
      expect(result.conflicts.first.conflictType, ConflictType.ambiguous);

      final contacts = await (db.select(db.contacts)
            ..where((t) => t.id.equals('new-contact')))
          .get();
      expect(contacts, isEmpty, reason: 'Must not invent incomplete rows');
    });
  });

  group('Financial silence bans', () {
    test('divergent duplicate transaction CREATE surfaces conflict', () async {
      await seedLedger();
      await seedContact();
      await seedTransaction();

      final op = createOp(
        id: 'op-dup',
        entityType: 'transaction',
        entityId: 'txn-1',
        action: 'CREATE',
        fieldDeltas: jsonEncode({
          'contactId': 'contact-1',
          'type': 'debt',
          'amount': 9999,
          'currency': 'YER',
        }),
      );

      final result = await mergeEngine.applyRemoteOps([op]);
      expect(result.conflicts, hasLength(1));
      expect(result.conflicts.first.conflictType, ConflictType.ambiguous);

      final txn = await (db.select(db.transactions)
            ..where((t) => t.id.equals('txn-1')))
          .getSingle();
      expect(txn.amount, 1000, reason: 'Original amount must be preserved');
    });

    test('malformed UPDATE is not silently accepted as empty apply', () async {
      await seedLedger(name: 'Keep Me');

      final op = createOp(
        id: 'op-bad',
        entityType: 'ledger',
        entityId: 'ledger-1',
        action: 'UPDATE',
        fieldDeltas: 'not-json',
      );

      final result = await mergeEngine.applyRemoteOps([op]);
      expect(result.conflicts, hasLength(1));

      final ledger = await (db.select(db.ledgers)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();
      expect(ledger.name, 'Keep Me');
    });

    test('archived transactions excluded from merge balance recalc', () async {
      await seedLedger();
      await seedContact();
      await seedTransaction(id: 'txn-live');
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'txn-archived',
          contactId: 'contact-1',
          type: TransactionType.debt,
          amount: 5000,
          currency: 'YER',
          transactionDate: DateTime.utc(2026, 7),
          isArchived: const Value(true),
        ),
      );

      final op = createOp(
        id: 'op-pay',
        entityType: 'transaction',
        entityId: 'txn-pay',
        action: 'CREATE',
        fieldDeltas: jsonEncode({
          'contactId': 'contact-1',
          'type': 'payment',
          'amount': 200,
          'currency': 'YER',
          'transactionDate': '2026-07-01T00:00:00.000Z',
        }),
        opSeq: 2,
      );

      await mergeEngine.applyRemoteOps([op]);

      final balances = await (db.select(db.contactBalances)
            ..where((t) => t.contactId.equals('contact-1')))
          .get();
      expect(balances, hasLength(1));
      expect(balances.first.totalDebt, 1000,
          reason: 'Archived 5000 debt must not count');
      expect(balances.first.totalPayment, 200);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // TEST GROUP 9: EMPTY OPS LIST
  // ════════════════════════════════════════════════════════════════════

  group('Edge cases', () {
    test('empty ops list produces zero applied', () async {
      final result = await mergeEngine.applyRemoteOps([]);
      expect(result.applied, 0);
      expect(result.skipped, 0);
      expect(result.conflicts, isEmpty);
    });

    test('unknown entity type surfaces ambiguous conflict', () async {
      final op = createOp(
        id: 'op-1',
        entityType: 'unknown_type',
        entityId: 'entity-1',
        action: 'CREATE',
        fieldDeltas: jsonEncode({'name': 'Test'}),
      );

      final result = await mergeEngine.applyRemoteOps([op]);
      expect(result.conflicts, hasLength(1));
      expect(result.conflicts.first.conflictType, ConflictType.ambiguous);
    });
  });
}
