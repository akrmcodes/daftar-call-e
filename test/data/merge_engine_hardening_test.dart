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

/// Stage 8 merge-engine hardening coverage.
///
/// Everything here protects a financial invariant that the original suite did
/// not exercise: replay convergence, cascade parity with the local delete
/// path, per-currency balance rebuild, and hostile payload containment.
void main() {
  const ts0 = 10;
  const ts1 = 11;
  const ts2 = 12;

  DateTime at(int hour) => DateTime.utc(2026, 7, 1, hour);

  SyncOperationModel op({
    required String id,
    required String entityType,
    required String entityId,
    required String action,
    Object? fieldDeltas,
    String deviceId = 'device-A',
    String role = 'owner',
    int opSeq = 1,
    int hour = ts2,
  }) {
    return SyncOperationModel(
      id: id,
      entityType: entityType,
      entityId: entityId,
      action: action,
      fieldDeltas: fieldDeltas == null
          ? null
          : fieldDeltas is String
              ? fieldDeltas
              : jsonEncode(fieldDeltas),
      deviceId: deviceId,
      role: role,
      localTimestamp: at(ts0),
      serverUpdatedAt: at(hour),
      opSeq: opSeq,
    );
  }

  Future<void> seedLedger(
    AppDatabase db, {
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
            updatedAt: Value(updatedAt ?? at(ts0)),
          ),
        );
  }

  Future<void> seedContact(
    AppDatabase db, {
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
            updatedAt: Value(updatedAt ?? at(ts0)),
          ),
        );
  }

  Future<void> seedTransaction(
    AppDatabase db, {
    required String id,
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
            transactionDate: at(ts0),
            isDeleted: Value(isDeleted),
            updatedAt: Value(updatedAt ?? at(ts0)),
          ),
        );
  }

  late AppDatabase db;
  late MergeEngineLocalDs sut;

  setUpAll(() {
    // Convergence tests deliberately open a second in-memory executor to
    // stand in for another device.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    sut = MergeEngineLocalDs(db, localDeviceId: 'device-local');
  });

  tearDown(() async {
    await db.close();
  });

  // ══════════════════════════════════════════════════════════════════════
  // CONVERGENCE — two devices must reach identical state
  // ══════════════════════════════════════════════════════════════════════

  group('Replay convergence', () {
    /// Two ops carrying the same server timestamp from different authors.
    /// The tiebreak must depend only on the op log, never on which device
    /// happens to be merging.
    List<SyncOperationModel> tiedNameOps() => [
          op(
            id: 'op-1',
            entityType: 'ledger',
            entityId: 'ledger-1',
            action: 'UPDATE',
            fieldDeltas: {'name': 'From AAA'},
            deviceId: 'device-aaa',
            role: 'editor',
            hour: ts1,
          ),
          op(
            id: 'op-2',
            entityType: 'ledger',
            entityId: 'ledger-1',
            action: 'UPDATE',
            fieldDeltas: {'name': 'From ZZZ'},
            deviceId: 'device-zzz',
            role: 'editor',
            opSeq: 2,
            hour: ts1,
          ),
        ];

    Future<String> replayOn(String localDeviceId) async {
      final scratch = AppDatabase(NativeDatabase.memory());
      addTearDown(scratch.close);
      await seedLedger(scratch, name: 'Seed');
      final engine = MergeEngineLocalDs(scratch, localDeviceId: localDeviceId);
      await engine.applyRemoteOps(tiedNameOps());
      final row = await (scratch.select(scratch.ledgers)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();
      return row.name;
    }

    test('devices on both sides of the tiebreak converge to one name',
        () async {
      // 'device-000' sorts below both authors, 'device-zzzz' above both.
      // Comparing the incoming op against the merging device would split
      // these two into different final states.
      final low = await replayOn('device-000');
      final high = await replayOn('device-zzzz');
      final middle = await replayOn('device-mmm');

      expect(low, high);
      expect(low, middle);
      expect(
        low,
        'From AAA',
        reason: 'Lowest authoring deviceId owns the field on a timestamp tie',
      );
    });

    test('pull order does not change the merged result', () async {
      await seedLedger(db, name: 'Seed');
      final forward = tiedNameOps();
      await sut.applyRemoteOps(forward);
      final inOrder = await (db.select(db.ledgers)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();

      final scratch = AppDatabase(NativeDatabase.memory());
      addTearDown(scratch.close);
      await seedLedger(scratch, name: 'Seed');
      final engine = MergeEngineLocalDs(scratch, localDeviceId: 'device-local');
      await engine.applyRemoteOps(forward.reversed.toList());
      final reversed = await (scratch.select(scratch.ledgers)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();

      expect(reversed.name, inOrder.name);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // ACTION COVERAGE — every action the local repositories emit
  // ══════════════════════════════════════════════════════════════════════

  group('Local audit actions the push path emits', () {
    test('RESTORE revives a deleted transaction and its balance', () async {
      await seedLedger(db);
      await seedContact(db);
      await seedTransaction(
        db,
        id: 'txn-1',
        amount: 4000,
        isDeleted: true,
        updatedAt: at(ts1),
      );

      final result = await sut.applyRemoteOps([
        op(
          id: 'op-restore',
          entityType: 'transaction',
          entityId: 'txn-1',
          action: 'RESTORE',
          fieldDeltas: {'id': 'txn-1', 'contactId': 'contact-1'},
        ),
      ]);

      expect(
        result.conflicts,
        isEmpty,
        reason: 'RESTORE is a first-class action, not an unknown one',
      );

      final txn = await (db.select(db.transactions)
            ..where((t) => t.id.equals('txn-1')))
          .getSingle();
      expect(txn.isDeleted, false);

      final balances = await (db.select(db.contactBalances)
            ..where((t) => t.contactId.equals('contact-1')))
          .get();
      expect(balances.single.totalDebt, 4000);
    });

    test('ACTIVATE_ARCHIVED promotes an archived transaction', () async {
      await seedLedger(db);
      await seedContact(db);
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'txn-archived',
              contactId: 'contact-1',
              type: TransactionType.debt,
              amount: 700,
              currency: 'YER',
              transactionDate: at(ts0),
              isArchived: const Value(true),
            ),
          );

      final result = await sut.applyRemoteOps([
        op(
          id: 'op-activate',
          entityType: 'transaction',
          entityId: 'txn-archived',
          action: 'ACTIVATE_ARCHIVED',
          fieldDeltas: {'id': 'txn-archived'},
        ),
      ]);

      expect(result.conflicts, isEmpty);
      final balances = await (db.select(db.contactBalances)
            ..where((t) => t.contactId.equals('contact-1')))
          .get();
      expect(balances.single.totalDebt, 700);
    });

    test('USER_ARCHIVE and CARRY_FORWARD do not raise conflicts', () async {
      await seedLedger(db);

      final result = await sut.applyRemoteOps([
        op(
          id: 'op-archive',
          entityType: 'ledger',
          entityId: 'ledger-1',
          action: 'USER_ARCHIVE',
          fieldDeltas: {'id': 'ledger-1'},
        ),
        op(
          id: 'op-carry',
          entityType: 'ledger',
          entityId: 'ledger-1',
          action: 'CARRY_FORWARD',
          fieldDeltas: {'operationId': 'ceremony-1'},
          opSeq: 2,
        ),
      ]);

      expect(result.conflicts, isEmpty);
      final ledger = await (db.select(db.ledgers)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();
      expect(ledger.isUserArchived, true);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CASCADES — remote deletes must match local delete semantics
  // ══════════════════════════════════════════════════════════════════════

  group('Delete cascades', () {
    test('contact DELETE also tombstones its transactions', () async {
      await seedLedger(db);
      await seedContact(db);
      await seedTransaction(db, id: 'txn-1', amount: 2500);

      await sut.applyRemoteOps([
        op(
          id: 'op-del-contact',
          entityType: 'contact',
          entityId: 'contact-1',
          action: 'DELETE',
          fieldDeltas: {'id': 'contact-1', 'deletedTransactionCount': 1},
        ),
      ]);

      final txn = await (db.select(db.transactions)
            ..where((t) => t.id.equals('txn-1')))
          .getSingle();
      expect(
        txn.isDeleted,
        true,
        reason: 'The originating device cascaded without emitting child ops',
      );

      final balances = await (db.select(db.contactBalances)
            ..where((t) => t.contactId.equals('contact-1')))
          .get();
      expect(balances, isEmpty, reason: 'A deleted contact owes nothing');
    });

    test('ledger DELETE cascades to contacts and transactions', () async {
      await seedLedger(db);
      await seedContact(db);
      await seedTransaction(db, id: 'txn-1', amount: 900);

      await sut.applyRemoteOps([
        op(
          id: 'op-del-ledger',
          entityType: 'ledger',
          entityId: 'ledger-1',
          action: 'DELETE',
          fieldDeltas: {'id': 'ledger-1'},
        ),
      ]);

      final contact = await (db.select(db.contacts)
            ..where((t) => t.id.equals('contact-1')))
          .getSingle();
      final txn = await (db.select(db.transactions)
            ..where((t) => t.id.equals('txn-1')))
          .getSingle();

      expect(contact.isDeleted, true);
      expect(txn.isDeleted, true);
    });

    test('contact RESTORE brings back exactly the cascaded transactions',
        () async {
      await seedLedger(db);
      await seedContact(db);
      await seedTransaction(db, id: 'txn-cascaded', amount: 1200);
      await seedTransaction(
        db,
        id: 'txn-deleted-earlier',
        amount: 300,
        isDeleted: true,
        updatedAt: at(ts0),
      );

      await sut.applyRemoteOps([
        op(
          id: 'op-del',
          entityType: 'contact',
          entityId: 'contact-1',
          action: 'DELETE',
          fieldDeltas: {'id': 'contact-1'},
          hour: ts1,
        ),
        op(
          id: 'op-restore',
          entityType: 'contact',
          entityId: 'contact-1',
          action: 'RESTORE',
          fieldDeltas: {'id': 'contact-1'},
          opSeq: 2,
        ),
      ]);

      final cascaded = await (db.select(db.transactions)
            ..where((t) => t.id.equals('txn-cascaded')))
          .getSingle();
      final earlier = await (db.select(db.transactions)
            ..where((t) => t.id.equals('txn-deleted-earlier')))
          .getSingle();

      expect(cascaded.isDeleted, false);
      expect(
        earlier.isDeleted,
        true,
        reason: 'A transaction deleted on its own must stay deleted',
      );

      final balances = await (db.select(db.contactBalances)
            ..where((t) => t.contactId.equals('contact-1')))
          .get();
      expect(balances.single.totalDebt, 1200);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // BALANCES — per-currency rebuild from the surviving set
  // ══════════════════════════════════════════════════════════════════════

  group('Multi-currency balance recalculation', () {
    test('every currency present for a contact gets its own row', () async {
      await seedLedger(db);
      await seedContact(db);
      await seedTransaction(db, id: 'txn-yer', amount: 5000);
      await seedTransaction(
        db,
        id: 'txn-sar',
        amount: 1200,
        currency: 'SAR',
      );

      await sut.applyRemoteOps([
        op(
          id: 'op-usd',
          entityType: 'transaction',
          entityId: 'txn-usd',
          action: 'CREATE',
          fieldDeltas: {
            'contactId': 'contact-1',
            'type': 'payment',
            'amount': 750,
            'currency': 'USD',
            'transactionDate': '2026-07-01T00:00:00.000Z',
          },
        ),
      ]);

      final balances = await (db.select(db.contactBalances)
            ..where((t) => t.contactId.equals('contact-1')))
          .get();
      final byCurrency = {for (final b in balances) b.currencyCode: b};

      expect(byCurrency.keys, containsAll(['YER', 'SAR', 'USD']));
      expect(byCurrency['YER']!.netBalance, -5000);
      expect(byCurrency['SAR']!.netBalance, -1200);
      expect(byCurrency['USD']!.netBalance, 750);
    });

    test('deleting the last transaction in a currency drops its balance row',
        () async {
      await seedLedger(db);
      await seedContact(db);
      await seedTransaction(db, id: 'txn-yer', amount: 5000);
      await seedTransaction(
        db,
        id: 'txn-sar-only',
        amount: 800,
        currency: 'SAR',
      );

      await sut.applyRemoteOps([
        op(
          id: 'op-del-sar',
          entityType: 'transaction',
          entityId: 'txn-sar-only',
          action: 'DELETE',
          fieldDeltas: {'id': 'txn-sar-only', 'contactId': 'contact-1'},
        ),
      ]);

      final balances = await (db.select(db.contactBalances)
            ..where((t) => t.contactId.equals('contact-1')))
          .get();

      expect(balances.map((b) => b.currencyCode), ['YER']);
      expect(
        balances.single.netBalance,
        -5000,
        reason: 'A stale SAR row would show debt the merchant does not owe',
      );
    });

    test('a transaction type flip is merged, not dropped', () async {
      await seedLedger(db);
      await seedContact(db);
      await seedTransaction(db, id: 'txn-1', amount: 3000);

      await sut.applyRemoteOps([
        op(
          id: 'op-flip',
          entityType: 'transaction',
          entityId: 'txn-1',
          action: 'UPDATE',
          fieldDeltas: {
            'type': 'payment',
            'amount': 3000,
            'currency': 'YER',
          },
        ),
      ]);

      final balances = await (db.select(db.contactBalances)
            ..where((t) => t.contactId.equals('contact-1')))
          .get();
      expect(
        balances.single.netBalance,
        3000,
        reason: 'Dropping the type would leave this device 6000 out of step',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // HOSTILE PAYLOADS — a bad op must never wedge the batch
  // ══════════════════════════════════════════════════════════════════════

  group('Hostile and malformed payloads', () {
    test('a wrongly typed amount cannot roll back the surrounding batch',
        () async {
      await seedLedger(db);
      await seedContact(db);

      final result = await sut.applyRemoteOps([
        op(
          id: 'op-good-1',
          entityType: 'transaction',
          entityId: 'txn-good-1',
          action: 'CREATE',
          fieldDeltas: {
            'contactId': 'contact-1',
            'type': 'debt',
            'amount': 1000,
            'currency': 'YER',
          },
        ),
        op(
          id: 'op-poison',
          entityType: 'transaction',
          entityId: 'txn-poison',
          action: 'CREATE',
          fieldDeltas: {
            'contactId': 'contact-1',
            'type': 'debt',
            'amount': '9000',
            'currency': 'YER',
          },
          opSeq: 2,
        ),
        op(
          id: 'op-good-2',
          entityType: 'transaction',
          entityId: 'txn-good-2',
          action: 'CREATE',
          fieldDeltas: {
            'contactId': 'contact-1',
            'type': 'payment',
            'amount': 400,
            'currency': 'YER',
          },
          opSeq: 3,
        ),
      ]);

      expect(result.conflicts, hasLength(1));
      expect(result.conflicts.single.conflictType, ConflictType.ambiguous);

      final ids = (await db.select(db.transactions).get())
          .map((t) => t.id)
          .toSet();
      expect(ids, {'txn-good-1', 'txn-good-2'});

      final balances = await (db.select(db.contactBalances)
            ..where((t) => t.contactId.equals('contact-1')))
          .get();
      expect(balances.single.netBalance, -600);
    });

    test('a rejected op is recorded so the next pull does not re-detect it',
        () async {
      await seedLedger(db);
      await seedContact(db);

      final poison = op(
        id: 'op-poison',
        entityType: 'transaction',
        entityId: 'txn-poison',
        action: 'CREATE',
        fieldDeltas: {
          'contactId': 'contact-1',
          'type': 'debt',
          'amount': -50,
          'currency': 'YER',
        },
      );

      final first = await sut.applyRemoteOps([poison]);
      final second = await sut.applyRemoteOps([poison]);

      expect(first.conflicts, hasLength(1));
      expect(
        second.conflicts,
        isEmpty,
        reason: 'Replays must not grow the conflict table without bound',
      );
      expect(await sut.getUnresolvedConflictCount(), 1);
    });

    test('a transaction CREATE without contactId is refused', () async {
      await seedLedger(db);
      await seedContact(db);

      final result = await sut.applyRemoteOps([
        op(
          id: 'op-orphan',
          entityType: 'transaction',
          entityId: 'txn-orphan',
          action: 'CREATE',
          fieldDeltas: {
            'type': 'debt',
            'amount': 100,
            'currency': 'YER',
          },
        ),
      ]);

      expect(result.conflicts, hasLength(1));
      expect(await db.select(db.transactions).get(), isEmpty);
    });

    test('an unknown transaction type is refused, not coerced to debt',
        () async {
      await seedLedger(db);
      await seedContact(db);

      final result = await sut.applyRemoteOps([
        op(
          id: 'op-bad-type',
          entityType: 'transaction',
          entityId: 'txn-bad-type',
          action: 'CREATE',
          fieldDeltas: {
            'contactId': 'contact-1',
            'type': 'refund',
            'amount': 100,
            'currency': 'YER',
          },
        ),
      ]);

      expect(result.conflicts, hasLength(1));
      expect(await db.select(db.transactions).get(), isEmpty);
    });

    test('a negative amount never reaches an existing transaction', () async {
      await seedLedger(db);
      await seedContact(db);
      await seedTransaction(db, id: 'txn-1');

      await sut.applyRemoteOps([
        op(
          id: 'op-negative',
          entityType: 'transaction',
          entityId: 'txn-1',
          action: 'UPDATE',
          fieldDeltas: {'amount': -1},
        ),
      ]);

      final txn = await (db.select(db.transactions)
            ..where((t) => t.id.equals('txn-1')))
          .getSingle();
      expect(txn.amount, 1000);
    });

    test('a JSON array payload is rejected without throwing', () async {
      await seedLedger(db);

      final result = await sut.applyRemoteOps([
        op(
          id: 'op-array',
          entityType: 'ledger',
          entityId: 'ledger-1',
          action: 'UPDATE',
          fieldDeltas: '[1,2,3]',
        ),
      ]);

      expect(result.conflicts, hasLength(1));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // IDEMPOTENCY
  // ══════════════════════════════════════════════════════════════════════

  group('Idempotency', () {
    test('a replayed op whose entityId drifted is still a duplicate',
        () async {
      await seedLedger(db);
      await seedLedger(db, id: 'ledger-2', name: 'Second');

      final original = op(
        id: 'op-shared',
        entityType: 'ledger',
        entityId: 'ledger-1',
        action: 'UPDATE',
        fieldDeltas: {'name': 'First Applied'},
      );
      await sut.applyRemoteOps([original]);

      final replay = op(
        id: 'op-shared',
        entityType: 'ledger',
        entityId: 'ledger-2',
        action: 'UPDATE',
        fieldDeltas: {'name': 'Should Not Apply'},
      );
      final result = await sut.applyRemoteOps([replay]);

      expect(result.applied, 0);
      expect(result.skipped, 1);
      final second = await (db.select(db.ledgers)
            ..where((t) => t.id.equals('ledger-2')))
          .getSingle();
      expect(second.name, 'Second');
    });

    test('a CREATE echoed back from this device is not a concurrent create',
        () async {
      await seedLedger(db);
      await seedContact(db, id: 'contact-mine', name: 'Mine');

      final result = await sut.applyRemoteOps([
        op(
          id: 'op-echo',
          entityType: 'contact',
          entityId: 'contact-mine',
          action: 'CREATE',
          fieldDeltas: {
            'ledgerId': 'ledger-1',
            'name': 'Mine',
            'avatarColor': '#6E6E76',
          },
          deviceId: 'device-local',
        ),
      ]);

      expect(
        result.conflicts,
        isEmpty,
        reason: 'Our own op coming back must not look like another device',
      );
    });
  });
}
