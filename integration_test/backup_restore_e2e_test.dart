import 'dart:io';

import 'package:daftar/bootstrap.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/env/env.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/backup_metadata.dart' as domain;
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/main.dart' as app_main;
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('backup restore round-trip preserves data', (tester) async {
    expect(Env.backupAesKey, isNotEmpty);

    final tempRoot = await getTemporaryDirectory();
    final testDocumentsDirectory = await Directory(
      p.join(
        tempRoot.path,
        'backup_restore_e2e_${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);

    final testDatabase = db.AppDatabase(
      NativeDatabase.createInBackground(
        File(p.join(testDocumentsDirectory.path, 'daftar.sqlite')),
      ),
    );

    app_main.activeDatabase = testDatabase;

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => app_main.activeDatabase),
        appDocumentsDirectoryProvider.overrideWith(
          (ref) => testDocumentsDirectory,
        ),
        backupPublicExportEnabledProvider.overrideWith((ref) => false),
      ],
    );
    addTearDown(container.dispose);

    app_main.appContainer = container;

    final backupSubscription = container.listen(
      backupProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(backupSubscription.close);

    await _waitUntil(() => !container.read(backupProvider).isLoading);

    final ledgerUseCase = container.read(createLedgerUseCaseProvider);
    final contactUseCase = container.read(createContactUseCaseProvider);
    final transactionUseCase = container.read(addTransactionUseCaseProvider);
    final backupNotifier = container.read(backupProvider.notifier);

    final ledger = await _expectRight(
      ledgerUseCase.execute(
        name: 'E2E Ledger',
        type: LedgerType.custom,
        icon: 'ledger',
        color: 0xFF1565C0,
      ),
    );

    final contact = await _expectRight(
      contactUseCase.execute(
        ledgerId: ledger.id,
        name: 'E2E Contact',
        phone: '+967777777777',
        notes: 'Seed note',
        creditLimit: 5000,
        creditCurrency: DbConstants.currencyYer,
        avatarColor: '#FF9800',
      ),
    );

    final seededTransaction = await _expectRight(
      transactionUseCase.execute(
        contactId: contact.id,
        type: TransactionType.debt,
        amount: 1250,
        currency: DbConstants.currencyYer,
        description: 'Seed debt',
        itemName: 'Flour',
        transactionDate: DateTime.utc(2026, 1, 2, 3, 4, 5),
      ),
    );

    final seededLedger = await _expectRight(
      container.read(ledgerRepositoryProvider).getById(ledger.id),
    );
    final seededContact = await _expectRight(
      container.read(contactRepositoryProvider).getById(contact.id),
    );
    final seededTransactions = await _expectRight(
      container.read(transactionRepositoryProvider).getByContact(contact.id),
    );

    expect(seededLedger.id, ledger.id);
    expect(seededContact.id, contact.id);
    expect(seededTransactions, hasLength(1));
    expect(seededTransactions.single.id, seededTransaction.transaction.id);

    final backupCreated = await backupNotifier.createBackup();
    expect(backupCreated, isTrue);

    final backupState = container.read(backupProvider);
    expect(backupState.backups, isNotEmpty);
    final backupMetadata = backupState.backups.first;
    final backupFile = File(backupMetadata.filePath);
    expect(backupFile.existsSync(), isTrue);

    final cachedMetadata = List<domain.BackupMetadata>.of(backupState.backups);

    await testDatabase.close();
    await _deleteIfExists(
      File(p.join(testDocumentsDirectory.path, 'daftar.sqlite')),
    );
    await _deleteIfExists(
      File(p.join(testDocumentsDirectory.path, 'daftar.sqlite-wal')),
    );
    await _deleteIfExists(
      File(p.join(testDocumentsDirectory.path, 'daftar.sqlite-shm')),
    );

    final wipedDb = await openDatabase(
      documentsDirectory: testDocumentsDirectory,
    );
    final wipedLedgers = await wipedDb.select(wipedDb.ledgers).get();
    final wipedContacts = await wipedDb.select(wipedDb.contacts).get();
    final wipedTransactions = await wipedDb.select(wipedDb.transactions).get();
    expect(wipedLedgers, isEmpty);
    expect(wipedContacts, isEmpty);
    expect(wipedTransactions, isEmpty);
    await wipedDb.close();

    final restoreSucceeded = await backupNotifier.restoreBackup(
      backupFile,
      backupMetadata.checksum,
    );
    expect(restoreSucceeded, isTrue);

    await backupNotifier.softRestart(cachedMetadata);
    await _waitUntil(() => !container.read(backupProvider).isLoading);

    final restoredDb = container.read(appDatabaseProvider);
    final restoredLedgers = await restoredDb.select(restoredDb.ledgers).get();
    final restoredContacts = await restoredDb.select(restoredDb.contacts).get();
    final restoredTransactions = await restoredDb
        .select(restoredDb.transactions)
        .get();

    expect(restoredLedgers, hasLength(1));
    expect(restoredLedgers.single.name, 'E2E Ledger');
    expect(restoredContacts, hasLength(1));
    expect(restoredContacts.single.name, 'E2E Contact');
    expect(restoredTransactions, hasLength(1));
    expect(restoredTransactions.single.amount, 1250);
    expect(restoredTransactions.single.itemName, 'Flour');

    final restoredBackupState = container.read(backupProvider);
    expect(restoredBackupState.isRestoring, isFalse);
    expect(restoredBackupState.backups, isNotEmpty);
  });
}

Future<T> _expectRight<T>(Future<Either<Failure, T>> future) async {
  final result = await future;
  return result.fold(
    (failure) => fail('Expected Right but got Left(${failure.message})'),
    (value) => value,
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for test condition to become true.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _deleteIfExists(File file) async {
  if (file.existsSync()) {
    file.deleteSync();
  }
}
