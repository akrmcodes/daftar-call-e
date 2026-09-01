import 'dart:async';

import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/balance_local_ds.dart';
import 'package:daftar/data/datasources/local/contact_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/datasources/local/ledger_local_ds.dart';
import 'package:daftar/data/datasources/local/transaction_local_ds.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/data/repositories/contact_repository_impl.dart';
import 'package:daftar/data/repositories/ledger_repository_impl.dart';
import 'package:daftar/data/repositories/transaction_repository_impl.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  late AppDatabase database;
  late TransactionLocalDataSource transactionLocal;
  late LedgerRepositoryImpl ledgerRepository;
  late ContactRepositoryImpl contactRepository;
  late TransactionRepositoryImpl transactionRepository;

  setUp(() {
    DeviceIdentity.initializeForTest('closing-local-day-test');
    database = AppDatabase(NativeDatabase.memory());
    transactionLocal = TransactionLocalDataSource(database);
    final audit = AuditLogLocalDataSource(database);
    final balances = BalanceLocalDataSource(database);
    ledgerRepository = LedgerRepositoryImpl(
      ledgerLocalDataSource: LedgerLocalDataSource(database),
      contactLocalDataSource: ContactLocalDataSource(database),
      transactionLocalDataSource: transactionLocal,
      balanceLocalDataSource: balances,
      auditLogLocalDataSource: audit,
    );
    contactRepository = ContactRepositoryImpl(
      contactLocalDataSource: ContactLocalDataSource(database),
      transactionLocalDataSource: transactionLocal,
      balanceLocalDataSource: balances,
      auditLogLocalDataSource: audit,
    );
    transactionRepository = TransactionRepositoryImpl(
      transactionLocalDataSource: transactionLocal,
      balanceLocalDataSource: balances,
      auditLogLocalDataSource: audit,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'getCreatedOnLocalDay uses createdAt local calendar, not transactionDate',
    () async {
      final ledger = await expectRight(
        ledgerRepository.create(
          const CreateLedgerParams(
            name: 'عملاء',
            type: LedgerType.customers,
            icon: 'store',
            color: '#000000',
          ),
        ),
      );
      final contact = await expectRight(
        contactRepository.create(
          CreateContactParams(
            ledgerId: ledger.id,
            name: 'محمد',
            avatarColor: '#000000',
          ),
        ),
      );

      const localDay = '2026-08-15';
      final bounds = ClosingAgentConstants.utcBoundsForLocalDay(localDay)!;
      final inDay = bounds.startUtc.add(const Duration(hours: 10));
      final previousDay = bounds.startUtc.subtract(const Duration(hours: 1));
      final nextDay = bounds.endUtc;

      await transactionLocal.createTransaction(
        TransactionModel(
          id: 'in-day-quick-add',
          contactId: contact.id,
          type: TransactionType.debt,
          amount: 1500,
          currency: 'YER',
          description: null,
          itemName: 'خبز',
          transactionDate: previousDay,
          attachmentPath: null,
          createdAt: inDay,
          updatedAt: inDay,
        ),
      );
      await transactionLocal.createTransaction(
        TransactionModel(
          id: 'other-day',
          contactId: contact.id,
          type: TransactionType.payment,
          amount: 200,
          currency: 'YER',
          description: null,
          itemName: null,
          transactionDate: inDay,
          attachmentPath: null,
          createdAt: previousDay,
          updatedAt: previousDay,
        ),
      );
      await transactionLocal.createTransaction(
        TransactionModel(
          id: 'next-day',
          contactId: contact.id,
          type: TransactionType.debt,
          amount: 50,
          currency: 'YER',
          description: null,
          itemName: null,
          transactionDate: inDay,
          attachmentPath: null,
          createdAt: nextDay,
          updatedAt: nextDay,
        ),
      );
      await transactionLocal.createTransaction(
        TransactionModel(
          id: 'archived',
          contactId: contact.id,
          type: TransactionType.debt,
          amount: 999,
          currency: 'YER',
          description: null,
          itemName: null,
          transactionDate: inDay,
          attachmentPath: null,
          createdAt: inDay,
          updatedAt: inDay,
          isArchived: true,
        ),
      );

      final rows = await expectRight(
        transactionRepository.getCreatedOnLocalDay(localDay),
      );
      expect(rows.map((row) => row.id), ['in-day-quick-add']);
      expect(rows.first.amount, 1500);
      expect(rows.first.itemName, 'خبز');
    },
  );
}

Future<T> expectRight<T>(FutureOr<Either<Failure, T>> futureOrResult) async {
  final result = await futureOrResult;
  return result.fold(
    (failure) => fail('Expected Right but got Left($failure)'),
    (value) => value,
  );
}
