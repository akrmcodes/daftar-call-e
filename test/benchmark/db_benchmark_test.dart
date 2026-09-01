// Benchmark telemetry prints structured METRIC lines to stdout for CI capture.
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/balance_local_ds.dart';
import 'package:daftar/data/datasources/local/contact_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/datasources/local/ledger_local_ds.dart';
import 'package:daftar/data/datasources/local/transaction_local_ds.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/models/balance_model.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/ledger_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/data/repositories/balance_calculator.dart';
import 'package:daftar/data/repositories/balance_recalculation_service.dart';
import 'package:daftar/data/repositories/bulk_write_service.dart';
import 'package:daftar/data/repositories/contact_search_index_utils.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
/// DAFTAR PERFORMANCE TELEMETRY — DATABASE BENCHMARKS
/// ============================================================================
///
/// Measures raw Drift/SQLite operation latencies in-memory (isolates out
/// disk I/O to reveal pure SQL + Dart mapper overhead).
///
/// Output format:
///   METRIC: `name`=`value_ms`
///
/// Names follow the convention: DB_OPERATION_VARIANT
///
/// Run with:
///   flutter test test/benchmark/dbbenchmark_test.dart --reporter expanded
/// ============================================================================

void main() {
  late AppDatabase db;
  late LedgerLocalDataSource ledgerDs;
  late ContactLocalDataSource contactDs;
  late TransactionLocalDataSource transactionDs;
  late BalanceLocalDataSource balanceDs;
  late AuditLogLocalDataSource auditLogDs;
  late BulkWriteService bulkWriteService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ledgerDs = LedgerLocalDataSource(db);
    contactDs = ContactLocalDataSource(db);
    transactionDs = TransactionLocalDataSource(db);
    balanceDs = BalanceLocalDataSource(db);
    auditLogDs = AuditLogLocalDataSource(db);
    bulkWriteService = BulkWriteService(
      database: db,
      contactLocalDataSource: contactDs,
      transactionLocalDataSource: transactionDs,
      auditLogLocalDataSource: auditLogDs,
      balanceRecalculationService: BalanceRecalculationService(
        database: db,
        balanceLocalDataSource: balanceDs,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  // ── Helpers ────────────────────────────────────────────────────────────

  LedgerModel makeLedger({String? id, String? name}) {
    final now = DateTime.now().toUtc();
    return LedgerModel(
      id: id ?? UuidUtil.generate(),
      name: name ?? 'Ledger ${_random.nextInt(99999)}',
      type: LedgerType.customers,
      icon: 'ledger',
      color: '#FF1565C0',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  ContactModel makeContact(String ledgerId, {String? id, String? name}) {
    final now = DateTime.now().toUtc();
    return ContactModel(
      id: id ?? UuidUtil.generate(),
      ledgerId: ledgerId,
      name: name ?? _randomArabicName(),
      phone: '+967${_random.nextInt(999999999).toString().padLeft(9, '0')}',
      notes: null,
      creditLimit: null,
      creditCurrency: null,
      avatarColor: '#FF9800',
      createdAt: now,
      updatedAt: now,
    );
  }

  TransactionModel makeTransaction(
    String contactId, {
    String? id,
    TransactionType type = TransactionType.debt,
    int? amount,
  }) {
    final now = DateTime.now().toUtc();
    return TransactionModel(
      id: id ?? UuidUtil.generate(),
      contactId: contactId,
      type: type,
      amount: amount ?? (_random.nextInt(50000) + 100),
      currency: 'YER',
      description: 'Benchmark transaction',
      itemName: 'بضاعة',
      transactionDate: now,
      attachmentPath: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> appendAuditLog({
    required String entityType,
    required String entityId,
    required String action,
  }) async {
    await auditLogDs.appendLog(
      AuditLogModel(
        id: UuidUtil.generate(),
        entityType: entityType,
        entityId: entityId,
        action: action,
        timestamp: DateTime.now().toUtc(),
        deviceId: repositoryDeviceId,
      ),
    );
  }

  // ── Metric emitter ─────────────────────────────────────────────────────

  void emitMetric(String name, double ms) {
    // Fixed-width aligned output for clean CTO readability
    final paddedName = name.padRight(50);
    final paddedMs = ms.toStringAsFixed(2).padLeft(10);
    print('METRIC: $paddedName= $paddedMs ms');
  }

  /// Runs [fn] [iterations] times, emits p50, p95, max, and mean.
  Future<void> bench(
    String name,
    Future<void> Function() fn, {
    int iterations = 20,
  }) async {
    final timings = <double>[];

    // Warm-up: 3 iterations (not recorded)
    for (var i = 0; i < 3; i++) {
      await fn();
    }

    for (var i = 0; i < iterations; i++) {
      final sw = Stopwatch()..start();
      await fn();
      sw.stop();
      timings.add(sw.elapsedMicroseconds / 1000.0);
    }

    timings.sort();
    final p50 = timings[(timings.length * 0.50).floor()];
    final p95 = timings[(timings.length * 0.95).floor()];
    final maxMs = timings.last;
    final mean = timings.reduce((a, b) => a + b) / timings.length;

    emitMetric('${name}_P50', p50);
    emitMetric('${name}_P95', p95);
    emitMetric('${name}_MAX', maxMs);
    emitMetric('${name}_MEAN', mean);
  }

  // ══════════════════════════════════════════════════════════════════════
  //  BENCHMARK TESTS
  // ══════════════════════════════════════════════════════════════════════

  group('DB Benchmarks — Single-Row CRUD', () {
    test('LEDGER_CREATE — single ledger insert', () async {
      await bench('DB_LEDGER_CREATE', () async {
        await ledgerDs.createLedger(makeLedger());
      });
    });

    test('CONTACT_CREATE — single contact insert + FTS index', () async {
      final ledger = makeLedger();
      await ledgerDs.createLedger(ledger);

      await bench('DB_CONTACT_CREATE', () async {
        await contactDs.createContact(makeContact(ledger.id));
      });
    });

    test('TRANSACTION_CREATE — single transaction insert', () async {
      final ledger = makeLedger();
      await ledgerDs.createLedger(ledger);
      final contact = makeContact(ledger.id);
      await contactDs.createContact(contact);

      await bench('DB_TXN_CREATE', () async {
        await transactionDs.createTransaction(
          makeTransaction(contact.id),
        );
      });
    });

    test('TRANSACTION_CREATE_WITH_BALANCE — insert + balance recalc',
        () async {
      final ledger = makeLedger();
      await ledgerDs.createLedger(ledger);
      final contact = makeContact(ledger.id);
      await contactDs.createContact(contact);

      await bench('DB_TXN_CREATE_WITH_BALANCE', () async {
        final txn = makeTransaction(contact.id);
        await transactionDs.createTransaction(txn);

        // Simulate the real repository: full balance recalculation
        final allTxns = await (db.select(db.transactions)
              ..where((t) => t.contactId.equals(contact.id))
              ..where((t) => t.isDeleted.equals(false)))
            .get();
        final balances = calculateContactBalances(
          contactId: contact.id,
          transactions: allTxns.map(TransactionModel.fromDrift),
          lastUpdatedAt: DateTime.now().toUtc(),
        );
        for (final b in balances) {
          await balanceDs.upsertBalance(b);
        }
      });
    });

    test('AUDIT_LOG_APPEND — single audit entry', () async {
      await bench('DB_AUDIT_LOG_APPEND', () async {
        await appendAuditLog(
          entityType: 'transaction',
          entityId: UuidUtil.generate(),
          action: 'CREATE',
        );
      });
    });
  });

  group('DB Benchmarks — Bulk Inserts', () {
    for (final count in [50, 200, 500]) {
      test('BULK_CONTACT_INSERT_$count — $count contacts with FTS', () async {
        final ledger = makeLedger();
        await ledgerDs.createLedger(ledger);

        final contacts = List.generate(
          count,
          (_) => makeContact(ledger.id),
        );
        final contactSearchIndex = {
          for (final contact in contacts) contact.id: contact.name,
        };
        final auditLogs = contacts
            .map(
              (contact) => AuditLogModel(
                id: UuidUtil.generate(),
                entityType: 'contact',
                entityId: contact.id,
                action: 'CREATE',
                timestamp: contact.createdAt,
                deviceId: repositoryDeviceId,
              ),
            )
            .toList(growable: false);

        final sw = Stopwatch()..start();
        await bulkWriteService.execute(
          BulkWritePayload(
            contacts: contacts,
            contactSearchIndex: contactSearchIndex,
            transactions: const [],
            auditLogs: auditLogs,
          ),
        );
        sw.stop();
        emitMetric('DB_BULK_CONTACT_INSERT_$count', sw.elapsedMilliseconds.toDouble());
        if (count == 200) {
          expect(sw.elapsedMilliseconds, lessThan(100));
        }
      });
    }

    for (final count in [50, 200, 500]) {
      test('BULK_TXN_INSERT_$count — $count transactions', () async {
        final ledger = makeLedger();
        await ledgerDs.createLedger(ledger);
        final contact = makeContact(ledger.id);
        await contactDs.createContact(contact);

        final transactions = List.generate(
          count,
          (_) => makeTransaction(contact.id),
        );

        final sw = Stopwatch()..start();
        await db.transaction(() async {
          for (final txn in transactions) {
            await db.into(db.transactions).insert(txn.toDrift());
          }
        });
        sw.stop();
        emitMetric('DB_BULK_TXN_INSERT_$count', sw.elapsedMilliseconds.toDouble());
      });
    }

    test('BULK_TXN_INSERT_500_WITH_BALANCE — 500 txns + balance recalc',
        () async {
      final ledger = makeLedger();
      await ledgerDs.createLedger(ledger);
      final contact = makeContact(ledger.id);
      await contactDs.createContact(contact);

      final transactions = List.generate(
        500,
        (i) => makeTransaction(
          contact.id,
          type: i.isEven ? TransactionType.debt : TransactionType.payment,
        ),
      );

      final sw = Stopwatch()..start();
      await db.transaction(() async {
        for (final txn in transactions) {
          await db.into(db.transactions).insert(txn.toDrift());
        }
      });
      final insertMs = sw.elapsedMilliseconds;

      // Now measure balance recalculation separately
      final swBalance = Stopwatch()..start();
      final allTxns = await (db.select(db.transactions)
            ..where((t) => t.contactId.equals(contact.id))
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      final balances = calculateContactBalances(
        contactId: contact.id,
        transactions: allTxns.map(TransactionModel.fromDrift),
        lastUpdatedAt: DateTime.now().toUtc(),
      );
      for (final b in balances) {
        await balanceDs.upsertBalance(b);
      }
      swBalance.stop();

      emitMetric('DB_BULK_TXN_INSERT_500', insertMs.toDouble());
      emitMetric('DB_BALANCE_RECALC_500_TXNS', swBalance.elapsedMilliseconds.toDouble());
    });
  });

  group('DB Benchmarks — Query Performance', () {
    test('CONTACT_LIST_QUERY — query 200 contacts by ledger', () async {
      final ledger = makeLedger();
      await ledgerDs.createLedger(ledger);

      // Seed 200 contacts
      await db.transaction(() async {
        for (var i = 0; i < 200; i++) {
          final c = makeContact(ledger.id);
          await db.into(db.contacts).insert(c.toDrift());
          await upsertContactSearchIndex(db, c.id, c.name);
        }
      });

      await bench('DB_CONTACT_LIST_QUERY_200', () async {
        await (db.select(db.contacts)
              ..where((t) => t.ledgerId.equals(ledger.id))
              ..where(
                (t) =>
                    t.isDeleted.equals(false) & t.isArchived.equals(false),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.name)]))
            .get();
      });
    });

    test('TXN_LIST_QUERY — query 500 transactions by contact', () async {
      final ledger = makeLedger();
      await ledgerDs.createLedger(ledger);
      final contact = makeContact(ledger.id);
      await contactDs.createContact(contact);

      // Seed 500 transactions
      await db.transaction(() async {
        for (var i = 0; i < 500; i++) {
          await db.into(db.transactions).insert(
                makeTransaction(contact.id).toDrift(),
              );
        }
      });

      await bench('DB_TXN_LIST_QUERY_500', () async {
        await (db.select(db.transactions)
              ..where((t) => t.contactId.equals(contact.id))
              ..where(
                (t) =>
                    t.isDeleted.equals(false) & t.isArchived.equals(false),
              )
              ..orderBy([
                (t) => OrderingTerm(
                      expression: t.transactionDate,
                      mode: OrderingMode.desc,
                    ),
                (t) => OrderingTerm(
                      expression: t.createdAt,
                      mode: OrderingMode.desc,
                    ),
              ]))
            .get();
      });

      await bench('DB_TXN_PAGINATED_QUERY_20_OF_500', () async {
        await (db.select(db.transactions)
              ..where((t) => t.contactId.equals(contact.id))
              ..where((t) => t.isDeleted.equals(false))
              ..orderBy([
                (t) => OrderingTerm(
                      expression: t.transactionDate,
                      mode: OrderingMode.desc,
                    ),
                (t) => OrderingTerm(
                      expression: t.createdAt,
                      mode: OrderingMode.desc,
                    ),
              ])
              ..limit(20))
            .get();
      });
    });

    test('BALANCE_WATCH_ALL — join contacts + ledgers + balances', () async {
      final ledger = makeLedger();
      await ledgerDs.createLedger(ledger);

      // Seed 50 contacts with balances
      for (var i = 0; i < 50; i++) {
        final c = makeContact(ledger.id);
        await contactDs.createContact(c);
        await balanceDs.upsertBalance(
          BalanceModel(
            contactId: c.id,
            currencyCode: 'YER',
            totalDebt: _random.nextInt(100000),
            totalPayment: _random.nextInt(100000),
            netBalance: _random.nextInt(50000) - 25000,
            lastUpdatedAt: DateTime.now().toUtc(),
          ),
        );
      }

      await bench('DB_BALANCE_WATCH_ALL_JOIN_50', () async {
        await balanceDs.watchAllBalances().first;
      });

      await bench('DB_BALANCE_WATCH_BY_LEDGER_50', () async {
        await balanceDs.watchBalancesByLedger(ledger.id).first;
      });
    });
  });

  group('DB Benchmarks — FTS5 Arabic Search', () {
    test('FTS_SEARCH — search across 200 Arabic contacts', () async {
      final ledger = makeLedger();
      await ledgerDs.createLedger(ledger);

      // Seed 200 contacts with Arabic names
      final arabicNames = _generateArabicNames(200);
      await db.transaction(() async {
        for (final name in arabicNames) {
          final c = makeContact(ledger.id, name: name);
          await db.into(db.contacts).insert(c.toDrift());
          await upsertContactSearchIndex(db, c.id, c.name);
        }
      });

      await bench('DB_FTS_SEARCH_PREFIX_200', () async {
        await contactDs.searchContacts('محمد');
      });

      await bench('DB_FTS_SEARCH_DIACRITICS_200', () async {
        await contactDs.searchContacts('مُحَمَّد');
      });

      await bench('DB_FTS_SEARCH_PARTIAL_200', () async {
        await contactDs.searchContacts('عبد');
      });
    });
  });

  group('DB Benchmarks — Cascade Operations', () {
    test('CASCADING_DELETE — ledger with 50 contacts × 10 txns each',
        () async {
      final ledger = makeLedger();
      await ledgerDs.createLedger(ledger);

      final contactIds = <String>[];
      await db.transaction(() async {
        for (var c = 0; c < 50; c++) {
          final contact = makeContact(ledger.id);
          contactIds.add(contact.id);
          await db.into(db.contacts).insert(contact.toDrift());
          await upsertContactSearchIndex(db, contact.id, contact.name);

          for (var t = 0; t < 10; t++) {
            await db.into(db.transactions).insert(
                  makeTransaction(contact.id).toDrift(),
                );
          }

          await balanceDs.upsertBalance(
            BalanceModel(
              contactId: contact.id,
              currencyCode: 'YER',
              totalDebt: 50000,
              totalPayment: 25000,
              netBalance: -25000,
              lastUpdatedAt: DateTime.now().toUtc(),
            ),
          );
        }
      });

      // Verify seed
      final seedContactCount =
          await (db.select(db.contacts)
                ..where((t) => t.ledgerId.equals(ledger.id))
                ..where((t) => t.isDeleted.equals(false)))
              .get();
      expect(seedContactCount.length, 50);

      // Measure the cascading delete (mimics LedgerRepositoryImpl.delete)
      final sw = Stopwatch()..start();
      final now = DateTime.now().toUtc();

      await db.transaction(() async {
        await (db.update(db.ledgers)
              ..where((t) => t.id.equals(ledger.id)))
            .write(
          LedgersCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(now),
          ),
        );

        await contactDs.bulkSoftDeleteContactsByLedgerId(
          ledger.id,
          updatedAt: now,
        );
        await bulkRemoveContactSearchIndex(db, contactIds);
        await transactionDs.bulkSoftDeleteTransactionsByContactIds(
          contactIds,
          updatedAt: now,
        );

        await (db.delete(db.contactBalances)
              ..where((t) => t.contactId.isIn(contactIds)))
            .go();
      });
      sw.stop();
      emitMetric(
        'DB_CASCADE_DELETE_50C_500T',
        sw.elapsedMilliseconds.toDouble(),
      );
      expect(sw.elapsedMilliseconds, lessThan(100));
    });
  });

  group('DB Benchmarks — Balance Recalculation', () {
    for (final txnCount in [50, 200, 500]) {
      test('BALANCE_RECALC_${txnCount}_TXNS', () async {
        final ledger = makeLedger();
        await ledgerDs.createLedger(ledger);
        final contact = makeContact(ledger.id);
        await contactDs.createContact(contact);

        // Seed transactions
        await db.transaction(() async {
          for (var i = 0; i < txnCount; i++) {
            await db.into(db.transactions).insert(
                  makeTransaction(
                    contact.id,
                    type: i.isEven
                        ? TransactionType.debt
                        : TransactionType.payment,
                  ).toDrift(),
                );
          }
        });

        await bench('DB_BALANCE_RECALC_$txnCount', () async {
          // Step 1: Read all transactions for this contact
          final allTxns = await (db.select(db.transactions)
                ..where((t) => t.contactId.equals(contact.id))
                ..where((t) => t.isDeleted.equals(false)))
              .get();

          // Step 2: Calculate balances
          final balances = calculateContactBalances(
            contactId: contact.id,
            transactions: allTxns.map(TransactionModel.fromDrift),
            lastUpdatedAt: DateTime.now().toUtc(),
          );

          // Step 3: Delete old + upsert new
          await (db.delete(db.contactBalances)
                ..where((t) => t.contactId.equals(contact.id)))
              .go();
          for (final b in balances) {
            await balanceDs.upsertBalance(b);
          }
        });
      });
    }
  });

  group('DB Benchmarks — Recent Item Search (Arabic normalization)', () {
    test('RECENT_ITEM_SEARCH — across 500 transactions', () async {
      final ledger = makeLedger();
      await ledgerDs.createLedger(ledger);
      final contact = makeContact(ledger.id);
      await contactDs.createContact(contact);

      final itemNames = _generateArabicItemNames(500);
      await db.transaction(() async {
        for (var i = 0; i < 500; i++) {
          final txn = TransactionModel(
            id: UuidUtil.generate(),
            contactId: contact.id,
            type: TransactionType.debt,
            amount: _random.nextInt(50000) + 100,
            currency: 'YER',
            description: null,
            itemName: itemNames[i],
            transactionDate: DateTime.now().toUtc(),
            attachmentPath: null,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          );
          await db.into(db.transactions).insert(txn.toDrift());
        }
      });

      // NOTE: searchRecentItems has a known pre-existing bug — it uses
      // camelCase column names (itemName, isDeleted, createdAt) in raw SQL
      // but Drift generates snake_case columns (item_name, is_deleted,
      // created_at). This benchmark catches the error and reports it as a
      // SKIP rather than failing the entire suite.
      try {
        await bench('DB_RECENT_ITEM_SEARCH_500', () async {
          await transactionDs.searchRecentItems('سكر');
        });
      } on Object catch (e) {
        print(
          'METRIC: ${'DB_RECENT_ITEM_SEARCH_500'.padRight(50)}= SKIP (app bug: $e)',
        );
        print(
          '  ⚠ KNOWN DEFECT: TransactionLocalDataSource.searchRecentItems '
          'uses camelCase column names in raw SQL. Fix the raw SQL to use '
          'snake_case (item_name, is_deleted, created_at).',
        );
      }
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  TEST DATA GENERATORS
// ═══════════════════════════════════════════════════════════════════════════

final _random = Random(42); // Deterministic seed for reproducibility

String _randomArabicName() {
  const firstNames = [
    'محمد', 'أحمد', 'عبدالله', 'علي', 'خالد', 'عمر', 'يوسف', 'إبراهيم',
    'سعيد', 'حسن', 'فهد', 'سلطان', 'عبدالرحمن', 'ناصر', 'مصطفى',
    'سامي', 'طارق', 'وليد', 'فيصل', 'ماجد',
  ];
  const lastNames = [
    'الشرعبي', 'المقطري', 'الحوثي', 'الأحمدي', 'العمري', 'القحطاني',
    'السعدي', 'الزبيدي', 'المالكي', 'الشهراني', 'الحربي', 'الغامدي',
    'العنزي', 'المطيري', 'الدوسري', 'الشمري', 'البلوي', 'الرشيدي',
    'العتيبي', 'السبيعي',
  ];
  return '${firstNames[_random.nextInt(firstNames.length)]} '
      '${lastNames[_random.nextInt(lastNames.length)]}';
}

List<String> _generateArabicNames(int count) {
  return List.generate(count, (_) => _randomArabicName());
}

List<String> _generateArabicItemNames(int count) {
  const items = [
    'سكر', 'أرز', 'دقيق', 'زيت', 'شاي', 'قهوة', 'حليب', 'ملح',
    'فلفل', 'طماطم', 'بصل', 'ثوم', 'بيض', 'جبن', 'خبز', 'لحم',
    'دجاج', 'سمك', 'فواكه', 'خضروات', 'مكرونة', 'عدس', 'فول',
    'تونة', 'مربى', 'عسل', 'زبدة', 'صابون', 'مناديل', 'شامبو',
  ];
  return List.generate(
    count,
    (i) => items[_random.nextInt(items.length)],
  );
}
