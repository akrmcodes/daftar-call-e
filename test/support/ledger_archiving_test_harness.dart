import 'dart:async';

import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/balance_local_ds.dart';
import 'package:daftar/data/datasources/local/contact_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' hide Contact, Ledger;
import 'package:daftar/data/datasources/local/ledger_local_ds.dart';
import 'package:daftar/data/datasources/local/transaction_local_ds.dart';
import 'package:daftar/data/repositories/balance_recalculation_service.dart';
import 'package:daftar/data/repositories/balance_repository_impl.dart';
import 'package:daftar/data/repositories/bulk_write_repository_impl.dart';
import 'package:daftar/data/repositories/bulk_write_service.dart';
import 'package:daftar/data/repositories/contact_repository_impl.dart';
import 'package:daftar/data/repositories/ledger_repository_impl.dart';
import 'package:daftar/data/repositories/transaction_repository_impl.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/bulk_write_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

class LedgerArchivingTestHarness {
  LedgerArchivingTestHarness({CarryForwardTestFaults? carryForwardTestFaults}) {
    DeviceIdentity.initializeForTest('test-device-id');
    database = AppDatabase(NativeDatabase.memory());
    final ledgerLocalDataSource = LedgerLocalDataSource(database);
    final contactLocalDataSource = ContactLocalDataSource(database);
    final transactionLocalDataSource = TransactionLocalDataSource(database);
    balanceLocalDataSource = BalanceLocalDataSource(database);
    final auditLogLocalDataSource = AuditLogLocalDataSource(database);

    ledgerRepository = LedgerRepositoryImpl(
      ledgerLocalDataSource: ledgerLocalDataSource,
      contactLocalDataSource: contactLocalDataSource,
      transactionLocalDataSource: transactionLocalDataSource,
      balanceLocalDataSource: balanceLocalDataSource,
      auditLogLocalDataSource: auditLogLocalDataSource,
      carryForwardTestFaults: carryForwardTestFaults,
    );
    contactRepository = ContactRepositoryImpl(
      contactLocalDataSource: contactLocalDataSource,
      transactionLocalDataSource: transactionLocalDataSource,
      balanceLocalDataSource: balanceLocalDataSource,
      auditLogLocalDataSource: auditLogLocalDataSource,
    );
    transactionRepository = TransactionRepositoryImpl(
      transactionLocalDataSource: transactionLocalDataSource,
      balanceLocalDataSource: balanceLocalDataSource,
      auditLogLocalDataSource: auditLogLocalDataSource,
    );
    balanceRepository = BalanceRepositoryImpl(
      balanceLocalDataSource: balanceLocalDataSource,
      transactionLocalDataSource: transactionLocalDataSource,
    );
    bulkWriteRepository = BulkWriteRepositoryImpl(
      bulkWriteService: BulkWriteService(
        database: database,
        contactLocalDataSource: contactLocalDataSource,
        transactionLocalDataSource: transactionLocalDataSource,
        auditLogLocalDataSource: auditLogLocalDataSource,
        balanceRecalculationService: BalanceRecalculationService(
          database: database,
          balanceLocalDataSource: balanceLocalDataSource,
        ),
      ),
    );
  }

  late final AppDatabase database;
  late final BalanceLocalDataSource balanceLocalDataSource;
  late final LedgerRepositoryImpl ledgerRepository;
  late final ContactRepositoryImpl contactRepository;
  late final TransactionRepositoryImpl transactionRepository;
  late final BalanceRepositoryImpl balanceRepository;
  late final BulkWriteRepository bulkWriteRepository;

  Future<void> close() => database.close();

  Future<Ledger> seedLedger({
    String name = 'دفتر اختبار',
    LedgerType type = LedgerType.custom,
    String icon = 'store',
    String color = '#1565C0',
  }) async {
    return expectRight(
      ledgerRepository.create(
        CreateLedgerParams(
          name: name,
          type: type,
          icon: icon,
          color: color,
        ),
      ),
    );
  }

  Future<Contact> seedContact({
    required String ledgerId,
    required String name,
    String avatarColor = '#FF9800',
    String? phone,
  }) async {
    return expectRight(
      contactRepository.create(
        CreateContactParams(
          ledgerId: ledgerId,
          name: name,
          avatarColor: avatarColor,
          phone: phone,
        ),
      ),
    );
  }

  Future<void> seedBalance({
    required String contactId,
    required TransactionType type,
    required int amount,
    String currency = DbConstants.currencyYer,
    String description = 'حركة',
    String itemName = 'بضاعة',
  }) async {
    if (type == TransactionType.debt) {
      await seedDebt(
        contactId: contactId,
        amount: amount,
        currency: currency,
        description: description,
        itemName: itemName,
      );
      return;
    }
    await seedPayment(
      contactId: contactId,
      amount: amount,
      currency: currency,
      description: description,
    );
  }

  Future<void> seedDebt({
    required String contactId,
    required int amount,
    String currency = DbConstants.currencyYer,
    String description = 'دين',
    String itemName = 'بضاعة',
  }) async {
    await expectRight(
      transactionRepository.create(
        CreateTransactionParams(
          contactId: contactId,
          type: TransactionType.debt,
          amount: amount,
          currency: currency,
          description: description,
          itemName: itemName,
          transactionDate: DateTime.utc(2026, 3),
        ),
      ),
    );
  }

  Future<void> seedPayment({
    required String contactId,
    required int amount,
    String currency = DbConstants.currencyYer,
    String description = 'دفعة',
  }) async {
    await expectRight(
      transactionRepository.create(
        CreateTransactionParams(
          contactId: contactId,
          type: TransactionType.payment,
          amount: amount,
          currency: currency,
          description: description,
          transactionDate: DateTime.utc(2026, 3, 2),
        ),
      ),
    );
  }

  Future<Map<String, int>> sumGlobalBalances() async {
    final rows = await balanceLocalDataSource.watchAllBalances().first;
    final totals = <String, int>{};
    for (final row in rows) {
      totals.update(
        row.currencyCode,
        (value) => value + row.netBalance,
        ifAbsent: () => row.netBalance,
      );
    }
    return totals;
  }

  Future<Map<String, Map<String, int>>> snapshotLedgerBalances(
    String ledgerId,
  ) async {
    final contacts = await contactRepository.watchByLedger(ledgerId).first;
    final snapshot = <String, Map<String, int>>{};
    for (final contact in contacts) {
      final balances = await expectRight(
        balanceRepository.getByContact(contact.id),
      );
      snapshot[contact.name] = {
        for (final row in balances) row.currencyCode: row.netBalance,
      };
    }
    return snapshot;
  }

  Future<int> countContactsInLedger(String ledgerId) async {
    final contacts = await contactRepository.watchByLedger(ledgerId).first;
    return contacts.length;
  }

  Future<bool> isLedgerUserArchived(String ledgerId) async {
    final ledger = await expectRight(ledgerRepository.getById(ledgerId));
    return ledger.isUserArchived;
  }

  Future<String?> carryForwardTargetLedgerId(String ledgerId) async {
    final ledger = await expectRight(ledgerRepository.getById(ledgerId));
    return ledger.carryForwardTargetLedgerId;
  }

  Future<void> setLedgerFlags(
    String ledgerId, {
    bool? isArchived,
    bool? isUserArchived,
    String? carryForwardTargetLedgerId,
  }) async {
    await (database.update(database.ledgers)
          ..where((table) => table.id.equals(ledgerId)))
        .write(
      LedgersCompanion(
        isArchived: isArchived == null
            ? const drift.Value.absent()
            : drift.Value(isArchived),
        isUserArchived: isUserArchived == null
            ? const drift.Value.absent()
            : drift.Value(isUserArchived),
        carryForwardTargetLedgerId: carryForwardTargetLedgerId == null
            ? const drift.Value.absent()
            : drift.Value(carryForwardTargetLedgerId),
        updatedAt: drift.Value(DateTime.now().toUtc()),
      ),
    );
  }
}

Future<T> expectRight<T>(FutureOr<Either<Failure, T>> resultOrFuture) async {
  final result = await resultOrFuture;
  return result.fold(
    (failure) => fail('Expected Right but got Left($failure)'),
    (value) => value,
  );
}

Future<Failure> expectLeft<T>(
  FutureOr<Either<Failure, T>> resultOrFuture,
) async {
  final result = await resultOrFuture;
  return result.fold(
    (failure) => failure,
    (value) => fail('Expected Left but got Right($value)'),
  );
}
