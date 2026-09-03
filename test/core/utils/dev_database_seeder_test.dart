import 'package:daftar/application/contact/compute_fifo_contact_aging.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/utils/demo_seed_emails.dart';
import 'package:daftar/core/utils/demo_seed_report.dart';
import 'package:daftar/core/utils/demo_seed_us_did.dart';
import 'package:daftar/core/utils/demo_store_seeder.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/ledger_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/domain/constants/contact_email.dart';
import 'package:daftar/domain/constants/dual_rail_split.dart';
import 'package:daftar/domain/constants/j10_calle_regions.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/phone_number.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'seedPerformanceTransactions inserts count and updates balances',
    () async {
      final ledgerId = UuidUtil.generate();
      final contactId = UuidUtil.generate();
      final now = DateTime.utc(2026, 6, 17);

      await database
          .into(database.ledgers)
          .insert(
            LedgerModel(
              id: ledgerId,
              name: 'Perf Ledger',
              type: LedgerType.custom,
              icon: 'ledger',
              color: '#000000',
              sortOrder: 0,
              createdAt: now,
              updatedAt: now,
            ).toDrift(),
          );
      await database
          .into(database.contacts)
          .insert(
            ContactModel(
              id: contactId,
              ledgerId: ledgerId,
              name: 'Perf Contact',
              phone: null,
              notes: null,
              creditLimit: null,
              creditCurrency: null,
              avatarColor: '#123456',
              createdAt: now,
              updatedAt: now,
            ).toDrift(),
          );

      final result = await DemoStoreSeeder.seedPerformanceTransactions(
        database,
        contactId: contactId,
      );

      expect(result, isNotNull);
      expect(result!.count, 1000);
      expect(result.contactName, 'Perf Contact');

      final txnCount = await (database.select(
        database.transactions,
      )..where((table) => table.contactId.equals(contactId))).get();
      expect(txnCount.length, 1000);

      final balance = await (database.select(
        database.contactBalances,
      )..where((table) => table.contactId.equals(contactId))).getSingle();
      expect(balance.totalDebt, greaterThan(0));
      expect(balance.totalPayment, greaterThan(0));

      final auditRows = await database.select(database.auditLogs).get();
      expect(auditRows.any((row) => row.action == 'PERF_SEED'), isTrue);
    },
  );

  group('seedData sample store', () {
    final now = DateTime.utc(2026, 8, 16, 12);

    Future<DemoSeedReport> seedEn() => DemoStoreSeeder.seedData(
      database,
      now: now,
      localeOverride: 'en',
    );

    test('seeds 7 contacts with desk-eligible overdue emails', () async {
      final report = await seedEn();

      final contacts = await database.select(database.contacts).get();
      expect(contacts, hasLength(DemoStoreSeeder.demoContactCount));

      final ledgers = await database.select(database.ledgers).get();
      expect(ledgers, hasLength(1));
      expect(ledgers.single.name, 'Customers');

      final mohameds = contacts.where(
        (row) => row.name == DemoStoreSeeder.mohamedNameEn,
      );
      expect(mohameds, hasLength(1));

      for (var i = 0; i < contacts.length; i++) {
        final contact = contacts[i];
        expect(contact.phone, isNotNull, reason: contact.name);
        final phone = PhoneNumber(contact.phone!);
        expect(phone.isValid, isTrue, reason: contact.name);
        expect(phone.e164, isNotNull, reason: contact.name);
        expect(
          J10CalleRegions.callingRegion(phone.e164!),
          'YE',
          reason: contact.name,
        );
        expect(
          contact.phone,
          DemoSeedUsDid.yemenPlaceholder(i),
          reason: contact.name,
        );
        expect(contact.doNotCall, isFalse, reason: contact.name);
        final email = contact.email?.trim() ?? '';
        expect(email, isNotEmpty, reason: contact.name);
        expect(ContactEmail.isValid(email), isTrue, reason: contact.name);
        expect(email, DemoSeedEmails.forIndex(i), reason: contact.name);
        final balances = await (database.select(
          database.contactBalances,
        )..where((table) => table.contactId.equals(contact.id))).get();
        expect(
          balances.any((row) => row.netBalance < 0),
          isTrue,
          reason: contact.name,
        );
        expect(
          balances.every(
            (row) => row.currencyCode == DemoStoreSeeder.demoCurrencyCode,
          ),
          isTrue,
          reason: contact.name,
        );
      }

      expect(report.contactCount, 7);
      expect(report.pdfCount, 5);
      expect(report.textOnlyCount, 2);
    });

    test('Mohamed uses US DID override; others stay Yemen', () async {
      const usFixture = '+15555550100';
      await DemoStoreSeeder.seedData(
        database,
        now: now,
        localeOverride: 'en',
        callEligibleE164: usFixture,
      );

      final contacts = await database.select(database.contacts).get();
      final mohamed = contacts.singleWhere(
        (row) => row.name == DemoStoreSeeder.mohamedNameEn,
      );
      expect(mohamed.phone, usFixture);

      final others = contacts.where(
        (row) => row.name != DemoStoreSeeder.mohamedNameEn,
      );
      for (final contact in others) {
        final phone = PhoneNumber(contact.phone!);
        expect(J10CalleRegions.callingRegion(phone.e164!), 'YE');
      }
    });

    test('invalid US DID override falls back to Yemen for Mohamed', () async {
      await DemoStoreSeeder.seedData(
        database,
        now: now,
        localeOverride: 'en',
        callEligibleE164: '0771234567',
      );

      final mohamed = (await database.select(database.contacts).get())
          .singleWhere((row) => row.name == DemoStoreSeeder.mohamedNameEn);
      expect(mohamed.phone, DemoSeedUsDid.yemenPlaceholder(0));
    });

    test('dual rail: US Mohamed is both; Yemen contacts callUnavailable', () async {
      const usFixture = '+15555550100';
      await DemoStoreSeeder.seedData(
        database,
        now: now,
        localeOverride: 'en',
        callEligibleE164: usFixture,
      );

      final contacts = await database.select(database.contacts).get();
      final ranked = <CollectionsCandidate>[];
      for (final contact in contacts) {
        final rows = await (database.select(
          database.transactions,
        )..where((table) => table.contactId.equals(contact.id))).get();
        final aging = computeFifoContactAging(
          transactions: [
            for (final row in rows) TransactionModel.fromDrift(row).toDomain(),
          ],
          currencyCode: DemoStoreSeeder.demoCurrencyCode,
          asOf: now,
        );
        final balance = await (database.select(
          database.contactBalances,
        )..where((table) => table.contactId.equals(contact.id))).getSingle();
        ranked.add(
          CollectionsCandidate(
            contactId: contact.id,
            name: contact.name,
            phone: contact.phone,
            email: contact.email,
            ledgerId: contact.ledgerId,
            netBalance: balance.netBalance,
            currencyCode: DemoStoreSeeder.demoCurrencyCode,
            ageDays: aging!.ageDays,
            toneBand: aging.toneBand,
            daysSinceLastPayment: aging.daysSinceLastPayment,
            daysSinceLastDebt: aging.daysSinceLastDebt,
            doNotCall: contact.doNotCall,
          ),
        );
      }
      ranked.sort((left, right) {
        final byAge = right.ageDays.compareTo(left.ageDays);
        if (byAge != 0) {
          return byAge;
        }
        return right.netBalance.abs().compareTo(left.netBalance.abs());
      });

      final split = DualRailSplit.split(
        ranked: ranked,
        allowlistRegion: 'US',
        allowlist: {usFixture},
      );

      final mohamed = split.ranked.singleWhere(
        (row) => row.name == DemoStoreSeeder.mohamedNameEn,
      );
      expect(mohamed.rail, OutreachRail.both);
      expect(split.callSet, contains(mohamed));

      final yeContacts = split.ranked.where(
        (row) => row.name != DemoStoreSeeder.mohamedNameEn,
      );
      expect(yeContacts, hasLength(6));
      for (final row in yeContacts) {
        expect(row.rail, OutreachRail.callUnavailable);
        expect(split.emailSet, contains(row));
        expect(split.callSet, isNot(contains(row)));
      }
    });

    test('Arabic locale uses Arabic names and ledger label', () async {
      await DemoStoreSeeder.seedData(
        database,
        now: now,
        localeOverride: 'ar',
      );

      final ledgers = await database.select(database.ledgers).get();
      expect(ledgers.single.name, 'الزبائن');

      final contacts = await database.select(database.contacts).get();
      expect(
        contacts.singleWhere((row) => row.name == DemoStoreSeeder.mohamedNameAr),
        isNotNull,
      );
    });

    test(
      'aging mix includes friendly, reminder, firm, and recent-payer cap',
      () async {
        await seedEn();

        final contacts = await database.select(database.contacts).get();
        final bands = <String, ReminderToneBand>{};
        for (final contact in contacts) {
          final rows = await (database.select(
            database.transactions,
          )..where((table) => table.contactId.equals(contact.id))).get();
          final aging = computeFifoContactAging(
            transactions: [
              for (final row in rows)
                TransactionModel.fromDrift(row).toDomain(),
            ],
            currencyCode: DemoStoreSeeder.demoCurrencyCode,
            asOf: now,
          );
          if (aging != null) {
            bands[contact.name] = aging.toneBand;
          }
        }

        expect(bands['Nadia'], ReminderToneBand.reminder);
        expect(bands['Salem'], ReminderToneBand.firm);
        expect(bands['Mohamed'], ReminderToneBand.firm);
        expect(bands['Yousef'], ReminderToneBand.friendly);

        expect(
          bands.values
              .where((band) => band == ReminderToneBand.friendly)
              .length,
          greaterThanOrEqualTo(1),
        );
        expect(
          bands.values
              .where((band) => band == ReminderToneBand.reminder)
              .length,
          greaterThanOrEqualTo(1),
        );
        expect(
          bands.values.where((band) => band == ReminderToneBand.firm).length,
          greaterThanOrEqualTo(3),
        );
      },
    );

    test('today createdAt strip is two rows across contacts', () async {
      await seedEn();

      final all = await database.select(database.transactions).get();
      final today = all
          .where(
            (row) => row.createdAt.toUtc().isAtSameMomentAs(now.toUtc()),
          )
          .toList();
      expect(today, hasLength(DemoStoreSeeder.demoTodayTransactionCount));
      expect(all.length, greaterThan(today.length));
    });

    test('debts use itemName for goods and invoice-style notes', () async {
      await seedEn();

      final contacts = await database.select(database.contacts).get();
      for (final contact in contacts) {
        final rows = await (database.select(
          database.transactions,
        )..where((table) => table.contactId.equals(contact.id))).get();
        expect(rows.length, greaterThanOrEqualTo(3), reason: contact.name);
        expect(
          rows.any(
            (row) => TransactionModel.fromDrift(row).type == TransactionType.payment,
          ),
          isTrue,
          reason: contact.name,
        );

        for (final row in rows) {
          final txn = TransactionModel.fromDrift(row);
          expect(txn.itemName, isNotNull, reason: contact.name);
          expect(txn.itemName!.trim(), isNotEmpty, reason: contact.name);
          if (txn.type == TransactionType.debt) {
            expect(txn.description, isNotNull, reason: contact.name);
            expect(txn.description!.contains('INV-'), isTrue, reason: contact.name);
            expect(txn.description, isNot(txn.itemName), reason: contact.name);
          }
        }
      }
    });

    test('collections rank keeps Omar and Yousef as text-only tail', () async {
      await seedEn();

      final contacts = await database.select(database.contacts).get();
      final ranked = <({String name, int ageDays, int owed})>[];
      for (final contact in contacts) {
        final rows = await (database.select(
          database.transactions,
        )..where((table) => table.contactId.equals(contact.id))).get();
        final aging = computeFifoContactAging(
          transactions: [
            for (final row in rows) TransactionModel.fromDrift(row).toDomain(),
          ],
          currencyCode: DemoStoreSeeder.demoCurrencyCode,
          asOf: now,
        );
        final balance = await (database.select(
          database.contactBalances,
        )..where((table) => table.contactId.equals(contact.id))).getSingle();
        ranked.add((
          name: contact.name,
          ageDays: aging!.ageDays,
          owed: -balance.netBalance,
        ));
      }
      ranked.sort((left, right) {
        final byAge = right.ageDays.compareTo(left.ageDays);
        if (byAge != 0) {
          return byAge;
        }
        return right.owed.compareTo(left.owed);
      });

      expect(
        ranked.take(5).map((row) => row.name).toList(),
        ['Mohamed', 'Ahmed', 'Nadia', 'Salem', 'Layla'],
      );
      expect(
        ranked.skip(5).map((row) => row.name).toList(),
        ['Omar', 'Yousef'],
      );
    });

    test('preserves store name and Drive ids without flipping locale', () async {
      await (database.update(
        database.appSettingsTable,
      )..where((row) => row.id.equals(DbConstants.appSettingsId))).write(
        const AppSettingsTableCompanion(
          locale: Value('en'),
          hasSeenOnboarding: Value(false),
          demoArchitectureHud: Value(false),
          googleAccountId: Value('drive-user'),
          googleAccountEmail: Value('akrm.codes@gmail.com'),
        ),
      );
      await database
          .into(database.merchantProfiles)
          .insert(
            MerchantProfilesCompanion.insert(
              id: UuidUtil.generate(),
              storeName: 'My Shop',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final report = await DemoStoreSeeder.seedData(
        database,
        now: now,
        localeOverride: 'en',
      );

      final settings = await database
          .select(database.appSettingsTable)
          .getSingle();
      expect(settings.locale, 'en');
      expect(settings.defaultCurrency, DemoStoreSeeder.demoCurrencyCode);
      expect(settings.isMultiCurrencyEnabled, isFalse);
      expect(settings.hasSeenOnboarding, isFalse);
      expect(settings.demoArchitectureHud, isFalse);
      expect(settings.googleAccountId, 'drive-user');
      expect(settings.googleAccountEmail, 'akrm.codes@gmail.com');

      final profile = await database
          .select(database.merchantProfiles)
          .getSingle();
      expect(profile.storeName, 'My Shop');
      expect(report.storeNameKept, isTrue);
    });

    test('sets USD as default currency for the sample store', () async {
      await (database.update(
        database.appSettingsTable,
      )..where((row) => row.id.equals(DbConstants.appSettingsId))).write(
        const AppSettingsTableCompanion(
          defaultCurrency: Value(DbConstants.currencyYer),
          isMultiCurrencyEnabled: Value(true),
        ),
      );

      await seedEn();

      final settings = await database
          .select(database.appSettingsTable)
          .getSingle();
      expect(settings.defaultCurrency, DemoStoreSeeder.demoCurrencyCode);
      expect(settings.isMultiCurrencyEnabled, isFalse);

      final txns = await database.select(database.transactions).get();
      expect(
        txns.every(
          (row) => row.currency == DemoStoreSeeder.demoCurrencyCode,
        ),
        isTrue,
      );
    });

    test('generates neutral store name when empty', () async {
      final report = await seedEn();

      final profile = await database
          .select(database.merchantProfiles)
          .getSingle();
      expect(profile.storeName, DemoStoreSeeder.generatedStoreNameEn);
      expect(report.storeNameKept, isFalse);
    });
  });
}
