import 'package:daftar/application/contact/get_contact_by_id_use_case.dart';
import 'package:daftar/application/contact/prepare_contact_statement_use_case.dart';
import 'package:daftar/application/transaction/get_all_transactions_for_contact_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockGetContactByIdUseCase extends Mock implements GetContactByIdUseCase {}

class MockGetAllTransactionsForContactUseCase extends Mock
    implements GetAllTransactionsForContactUseCase {}

class MockBalanceRepository extends Mock implements BalanceRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  late MockGetContactByIdUseCase getContact;
  late MockGetAllTransactionsForContactUseCase getTransactions;
  late MockBalanceRepository balances;
  late PrepareContactStatementUseCase sut;

  final now = DateTime.utc(2026, 8, 14);

  Contact contact({String? creditCurrency}) {
    return Contact(
      id: 'contact-1',
      ledgerId: 'ledger-1',
      name: 'Mohamed',
      creditCurrency: creditCurrency,
      avatarColor: '#000000',
      createdAt: now,
      updatedAt: now,
    );
  }

  Transaction txn() {
    return Transaction(
      id: 'txn-1',
      contactId: 'contact-1',
      type: TransactionType.debt,
      amount: 500,
      currency: 'SAR',
      transactionDate: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  ContactBalance balance({
    required String currency,
    required int debt,
    required int payment,
  }) {
    return ContactBalance(
      contactId: 'contact-1',
      currencyCode: currency,
      totalDebt: debt,
      totalPayment: payment,
      netBalance: payment - debt,
      lastUpdatedAt: now,
    );
  }

  setUp(() {
    getContact = MockGetContactByIdUseCase();
    getTransactions = MockGetAllTransactionsForContactUseCase();
    balances = MockBalanceRepository();
    sut = PrepareContactStatementUseCase(
      getContactByIdUseCase: getContact,
      getAllTransactionsForContactUseCase: getTransactions,
      balanceRepository: balances,
    );
  });

  test('empty contact id is contact_id_required', () async {
    final result = await sut.execute(contactId: '  ');

    expect(result.getLeft().toNullable()?.code, 'contact_id_required');
    verifyNever(() => getContact.execute(any()));
  });

  test('missing contact returns Left from getById', () async {
    when(() => getContact.execute('missing')).thenAnswer(
      (_) async => const Left(DatabaseFailure('Contact not found')),
    );

    final result = await sut.execute(contactId: 'missing');

    expect(result.getLeft().toNullable(), isA<DatabaseFailure>());
    verifyNever(() => getTransactions.execute(any()));
  });

  test('happy path prefers creditCurrency balance and includes txns', () async {
    when(() => getContact.execute('contact-1')).thenAnswer(
      (_) async => Right(contact(creditCurrency: 'SAR')),
    );
    when(() => getTransactions.execute('contact-1')).thenAnswer(
      (_) async => Right([txn()]),
    );
    when(() => balances.getByContact('contact-1')).thenAnswer(
      (_) async => Right([
        balance(currency: 'YER', debt: 100, payment: 0),
        balance(currency: 'SAR', debt: 500, payment: 200),
      ]),
    );

    final result = await sut.execute(contactId: 'contact-1');
    final export = result.getRight().toNullable()!;

    expect(export.contact.id, 'contact-1');
    expect(export.transactions, hasLength(1));
    expect(export.balance.currencyCode, 'SAR');
    expect(export.balance.totalDebt, 500);
    expect(export.balance.netBalance, -300);
  });

  test('empty balances yield a zero row in credit currency', () async {
    when(() => getContact.execute('contact-1')).thenAnswer(
      (_) async => Right(contact(creditCurrency: 'SAR')),
    );
    when(() => getTransactions.execute('contact-1')).thenAnswer(
      (_) async => const Right([]),
    );
    when(() => balances.getByContact('contact-1')).thenAnswer(
      (_) async => const Right([]),
    );

    final result = await sut.execute(contactId: 'contact-1');
    final export = result.getRight().toNullable()!;

    expect(export.transactions, isEmpty);
    expect(export.balance.currencyCode, 'SAR');
    expect(export.balance.totalDebt, 0);
    expect(export.balance.totalPayment, 0);
    expect(export.balance.netBalance, 0);
  });
}
