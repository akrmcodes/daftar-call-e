import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

class SeededLedgerGraph {
  const SeededLedgerGraph({required this.ledger, required this.contact});

  final Ledger ledger;
  final Contact contact;
}

Future<T> expectRight<T>(Future<Either<Failure, T>> future) async {
  final result = await future;
  return result.fold(
    (failure) => fail('Expected Right but got Left(${failure.message})'),
    (value) => value,
  );
}

Future<Failure> expectLeft<T>(Future<Either<Failure, T>> future) async {
  final result = await future;
  return result.fold(
    (failure) => failure,
    (value) => fail('Expected Left but got Right($value)'),
  );
}

Future<SeededLedgerGraph> seedLedgerGraph(ProviderContainer container) async {
  final ledger = await expectRight(
    container
        .read(createLedgerUseCaseProvider)
        .execute(
          name: 'E2E Ledger',
          type: LedgerType.custom,
          icon: 'ledger',
          color: 0xFF1565C0,
        ),
  );

  final contact = await expectRight(
    container
        .read(createContactUseCaseProvider)
        .execute(
          ledgerId: ledger.id,
          name: 'E2E Contact',
          phone: '+967777777777',
          notes: 'Seed note',
          creditLimit: 5000,
          creditCurrency: DbConstants.currencyYer,
          avatarColor: '#FF9800',
        ),
  );

  await expectRight(
    container
        .read(addTransactionUseCaseProvider)
        .execute(
          contactId: contact.id,
          type: TransactionType.debt,
          amount: 1250,
          currency: DbConstants.currencyYer,
          description: 'Seed debt',
          itemName: 'Flour',
          transactionDate: DateTime.utc(2026, 1, 2, 3, 4, 5),
        ),
  );

  return SeededLedgerGraph(ledger: ledger, contact: contact);
}
