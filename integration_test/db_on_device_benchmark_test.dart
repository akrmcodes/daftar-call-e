// Benchmark telemetry prints structured METRIC lines to stdout for CI capture.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/balance_local_ds.dart';
import 'package:daftar/data/datasources/local/contact_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/datasources/local/transaction_local_ds.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/models/balance_model.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/ledger_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/data/repositories/balance_recalculation_service.dart';
import 'package:daftar/data/repositories/bulk_write_service.dart';
import 'package:daftar/data/repositories/contact_search_index_utils.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// ============================================================================
/// DAFTAR PERFORMANCE TELEMETRY — ON-DEVICE DATABASE BENCHMARKS
/// ============================================================================
///
/// This integration test runs on a PHYSICAL device to measure real SQLite
/// performance (including disk I/O, WAL, actual filesystem speed).
///
/// Unlike the in-memory unit test, this captures the true cost of Drift
/// operations on low-end hardware (Samsung A03 target).
///
/// Output format:
///   METRIC: `name`=`value_ms`
///
/// Run with:
///   flutter test integration_test/db_on_device_benchmark_test.dart \
///     -d `DEVICE_ID` --no-pub
/// ============================================================================

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('On-device DB benchmarks', (tester) async {
    // ── Setup: ephemeral on-disk database for realistic I/O ──────────
    final tempRoot = await getTemporaryDirectory();
    final testDir = await Directory(
      p.join(
        tempRoot.path,
        'db_bench_${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);

    final database = db.AppDatabase(
      NativeDatabase.createInBackground(
        File(p.join(testDir.path, 'daftar.sqlite')),
      ),
    );

    // Wait for schema creation to complete
    await database.customSelect('SELECT 1').get();

    print('');
    print('╔══════════════════════════════════════════════════════════╗');
    print('║   DAFTAR ON-DEVICE DATABASE BENCHMARK RESULTS           ║');
    print('╠══════════════════════════════════════════════════════════╣');
    print('');

    try {
      final random = Random(42);

      // ── Helper factories ──────────────────────────────────────────

      LedgerModel makeLedger() {
        final now = DateTime.now().toUtc();
        return LedgerModel(
          id: UuidUtil.generate(),
          name: 'Bench Ledger ${random.nextInt(99999)}',
          type: LedgerType.customers,
          icon: 'ledger',
          color: '#FF1565C0',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        );
      }

      ContactModel makeContact(String ledgerId) {
        final now = DateTime.now().toUtc();
        return ContactModel(
          id: UuidUtil.generate(),
          ledgerId: ledgerId,
          name: _randomArabicName(random),
          phone:
              '+967${random.nextInt(999999999).toString().padLeft(9, '0')}',
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
        TransactionType type = TransactionType.debt,
      }) {
        final now = DateTime.now().toUtc();
        return TransactionModel(
          id: UuidUtil.generate(),
          contactId: contactId,
          type: type,
          amount: random.nextInt(50000) + 100,
          currency: 'YER',
          description: 'Benchmark txn',
          itemName: 'بضاعة',
          transactionDate: now,
          attachmentPath: null,
          createdAt: now,
          updatedAt: now,
        );
      }

      void emit(String name, double ms) {
        final paddedName = name.padRight(55);
        final paddedMs = ms.toStringAsFixed(2).padLeft(10);
        print('METRIC: $paddedName= $paddedMs ms');
      }

      // ── 1. Single Ledger Create ─────────────────────────────────
      {
        final sw = Stopwatch()..start();
        for (var i = 0; i < 20; i++) {
          await database.into(database.ledgers).insert(makeLedger().toDrift());
        }
        sw.stop();
        emit(
          'DEVICE_DB_LEDGER_CREATE_MEAN_20',
          sw.elapsedMilliseconds / 20.0,
        );
      }

      final contactDs = ContactLocalDataSource(database);
      final transactionDs = TransactionLocalDataSource(database);
      final balanceDs = BalanceLocalDataSource(database);
      final auditLogDs = AuditLogLocalDataSource(database);
      final bulkWriteService = BulkWriteService(
        database: database,
        contactLocalDataSource: contactDs,
        transactionLocalDataSource: transactionDs,
        auditLogLocalDataSource: auditLogDs,
        balanceRecalculationService: BalanceRecalculationService(
          database: database,
          balanceLocalDataSource: balanceDs,
        ),
      );

      // ── 2. Bulk Contact Insert + FTS ────────────────────────────
      final benchLedger = makeLedger();
      await database.into(database.ledgers).insert(benchLedger.toDrift());

      for (final count in [50, 200]) {
        final contacts = List.generate(count, (_) => makeContact(benchLedger.id));
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
        emit('DEVICE_DB_BULK_CONTACT_INSERT_$count', sw.elapsedMilliseconds.toDouble());
      }

      // ── 3. Bulk Transaction Insert ──────────────────────────────
      final benchContact = makeContact(benchLedger.id);
      await database.into(database.contacts).insert(benchContact.toDrift());
      await upsertContactSearchIndex(
        database,
        benchContact.id,
        benchContact.name,
      );

      for (final count in [100, 500]) {
        final txns = List.generate(
          count,
          (_) => makeTransaction(
            benchContact.id,
            type: random.nextBool()
                ? TransactionType.debt
                : TransactionType.payment,
          ),
        );
        final sw = Stopwatch()..start();
        await database.transaction(() async {
          for (final txn in txns) {
            await database.into(database.transactions).insert(txn.toDrift());
          }
        });
        sw.stop();
        emit(
          'DEVICE_DB_BULK_TXN_INSERT_$count',
          sw.elapsedMilliseconds.toDouble(),
        );
      }

      // ── 4. FTS5 Arabic Search ───────────────────────────────────
      {
        // Warm the FTS index
        await database
            .customSelect(
              "SELECT * FROM contact_fts WHERE contact_fts MATCH 'محمد*' LIMIT 1",
            )
            .get();

        final sw = Stopwatch()..start();
        for (var i = 0; i < 20; i++) {
          await database
              .customSelect(
                "SELECT * FROM contact_fts WHERE contact_fts MATCH 'محمد*' LIMIT 50",
              )
              .get();
        }
        sw.stop();
        emit(
          'DEVICE_DB_FTS_SEARCH_MEAN_20',
          sw.elapsedMilliseconds / 20.0,
        );
      }

      // ── 5. Transaction List Query (unpaginated) ─────────────────
      {
        final sw = Stopwatch()..start();
        for (var i = 0; i < 20; i++) {
          await (database.select(database.transactions)
                ..where((t) => t.contactId.equals(benchContact.id))
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
        }
        sw.stop();
        emit(
          'DEVICE_DB_TXN_LIST_FULL_MEAN_20',
          sw.elapsedMilliseconds / 20.0,
        );
      }

      // ── 6. Transaction List Query (paginated LIMIT 20) ──────────
      {
        final sw = Stopwatch()..start();
        for (var i = 0; i < 20; i++) {
          await (database.select(database.transactions)
                ..where((t) => t.contactId.equals(benchContact.id))
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
        }
        sw.stop();
        emit(
          'DEVICE_DB_TXN_PAGINATED_20_MEAN_20',
          sw.elapsedMilliseconds / 20.0,
        );
      }

      // ── 7. Cascading Ledger Delete (50 contacts × 10 txns) ──────
      {
        final cascadeLedger = makeLedger();
        await database.into(database.ledgers).insert(cascadeLedger.toDrift());

        final cascadeContactIds = <String>[];
        await database.transaction(() async {
          for (var c = 0; c < 50; c++) {
            final contact = makeContact(cascadeLedger.id);
            cascadeContactIds.add(contact.id);
            await database.into(database.contacts).insert(contact.toDrift());
            await upsertContactSearchIndex(database, contact.id, contact.name);

            for (var t = 0; t < 10; t++) {
              await database.into(database.transactions).insert(
                    makeTransaction(contact.id).toDrift(),
                  );
            }
            await database.into(database.contactBalances).insertOnConflictUpdate(
                  BalanceModel(
                    contactId: contact.id,
                    currencyCode: 'YER',
                    totalDebt: 50000,
                    totalPayment: 25000,
                    netBalance: -25000,
                    lastUpdatedAt: DateTime.now().toUtc(),
                  ).toDrift(),
                );
          }
        });

        final contactDs = ContactLocalDataSource(database);
        final transactionDs = TransactionLocalDataSource(database);
        final now = DateTime.now().toUtc();
        final sw = Stopwatch()..start();
        await database.transaction(() async {
          await (database.update(database.ledgers)
                ..where((t) => t.id.equals(cascadeLedger.id)))
              .write(
            db.LedgersCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(now),
            ),
          );
          await contactDs.bulkSoftDeleteContactsByLedgerId(
            cascadeLedger.id,
            updatedAt: now,
          );
          await bulkRemoveContactSearchIndex(database, cascadeContactIds);
          await transactionDs.bulkSoftDeleteTransactionsByContactIds(
            cascadeContactIds,
            updatedAt: now,
          );
          await (database.delete(database.contactBalances)
                ..where((t) => t.contactId.isIn(cascadeContactIds)))
              .go();
        });
        sw.stop();
        emit(
          'DEVICE_DB_CASCADE_DELETE_50C_500T',
          sw.elapsedMilliseconds.toDouble(),
        );
      }

      // ── 8. WAL Checkpoint ───────────────────────────────────────
      {
        final sw = Stopwatch()..start();
        await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
        sw.stop();
        emit('DEVICE_DB_WAL_CHECKPOINT', sw.elapsedMilliseconds.toDouble());
      }

      print('');
      print('╠══════════════════════════════════════════════════════════╣');
      print('║   ON-DEVICE DB BENCHMARKS COMPLETE                      ║');
      print('╚══════════════════════════════════════════════════════════╝');
      print('');
    } finally {
      await database.close();
      // Clean up temp directory
      if (testDir.existsSync()) {
        await testDir.delete(recursive: true);
      }
    }
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════

String _randomArabicName(Random random) {
  const firstNames = [
    'محمد', 'أحمد', 'عبدالله', 'علي', 'خالد', 'عمر', 'يوسف', 'إبراهيم',
    'سعيد', 'حسن', 'فهد', 'سلطان', 'عبدالرحمن', 'ناصر', 'مصطفى',
  ];
  const lastNames = [
    'الشرعبي', 'المقطري', 'الأحمدي', 'العمري', 'القحطاني',
    'السعدي', 'الزبيدي', 'المالكي', 'الشهراني', 'الحربي',
  ];
  return '${firstNames[random.nextInt(firstNames.length)]} '
      '${lastNames[random.nextInt(lastNames.length)]}';
}
