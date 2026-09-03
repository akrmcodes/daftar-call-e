import 'package:daftar/application/contact/get_collections_candidates_use_case.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/enums/payment_behavior_band.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:daftar/domain/value_objects/collections_outreach_contact_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockBalanceRepository extends Mock implements BalanceRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockContactRepository extends Mock implements ContactRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  final asOf = DateTime(2026, 8, 14);
  final created = DateTime.utc(2026, 8, 14);

  const mohamedOutreach = CollectionsOutreachContactEntry(
    contactId: 'contact-mohamed',
    contactName: 'Mohamed',
    ledgerId: 'ledger-1',
    phone: '+967700000001',
    email: 'mohamed@example.com',
  );

  final mohamed = Contact(
    id: 'contact-mohamed',
    ledgerId: 'ledger-1',
    name: 'Mohamed',
    avatarColor: '#000000',
    createdAt: created,
    updatedAt: created,
    phone: '+967700000001',
    email: 'mohamed@example.com',
    creditCurrency: 'YER',
  );

  ContactBalance balance({
    required String contactId,
    required int net,
    String currency = 'YER',
  }) {
    final debt = net < 0 ? -net : 0;
    final payment = net > 0 ? net : 0;
    return ContactBalance(
      contactId: contactId,
      currencyCode: currency,
      totalDebt: debt,
      totalPayment: payment,
      netBalance: net,
      lastUpdatedAt: created,
    );
  }

  Transaction txn({
    required String id,
    required TransactionType type,
    required int amount,
    required DateTime date,
    String contactId = 'contact-mohamed',
  }) {
    return Transaction(
      id: id,
      contactId: contactId,
      type: type,
      amount: amount,
      currency: 'YER',
      transactionDate: date,
      createdAt: date,
      updatedAt: date,
    );
  }

  late MockBalanceRepository balances;
  late MockTransactionRepository transactions;
  late MockContactRepository contacts;
  late GetCollectionsCandidatesUseCase useCase;

  setUp(() {
    balances = MockBalanceRepository();
    transactions = MockTransactionRepository();
    contacts = MockContactRepository();
    useCase = GetCollectionsCandidatesUseCase(
      balanceRepository: balances,
      transactionRepository: transactions,
      contactRepository: contacts,
    );
  });

  void stubOutreach(List<CollectionsOutreachContactEntry> entries) {
    when(contacts.getContactsEligibleForCollectionsOutreach).thenAnswer(
      (_) async => Right(entries),
    );
  }

  void stubBalances(List<ContactBalance> rows) {
    when(balances.watchAllBalances).thenAnswer((_) => Stream.value(rows));
  }

  void stubContact(Contact contact) {
    when(() => contacts.getById(contact.id)).thenAnswer(
      (_) async => Right(contact),
    );
  }

  void stubTxns(String contactId, List<Transaction> rows) {
    when(
      () => transactions.getRawTransactionsByContact(contactId),
    ).thenAnswer((_) async => Right(rows));
  }

  test('empty outreach list is success', () async {
    stubOutreach(const []);
    stubBalances(const []);

    final result = await useCase.execute(asOf: asOf);

    expect(result.getRight().toNullable(), isEmpty);
    verifyNever(() => transactions.getRawTransactionsByContact(any()));
  });

  test('Mohamed 100 then +50 is firm with owed 150', () async {
    stubOutreach(const [mohamedOutreach]);
    stubBalances([balance(contactId: 'contact-mohamed', net: -150)]);
    stubContact(mohamed);
    stubTxns('contact-mohamed', [
      txn(
        id: 'd-100',
        type: TransactionType.debt,
        amount: 100,
        date: DateTime(2026, 7, 5),
      ),
      txn(
        id: 'd-50',
        type: TransactionType.debt,
        amount: 50,
        date: DateTime(2026, 8, 4),
      ),
    ]);

    final result = await useCase.execute(asOf: asOf);
    final rows = result.getRight().toNullable()!;

    expect(rows, hasLength(1));
    expect(rows.single.contactId, 'contact-mohamed');
    expect(rows.single.owedMinor, 150);
    expect(rows.single.netBalance, -150);
    expect(rows.single.ageDays, 40);
    expect(rows.single.toneBand, ReminderToneBand.firm);
    expect(rows.single.paymentBehaviorBand, PaymentBehaviorBand.none);
    expect(rows.single.phone, '+967700000001');
    expect(rows.single.rail, OutreachRail.email);
  });

  test('FIFO payment 100 leaves reminder band on remaining 50', () async {
    stubOutreach(const [mohamedOutreach]);
    stubBalances([balance(contactId: 'contact-mohamed', net: -50)]);
    stubContact(mohamed);
    stubTxns('contact-mohamed', [
      txn(
        id: 'd-100',
        type: TransactionType.debt,
        amount: 100,
        date: DateTime(2026, 7, 5),
      ),
      txn(
        id: 'd-50',
        type: TransactionType.debt,
        amount: 50,
        date: DateTime(2026, 8, 4),
      ),
      txn(
        id: 'p-100',
        type: TransactionType.payment,
        amount: 100,
        date: DateTime(2026, 8, 9),
      ),
    ]);

    final result = await useCase.execute(asOf: asOf);
    final row = result.getRight().toNullable()!.single;

    expect(row.owedMinor, 50);
    expect(row.ageDays, 10);
    expect(row.toneBand, ReminderToneBand.reminder);
    expect(row.daysSinceLastPayment, 5);
    expect(row.paymentBehaviorBand, PaymentBehaviorBand.recent);
  });

  test('phone with netBalance >= 0 is omitted', () async {
    stubOutreach(const [mohamedOutreach]);
    stubBalances([balance(contactId: 'contact-mohamed', net: 100)]);
    stubContact(mohamed);

    final result = await useCase.execute(asOf: asOf);

    expect(result.getRight().toNullable(), isEmpty);
    verifyNever(() => transactions.getRawTransactionsByContact(any()));
  });

  test('overdue without email is included as skipped', () async {
    const phoneOnly = CollectionsOutreachContactEntry(
      contactId: 'contact-mohamed',
      contactName: 'Mohamed',
      ledgerId: 'ledger-1',
      phone: '+967700000001',
    );
    stubOutreach(const [phoneOnly]);
    stubBalances([balance(contactId: 'contact-mohamed', net: -100)]);
    stubContact(mohamed.copyWith(email: null));
    stubTxns('contact-mohamed', [
      txn(
        id: 'd-100',
        type: TransactionType.debt,
        amount: 100,
        date: DateTime(2026, 7, 5),
      ),
    ]);

    final result = await useCase.execute(asOf: asOf);
    final row = result.getRight().toNullable()!.single;

    expect(row.email, isNull);
    expect(row.rail, OutreachRail.skipped);
  });

  test('email-only overdue contact is included', () async {
    const emailOnly = CollectionsOutreachContactEntry(
      contactId: 'contact-mohamed',
      contactName: 'Mohamed',
      ledgerId: 'ledger-1',
      email: 'local+tag@gmail.com',
    );
    stubOutreach(const [emailOnly]);
    stubBalances([balance(contactId: 'contact-mohamed', net: -100)]);
    stubContact(mohamed.copyWith(phone: null, email: 'local+tag@gmail.com'));
    stubTxns('contact-mohamed', [
      txn(
        id: 'd-100',
        type: TransactionType.debt,
        amount: 100,
        date: DateTime(2026, 7, 5),
      ),
    ]);

    final result = await useCase.execute(asOf: asOf);
    final row = result.getRight().toNullable()!.single;
    expect(row.email, 'local+tag@gmail.com');
    expect(row.phone, isNull);
    expect(row.owedMinor, 100);
    expect(row.rail, OutreachRail.email);
  });

  test('friendly D-3 and firm D-30 sort oldest first', () async {
    const aliOutreach = CollectionsOutreachContactEntry(
      contactId: 'contact-ali',
      contactName: 'Ali',
      ledgerId: 'ledger-1',
      phone: '+967700000002',
      email: 'ali@example.com',
    );
    final ali = mohamed.copyWith(
      id: 'contact-ali',
      name: 'Ali',
      phone: '+967700000002',
      email: 'ali@example.com',
    );
    stubOutreach(const [mohamedOutreach, aliOutreach]);
    stubBalances([
      balance(contactId: 'contact-mohamed', net: -100),
      balance(contactId: 'contact-ali', net: -100),
    ]);
    stubContact(mohamed);
    stubContact(ali);
    stubTxns('contact-mohamed', [
      txn(
        id: 'd-m',
        type: TransactionType.debt,
        amount: 100,
        date: DateTime(2026, 8, 11),
      ),
    ]);
    stubTxns('contact-ali', [
      txn(
        id: 'd-a',
        type: TransactionType.debt,
        amount: 100,
        date: DateTime(2026, 7, 15),
        contactId: 'contact-ali',
      ),
    ]);

    final result = await useCase.execute(asOf: asOf);
    final rows = result.getRight().toNullable()!;

    expect(rows, hasLength(2));
    expect(rows.first.contactId, 'contact-ali');
    expect(rows.first.ageDays, 30);
    expect(rows.first.toneBand, ReminderToneBand.firm);
    expect(rows.last.contactId, 'contact-mohamed');
    expect(rows.last.ageDays, 3);
    expect(rows.last.toneBand, ReminderToneBand.friendly);
  });

  test('D-7 debt is reminder band', () async {
    stubOutreach(const [mohamedOutreach]);
    stubBalances([balance(contactId: 'contact-mohamed', net: -100)]);
    stubContact(mohamed);
    stubTxns('contact-mohamed', [
      txn(
        id: 'd-100',
        type: TransactionType.debt,
        amount: 100,
        date: DateTime(2026, 8, 7),
      ),
    ]);

    final result = await useCase.execute(asOf: asOf);
    final row = result.getRight().toNullable()!.single;

    expect(row.ageDays, 7);
    expect(row.toneBand, ReminderToneBand.reminder);
  });

  test('valid Yemen phone with email is callUnavailable', () async {
    const yeOutreach = CollectionsOutreachContactEntry(
      contactId: 'contact-ye',
      contactName: 'Yemen',
      ledgerId: 'ledger-1',
      phone: '0771234567',
      email: 'ye@example.com',
    );
    final yeContact = mohamed.copyWith(
      id: 'contact-ye',
      name: 'Yemen',
      phone: '0771234567',
      email: 'ye@example.com',
    );
    stubOutreach(const [yeOutreach]);
    stubBalances([balance(contactId: 'contact-ye', net: -100)]);
    stubContact(yeContact);
    stubTxns('contact-ye', [
      txn(
        id: 'd-100',
        type: TransactionType.debt,
        amount: 100,
        date: DateTime(2026, 7, 5),
        contactId: 'contact-ye',
      ),
    ]);

    final result = await useCase.execute(
      asOf: asOf,
      allowDial: true,
      allowlist: {'+967771234567'},
    );
    final row = result.getRight().toNullable()!.single;

    expect(row.rail, OutreachRail.callUnavailable);
  });

  test('doNotCall drops from call set but keeps email rail', () async {
    const usOutreach = CollectionsOutreachContactEntry(
      contactId: 'contact-us',
      contactName: 'US',
      ledgerId: 'ledger-1',
      phone: '+15555550100',
      email: 'us@example.com',
      doNotCall: true,
    );
    final usContact = mohamed.copyWith(
      id: 'contact-us',
      name: 'US',
      phone: '+15555550100',
      email: 'us@example.com',
      doNotCall: true,
    );
    stubOutreach(const [usOutreach]);
    stubBalances([balance(contactId: 'contact-us', net: -100)]);
    stubContact(usContact);
    stubTxns('contact-us', [
      txn(
        id: 'd-100',
        type: TransactionType.debt,
        amount: 100,
        date: DateTime(2026, 7, 5),
        contactId: 'contact-us',
      ),
    ]);

    final result = await useCase.execute(
      asOf: asOf,
      allowDial: true,
      allowlist: {'+15555550100'},
    );
    final row = result.getRight().toNullable()!.single;

    expect(row.rail, OutreachRail.email);
    expect(row.doNotCall, isTrue);
  });
}
