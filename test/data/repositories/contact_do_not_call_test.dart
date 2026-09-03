import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/balance_local_ds.dart';
import 'package:daftar/data/datasources/local/contact_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/datasources/local/transaction_local_ds.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/repositories/contact_repository_impl.dart';
import 'package:daftar/data/repositories/contact_search_index_utils.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  late AppDatabase database;
  late ContactRepositoryImpl contactRepository;
  const ledgerId = 'ledger-dnc-test';
  const contactId = 'contact-dnc-test';

  setUp(() async {
    DeviceIdentity.initializeForTest('contact-dnc-test-device');
    database = AppDatabase(NativeDatabase.memory());
    contactRepository = ContactRepositoryImpl(
      contactLocalDataSource: ContactLocalDataSource(database),
      transactionLocalDataSource: TransactionLocalDataSource(database),
      balanceLocalDataSource: BalanceLocalDataSource(database),
      auditLogLocalDataSource: AuditLogLocalDataSource(database),
    );
    final now = DateTime.utc(2026, 9, 3);
    await database.into(database.ledgers).insert(
      LedgersCompanion.insert(
        id: ledgerId,
        name: 'Test ledger',
        type: LedgerType.customers,
        icon: 'store',
        color: '#1565C0',
        sortOrder: 0,
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await database.into(database.contacts).insert(
      ContactModel(
        id: contactId,
        ledgerId: ledgerId,
        name: 'DNC contact',
        phone: '+15555550100',
        notes: null,
        creditLimit: null,
        creditCurrency: null,
        avatarColor: '#1565C0',
        createdAt: now,
        updatedAt: now,
        doNotCall: true,
      ).toDrift(),
    );
    await upsertContactSearchIndex(database, contactId, 'DNC contact');
  });

  tearDown(() async {
    await database.close();
  });

  test('name-only update preserves doNotCall', () async {
    final renamed = await contactRepository
        .update(
          const UpdateContactParams(
            id: contactId,
            name: 'Renamed only',
          ),
        )
        .then((either) => either.getOrElse((failure) => throw failure));

    expect(renamed.name, 'Renamed only');
    expect(renamed.doNotCall, isTrue);
  });
}
