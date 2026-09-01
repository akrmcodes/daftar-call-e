import 'dart:async';

import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/balance_local_ds.dart';
import 'package:daftar/data/datasources/local/contact_local_ds.dart';
import 'package:daftar/data/datasources/local/currency_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/datasources/local/ledger_local_ds.dart';
import 'package:daftar/data/datasources/local/settings_local_ds.dart';
import 'package:daftar/data/datasources/local/transaction_local_ds.dart';
import 'package:daftar/data/repositories/audit_log_repository_impl.dart';
import 'package:daftar/data/repositories/balance_repository_impl.dart';
import 'package:daftar/data/repositories/contact_repository_impl.dart';
import 'package:daftar/data/repositories/currency_repository_impl.dart';
import 'package:daftar/data/repositories/ledger_repository_impl.dart';
import 'package:daftar/data/repositories/settings_repository_impl.dart';
import 'package:daftar/data/repositories/transaction_repository_impl.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  group('Repository lifecycle', () {
    late AppDatabase database;
    late LedgerRepositoryImpl ledgerRepository;
    late ContactRepositoryImpl contactRepository;
    late TransactionRepositoryImpl transactionRepository;
    late BalanceRepositoryImpl balanceRepository;
    late CurrencyRepositoryImpl currencyRepository;
    late SettingsRepositoryImpl settingsRepository;
    late AuditLogRepositoryImpl auditLogRepository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());

      final ledgerLocalDataSource = LedgerLocalDataSource(database);
      final contactLocalDataSource = ContactLocalDataSource(database);
      final transactionLocalDataSource = TransactionLocalDataSource(database);
      final balanceLocalDataSource = BalanceLocalDataSource(database);
      final currencyLocalDataSource = CurrencyLocalDataSource(database);
      final settingsLocalDataSource = SettingsLocalDataSource(database);
      final auditLogLocalDataSource = AuditLogLocalDataSource(database);

      ledgerRepository = LedgerRepositoryImpl(
        ledgerLocalDataSource: ledgerLocalDataSource,
        contactLocalDataSource: contactLocalDataSource,
        transactionLocalDataSource: transactionLocalDataSource,
        balanceLocalDataSource: balanceLocalDataSource,
        auditLogLocalDataSource: auditLogLocalDataSource,
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
      currencyRepository = CurrencyRepositoryImpl(
        currencyLocalDataSource: currencyLocalDataSource,
        auditLogLocalDataSource: auditLogLocalDataSource,
      );
      settingsRepository = SettingsRepositoryImpl(
        settingsLocalDataSource: settingsLocalDataSource,
        auditLogLocalDataSource: auditLogLocalDataSource,
      );
      auditLogRepository = AuditLogRepositoryImpl(
        auditLogLocalDataSource: auditLogLocalDataSource,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('CRUD lifecycle with limits, balances, and audit logs', () async {
      final settings = await expectRight(settingsRepository.get());
      expect(settings.locale, 'ar');
      expect(settings.defaultCurrency, DbConstants.defaultCurrency);
      expect(settings.isMultiCurrencyEnabled, isFalse);

      final builtInCurrencies = await expectRight(
        currencyRepository.getBuiltIn(),
      );
      expect(builtInCurrencies, hasLength(3));

      final ledger = await expectRight(
        ledgerRepository.create(
          const CreateLedgerParams(
            name: 'حسابات المتجر',
            type: LedgerType.custom,
            icon: 'store',
            color: '#1565C0',
          ),
        ),
      );
      expect(ledger.name, 'حسابات المتجر');

      final fetchedLedger = await expectRight(
        ledgerRepository.getById(ledger.id),
      );
      expect(fetchedLedger.id, ledger.id);

      final updatedLedger = await expectRight(
        ledgerRepository.update(
          UpdateLedgerParams(
            id: ledger.id,
            name: 'حسابات المتجر الرئيسية',
            icon: 'storefront',
            color: '#0D47A1',
            sortOrder: 7,
          ),
        ),
      );
      expect(updatedLedger.name, 'حسابات المتجر الرئيسية');
      expect(updatedLedger.sortOrder, 7);

      // Free-tier limits are enforced in the application layer (use cases),
      // not in repositories — the data layer must allow multiple ledgers.
      final secondLedger = await expectRight(
        ledgerRepository.create(
          const CreateLedgerParams(
            name: 'حسابات إضافية',
            type: LedgerType.custom,
            icon: 'folder',
            color: '#424242',
          ),
        ),
      );
      expect(secondLedger.name, 'حسابات إضافية');

      final activeLedgersAfterSecondCreate =
          await ledgerRepository.watchAll().first;
      expect(activeLedgersAfterSecondCreate, hasLength(2));

      final firstLedgerContact = await expectRight(
        contactRepository.create(
          CreateContactParams(
            ledgerId: ledger.id,
            name: 'عميل أساسي',
            avatarColor: '#FF9800',
            phone: '770000000',
            notes: 'ملاحظات أولية',
            creditLimit: 25000,
            creditCurrency: DbConstants.currencyYer,
          ),
        ),
      );
      expect(firstLedgerContact.ledgerId, ledger.id);

      final fetchedContact = await expectRight(
        contactRepository.getById(firstLedgerContact.id),
      );
      expect(fetchedContact.name, 'عميل أساسي');

      final updatedContact = await expectRight(
        contactRepository.update(
          UpdateContactParams(
            id: firstLedgerContact.id,
            name: 'عميل محدث',
            notes: 'ملاحظات محدثة',
            creditLimit: 30000,
          ),
        ),
      );
      expect(updatedContact.name, 'عميل محدث');

      for (var index = 0; index < 49; index++) {
        final created = await expectRight(
          contactRepository.create(
            CreateContactParams(
              ledgerId: ledger.id,
              name: 'عميل إضافي $index',
              avatarColor: '#009688',
              phone: '770000${index.toString().padLeft(3, '0')}',
            ),
          ),
        );
        expect(created.ledgerId, ledger.id);
      }

      final overflowContact = await expectRight(
        contactRepository.create(
          CreateContactParams(
            ledgerId: ledger.id,
            name: 'عميل يتجاوز الحد',
            avatarColor: '#009688',
          ),
        ),
      );
      expect(overflowContact.name, 'عميل يتجاوز الحد');

      final contactsInLedger = await contactRepository
          .watchByLedger(ledger.id)
          .first;
      expect(contactsInLedger, hasLength(51));

      final debt = await expectRight(
        transactionRepository.create(
          CreateTransactionParams(
            contactId: firstLedgerContact.id,
            type: TransactionType.debt,
            amount: 1500,
            currency: DbConstants.currencyYer,
            description: 'بضاعة',
            itemName: 'أرز',
            transactionDate: DateTime.utc(2025),
          ),
        ),
      );
      expect(debt.amount, 1500);

      final payment = await expectRight(
        transactionRepository.create(
          CreateTransactionParams(
            contactId: firstLedgerContact.id,
            type: TransactionType.payment,
            amount: 500,
            currency: DbConstants.currencyYer,
            description: 'جزئي',
            transactionDate: DateTime.utc(2025, 1, 2),
          ),
        ),
      );
      expect(payment.type, TransactionType.payment);

      final transactions = await expectRight(
        transactionRepository.getByContact(firstLedgerContact.id),
      );
      expect(transactions, hasLength(2));
      expect(transactions.first.id, payment.id);

      final balances = await expectRight(
        balanceRepository.getByContact(firstLedgerContact.id),
      );
      expect(balances, hasLength(1));
      expect(balances.single.netBalance, -1000);

      final updatedPayment = await expectRight(
        transactionRepository.update(
          UpdateTransactionParams(
            id: payment.id,
            amount: 700,
            description: 'تسوية جزئية',
          ),
        ),
      );
      expect(updatedPayment.amount, 700);

      final balancesAfterUpdate = await expectRight(
        balanceRepository.getByContact(firstLedgerContact.id),
      );
      expect(balancesAfterUpdate.single.netBalance, -800);

      await expectRight(transactionRepository.delete(payment.id));

      final transactionsAfterDelete = await expectRight(
        transactionRepository.getByContact(firstLedgerContact.id),
      );
      expect(transactionsAfterDelete, hasLength(1));
      expect(transactionsAfterDelete.single.id, debt.id);

      final balancesAfterDelete = await expectRight(
        balanceRepository.getByContact(firstLedgerContact.id),
      );
      expect(balancesAfterDelete.single.netBalance, -1500);

      await expectRight(contactRepository.delete(firstLedgerContact.id));

      final deletedContactResult = await contactRepository.getById(
        firstLedgerContact.id,
      );
      final deletedContactFailure = await expectLeft(deletedContactResult);
      expect(deletedContactFailure, isA<DatabaseFailure>());

      final balancesAfterContactDelete = await expectRight(
        balanceRepository.getByContact(firstLedgerContact.id),
      );
      expect(balancesAfterContactDelete, isEmpty);

      final transactionsAfterContactDelete = await expectRight(
        transactionRepository.getByContact(firstLedgerContact.id),
      );
      expect(transactionsAfterContactDelete, isEmpty);

      final restoredContact = await expectRight(
        contactRepository.restore(firstLedgerContact.id),
      );
      expect(restoredContact.id, firstLedgerContact.id);
      expect(restoredContact.isDeleted, isFalse);

      final fetchedRestoredContact = await expectRight(
        contactRepository.getById(firstLedgerContact.id),
      );
      expect(fetchedRestoredContact.id, firstLedgerContact.id);

      final balancesAfterContactRestore = await expectRight(
        balanceRepository.getByContact(firstLedgerContact.id),
      );
      expect(balancesAfterContactRestore, hasLength(1));
      expect(balancesAfterContactRestore.single.totalDebt, 1500);
      expect(balancesAfterContactRestore.single.totalPayment, 0);
      expect(balancesAfterContactRestore.single.netBalance, -1500);

      final transactionsAfterContactRestore = await expectRight(
        transactionRepository.getByContact(firstLedgerContact.id),
      );
      expect(transactionsAfterContactRestore, hasLength(1));
      expect(transactionsAfterContactRestore.single.id, debt.id);

      await expectRight(ledgerRepository.delete(ledger.id));

      final deletedLedgerResult = await ledgerRepository.getById(ledger.id);
      final deletedLedgerFailure = await expectLeft(deletedLedgerResult);
      expect(deletedLedgerFailure, isA<DatabaseFailure>());

      final activeLedgers = await ledgerRepository.watchAll().first;
      expect(activeLedgers, hasLength(1));
      expect(activeLedgers.single.id, secondLedger.id);

      final ledgerAuditLogs = await expectRight(
        auditLogRepository.getByEntity('ledger', ledger.id),
      );
      expect(ledgerAuditLogs, hasLength(3));
    });

    test(
      'contact restore does not resurrect individually deleted transactions',
      () async {
        final ledger = await expectRight(
          ledgerRepository.create(
            const CreateLedgerParams(
              name: 'دفتر استعادة',
              type: LedgerType.custom,
              icon: 'store',
              color: '#1565C0',
            ),
          ),
        );

        final contact = await expectRight(
          contactRepository.create(
            CreateContactParams(
              ledgerId: ledger.id,
              name: 'عميل الاستعادة',
              avatarColor: '#FF9800',
            ),
          ),
        );

        final debt = await expectRight(
          transactionRepository.create(
            CreateTransactionParams(
              contactId: contact.id,
              type: TransactionType.debt,
              amount: 2000,
              currency: DbConstants.currencyYer,
              transactionDate: DateTime.utc(2025, 3),
            ),
          ),
        );

        final payment = await expectRight(
          transactionRepository.create(
            CreateTransactionParams(
              contactId: contact.id,
              type: TransactionType.payment,
              amount: 800,
              currency: DbConstants.currencyYer,
              transactionDate: DateTime.utc(2025, 3, 2),
            ),
          ),
        );

        await expectRight(transactionRepository.delete(payment.id));

        await expectRight(contactRepository.delete(contact.id));

        await expectRight(contactRepository.restore(contact.id));

        final restoredTransactions = await expectRight(
          transactionRepository.getByContact(contact.id),
        );
        expect(restoredTransactions, hasLength(1));
        expect(restoredTransactions.single.id, debt.id);
      },
    );
  });
}

Future<T> expectRight<T>(FutureOr<Either<Failure, T>> futureOrResult) async {
  final result = await futureOrResult;
  return result.fold(
    (failure) => fail('Expected Right but got Left($failure)'),
    (value) => value,
  );
}

Future<Failure> expectLeft<T>(
  FutureOr<Either<Failure, T>> futureOrResult,
) async {
  final result = await futureOrResult;
  return result.fold(
    (failure) => failure,
    (value) => fail('Expected Left but got Right($value)'),
  );
}
