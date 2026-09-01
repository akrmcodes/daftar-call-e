import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/balance_local_ds.dart';
import 'package:daftar/data/datasources/local/contact_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/datasources/local/ledger_local_ds.dart';
import 'package:daftar/data/datasources/local/transaction_local_ds.dart';
import 'package:daftar/data/models/balance_model.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/ledger_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/data/repositories/balance_recalculation_service.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BalanceRecalculationService', () {
    late AppDatabase database;
    late LedgerLocalDataSource ledgerLocalDataSource;
    late ContactLocalDataSource contactLocalDataSource;
    late TransactionLocalDataSource transactionLocalDataSource;
    late BalanceLocalDataSource balanceLocalDataSource;
    late BalanceRecalculationService service;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      ledgerLocalDataSource = LedgerLocalDataSource(database);
      contactLocalDataSource = ContactLocalDataSource(database);
      transactionLocalDataSource = TransactionLocalDataSource(database);
      balanceLocalDataSource = BalanceLocalDataSource(database);
      service = BalanceRecalculationService(
        database: database,
        balanceLocalDataSource: balanceLocalDataSource,
      );
    });

    tearDown(() async {
      await database.close();
    });

    Future<String> seedContact() async {
      final now = DateTime.now().toUtc();
      final ledger = await ledgerLocalDataSource.createLedger(
        LedgerModel(
          id: UuidUtil.generate(),
          name: 'Test Ledger',
          type: LedgerType.customers,
          icon: 'store',
          color: '#1565C0',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final contact = await contactLocalDataSource.createContact(
        ContactModel(
          id: UuidUtil.generate(),
          ledgerId: ledger.id,
          name: 'Test Contact',
          phone: '770000000',
          notes: null,
          creditLimit: null,
          creditCurrency: null,
          avatarColor: '#FF9800',
          createdAt: now,
          updatedAt: now,
        ),
      );
      return contact.id;
    }

    Future<TransactionModel> insertTransaction({
      required String contactId,
      required int amount,
      required String currency,
      bool isArchived = false,
      bool isDeleted = false,
    }) async {
      final now = DateTime.now().toUtc();
      return transactionLocalDataSource.createTransaction(
        TransactionModel(
          id: UuidUtil.generate(),
          contactId: contactId,
          type: TransactionType.debt,
          amount: amount,
          currency: currency,
          description: 'test',
          itemName: 'item',
          transactionDate: now,
          attachmentPath: null,
          createdAt: now,
          updatedAt: now,
          isArchived: isArchived,
          isDeleted: isDeleted,
        ),
      );
    }

    Future<List<BalanceModel>> readBalances(String contactId) {
      return balanceLocalDataSource.getBalanceByContact(contactId);
    }

    Future<List<BalanceModel>> recalculateInTransaction(String contactId) async {
      late List<BalanceModel> balances;
      await database.transaction(() async {
        balances = await service.recalculateBalancesForContact(
          contactId: contactId,
          lastUpdatedAt: DateTime.now().toUtc(),
        );
      });
      return balances;
    }

    test('excludes archived transactions from balance', () async {
      final contactId = await seedContact();
      await insertTransaction(
        contactId: contactId,
        amount: 1500,
        currency: DbConstants.currencyYer,
      );
      await insertTransaction(
        contactId: contactId,
        amount: 500,
        currency: DbConstants.currencyYer,
        isArchived: true,
      );

      final balances = await recalculateInTransaction(contactId);

      expect(balances, hasLength(1));
      expect(balances.single.currencyCode, DbConstants.currencyYer);
      expect(balances.single.totalDebt, 1500);
      expect(balances.single.netBalance, -1500);
    });

    test('removes stale currency balance rows', () async {
      final contactId = await seedContact();
      final now = DateTime.now().toUtc();

      await insertTransaction(
        contactId: contactId,
        amount: 1000,
        currency: DbConstants.currencyYer,
      );

      await balanceLocalDataSource.upsertBalance(
        BalanceModel(
          contactId: contactId,
          currencyCode: DbConstants.currencyYer,
          totalDebt: 1000,
          totalPayment: 0,
          netBalance: -1000,
          lastUpdatedAt: now,
        ),
      );
      await balanceLocalDataSource.upsertBalance(
        BalanceModel(
          contactId: contactId,
          currencyCode: DbConstants.currencyUsd,
          totalDebt: 200,
          totalPayment: 0,
          netBalance: -200,
          lastUpdatedAt: now,
        ),
      );

      await recalculateInTransaction(contactId);

      final persisted = await readBalances(contactId);
      expect(persisted, hasLength(1));
      expect(persisted.single.currencyCode, DbConstants.currencyYer);
    });

    test('clears all rows when no active transactions', () async {
      final contactId = await seedContact();
      final now = DateTime.now().toUtc();

      await balanceLocalDataSource.upsertBalance(
        BalanceModel(
          contactId: contactId,
          currencyCode: DbConstants.currencyYer,
          totalDebt: 500,
          totalPayment: 0,
          netBalance: -500,
          lastUpdatedAt: now,
        ),
      );

      final archived = await insertTransaction(
        contactId: contactId,
        amount: 500,
        currency: DbConstants.currencyYer,
        isArchived: true,
      );
      await transactionLocalDataSource.updateTransaction(
        TransactionModel(
          id: archived.id,
          contactId: archived.contactId,
          type: archived.type,
          amount: archived.amount,
          currency: archived.currency,
          description: archived.description,
          itemName: archived.itemName,
          transactionDate: archived.transactionDate,
          attachmentPath: archived.attachmentPath,
          createdAt: archived.createdAt,
          updatedAt: now,
          isArchived: true,
          isDeleted: true,
        ),
      );

      await recalculateInTransaction(contactId);

      final persisted = await readBalances(contactId);
      expect(persisted, isEmpty);
    });

    test('rollback leaves balances unchanged on transaction failure', () async {
      final contactId = await seedContact();
      final now = DateTime.now().toUtc();

      await insertTransaction(
        contactId: contactId,
        amount: 800,
        currency: DbConstants.currencyYer,
      );

      await balanceLocalDataSource.upsertBalance(
        BalanceModel(
          contactId: contactId,
          currencyCode: DbConstants.currencyYer,
          totalDebt: 9999,
          totalPayment: 0,
          netBalance: -9999,
          lastUpdatedAt: now,
        ),
      );

      await expectLater(
        database.transaction(() async {
          await service.recalculateBalancesForContact(
            contactId: contactId,
            lastUpdatedAt: now,
          );
          throw StateError('simulated crash');
        }),
        throwsA(isA<StateError>()),
      );

      final persisted = await readBalances(contactId);
      expect(persisted, hasLength(1));
      expect(persisted.single.totalDebt, 9999);
      expect(persisted.single.netBalance, -9999);
    });
  });
}
