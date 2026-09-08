import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/utils/demo_seed_emails.dart';
import 'package:daftar/core/utils/demo_seed_report.dart';
import 'package:daftar/core/utils/demo_seed_us_did.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/ledger_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/data/repositories/balance_calculator.dart';
import 'package:daftar/data/repositories/contact_search_index_utils.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

/// Production-safe sample-store seeder for contest evaluators and onboarding.
///
/// Wipes ledgers/contacts/transactions (not merchant profile OAuth ids), seeds
/// seven overdue USD contacts with ranked aging for Collections Desk, and
/// preserves a non-empty store name.
class DemoStoreSeeder {
  DemoStoreSeeder(this._database);

  final AppDatabase _database;

  static const String generatedStoreNameEn = 'Sample Store';
  static const String generatedStoreNameAr = 'متجر نموذجي';

  static const String mohamedNameEn = 'Mohamed';
  static const String mohamedNameAr = 'محمد';

  /// Total contacts after [seedData].
  static const int demoContactCount = DemoSeedEmails.contactCount;

  /// Transactions whose `createdAt` is the seed clock (closing summary strip).
  static const int demoTodayTransactionCount = 2;

  /// Sample-store transactions use USD (minor units = cents).
  static const String demoCurrencyCode = DbConstants.currencyUsd;

  /// Mid-day capture target in English locale.
  static const String demoMohamedNameEn = mohamedNameEn;

  /// Mid-day capture target in Arabic locale.
  static const String demoMohamedNameAr = mohamedNameAr;

  static String mohamedNameForLocale(String locale) {
    return _isArabic(locale) ? mohamedNameAr : mohamedNameEn;
  }

  static String generatedStoreNameForLocale(String locale) {
    return _isArabic(locale) ? generatedStoreNameAr : generatedStoreNameEn;
  }

  /// Wipes user workspace data (ledgers, contacts, transactions, balances).
  static Future<void> clearData(AppDatabase database) async {
    if (!kDebugMode) {
      return;
    }
    await DemoStoreSeeder(database)._clearWorkspace();
  }

  /// Clears workspace data then seeds the sample store fixture.
  ///
  /// [callEligibleE164] overrides the compile-time `DAFTAR_SEED_US_DID` for
  /// Mohamed (index 0). When unset/invalid, Mohamed uses a Yemen placeholder.
  static Future<DemoSeedReport> seedData(
    AppDatabase database, {
    DateTime? now,
    String? localeOverride,
    String? draftStoreName,
    String? callEligibleE164,
  }) async {
    final seeder = DemoStoreSeeder(database);
    final clock = now ?? DateTime.now().toUtc();
    final locale = _normalizeLocale(
      localeOverride ?? await seeder._readLocale(),
    );
    final keptStoreName = await seeder._resolveStoreNameToKeep(draftStoreName);
    final mohamedPhone =
        DemoSeedUsDid.resolve(override: callEligibleE164) ??
        DemoSeedUsDid.yemenPlaceholder(0);

    await seeder._clearWorkspace();
    await seeder._seedWorkspace(
      clock,
      locale: locale,
      keptStoreName: keptStoreName,
      mohamedPhone: mohamedPhone,
    );

    return seeder._buildReport(
      locale: locale,
      keptStoreName: keptStoreName,
      clock: clock,
    );
  }

  static Future<({int count, String contactName})?> seedPerformanceTransactions(
    AppDatabase database, {
    String? contactId,
    int count = 1000,
  }) async {
    if (!kDebugMode) {
      return null;
    }
    final seeder = DemoStoreSeeder(database);
    return seeder._seedPerformanceTransactions(
      count: count,
      contactId: contactId,
    );
  }

  static bool _isArabic(String locale) =>
      locale.toLowerCase().startsWith('ar');

  static String _normalizeLocale(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.startsWith('ar')) {
      return 'ar';
    }
    return 'en';
  }

  Future<String> _readLocale() async {
    final settings = await (_database.select(
      _database.appSettingsTable,
    )..where((row) => row.id.equals(DbConstants.appSettingsId))).getSingleOrNull();
    return settings?.locale ?? DbConstants.defaultLocale;
  }

  Future<String?> _resolveStoreNameToKeep(String? draftStoreName) async {
    final draft = draftStoreName?.trim() ?? '';
    if (draft.isNotEmpty) {
      return draft;
    }
    final profile = await (_database.select(
      _database.merchantProfiles,
    )..limit(1)).getSingleOrNull();
    final persisted = profile?.storeName.trim() ?? '';
    if (persisted.isNotEmpty) {
      return persisted;
    }
    return null;
  }

  Future<void> _clearWorkspace() async {
    await _database.transaction(() async {
      await _database.delete(_database.collectionsSendQueueItemRows).go();
      await _database.delete(_database.collectionsSendQueueHeaders).go();
      await _database.delete(_database.agentTurns).go();
      await _database.delete(_database.agentOutboxRows).go();
      await _database.delete(_database.agentSessions).go();
      await _database.delete(_database.dayJournalEntries).go();
      await _database.customStatement('DELETE FROM contact_fts');
      await _database.delete(_database.contactBalances).go();
      await _database.delete(_database.transactions).go();
      await _database.delete(_database.contacts).go();
      await _database.delete(_database.ledgers).go();
      await _database.delete(_database.auditLogs).go();
    });
  }

  Future<void> _seedWorkspace(
    DateTime now, {
    required String locale,
    required String? keptStoreName,
    required String mohamedPhone,
  }) async {
    final ledger = _buildLedger(now, locale);
    final contacts = _buildContacts(
      ledger.id,
      now,
      locale,
      mohamedPhone: mohamedPhone,
    );
    final transactions = _buildTransactions(contacts, now, locale);

    await _database.transaction(() async {
      await _database.into(_database.ledgers).insert(ledger.toDrift());
      for (final contact in contacts) {
        await _database.into(_database.contacts).insert(contact.toDrift());
        await upsertContactSearchIndex(
          _database,
          contact.id,
          contact.name,
        );
      }
      for (final transaction in transactions) {
        await _database
            .into(_database.transactions)
            .insert(transaction.toDrift());
      }
      for (final contact in contacts) {
        final contactTxns = transactions
            .where((txn) => txn.contactId == contact.id)
            .toList(growable: false);
        final balances = calculateContactBalances(
          contactId: contact.id,
          transactions: contactTxns,
          lastUpdatedAt: now,
        );
        for (final balance in balances) {
          await _database
              .into(_database.contactBalances)
              .insertOnConflictUpdate(balance.toDrift());
        }
      }
      await _upsertStoreName(now, locale, keptStoreName);
      await _upsertDemoCurrency(now);
    });
  }

  Future<void> _upsertDemoCurrency(DateTime now) async {
    await (_database.update(
      _database.appSettingsTable,
    )..where((row) => row.id.equals(DbConstants.appSettingsId))).write(
      const AppSettingsTableCompanion(
        defaultCurrency: Value(demoCurrencyCode),
        isMultiCurrencyEnabled: Value(false),
        calleAllowDial: Value(kDebugMode),
      ),
    );
  }

  Future<void> _upsertStoreName(
    DateTime now,
    String locale,
    String? keptStoreName,
  ) async {
    final resolvedName = keptStoreName ?? generatedStoreNameForLocale(locale);
    final existing = await (_database.select(
      _database.merchantProfiles,
    )..limit(1)).getSingleOrNull();
    if (existing != null) {
      await (_database.update(
        _database.merchantProfiles,
      )..where((row) => row.id.equals(existing.id))).write(
        MerchantProfilesCompanion(
          storeName: Value(resolvedName),
          updatedAt: Value(now),
        ),
      );
      return;
    }
    await _database
        .into(_database.merchantProfiles)
        .insert(
          MerchantProfilesCompanion.insert(
            id: UuidUtil.generate(),
            storeName: resolvedName,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<DemoSeedReport> _buildReport({
    required String locale,
    required String? keptStoreName,
    required DateTime clock,
  }) async {
    final profile = await (_database.select(
      _database.merchantProfiles,
    )..limit(1)).getSingleOrNull();
    final storeName = profile?.storeName.trim() ?? '';
    final ledger = await (_database.select(
      _database.ledgers,
    )..limit(1)).getSingleOrNull();

    final contacts = await _database.select(_database.contacts).get();

    return DemoSeedReport(
      storeName: storeName,
      storeNameKept: keptStoreName != null,
      locale: locale,
      ledgerName: ledger?.name ?? '',
      contactCount: contacts.length,
      pdfCount: 5,
      textOnlyCount: 2,
      hasFriendlyTone: true,
      hasReminderTone: true,
      hasFirmTone: true,
    );
  }

  Future<({int count, String contactName})?> _seedPerformanceTransactions({
    required int count,
    String? contactId,
  }) async {
    final contactQuery = _database.select(_database.contacts)
      ..where(
        (table) =>
            table.isDeleted.equals(false) & table.isArchived.equals(false),
      );
    if (contactId != null) {
      contactQuery.where((table) => table.id.equals(contactId));
    }
    contactQuery.limit(1);

    final contactRow = await contactQuery.getSingleOrNull();
    if (contactRow == null) {
      return null;
    }

    final now = DateTime.now().toUtc();
    final models = <TransactionModel>[
      for (var i = 0; i < count; i++)
        TransactionModel(
          id: UuidUtil.generate(),
          contactId: contactRow.id,
          type: i.isEven ? TransactionType.debt : TransactionType.payment,
          amount: 500 + (i % 50) * 100,
          currency: demoCurrencyCode,
          description: 'Perf seed $i',
          itemName: 'Item ${i % 12}',
          transactionDate: now.subtract(Duration(days: i % 730)),
          attachmentPath: null,
          createdAt: now.subtract(Duration(days: i % 730)),
          updatedAt: now,
        ),
    ];

    await _database.transaction(() async {
      await _database.batch((batch) {
        batch.insertAll(
          _database.transactions,
          models.map((model) => model.toDrift()).toList(growable: false),
        );
      });

      final existingTransactions =
          await (_database.select(
                _database.transactions,
              )..where(
                (table) =>
                    table.contactId.equals(contactRow.id) &
                    table.isDeleted.equals(false) &
                    table.isArchived.equals(false),
              ))
              .get();
      final allModels = existingTransactions
          .map(TransactionModel.fromDrift)
          .toList(growable: false);
      final balances = calculateContactBalances(
        contactId: contactRow.id,
        transactions: allModels,
        lastUpdatedAt: now,
      );
      for (final balance in balances) {
        await _database
            .into(_database.contactBalances)
            .insertOnConflictUpdate(balance.toDrift());
      }

      await _database
          .into(_database.auditLogs)
          .insert(
            AuditLogModel(
              id: UuidUtil.generate(),
              entityType: 'contact',
              entityId: contactRow.id,
              action: 'PERF_SEED',
              payload: 'Seeded $count performance transactions',
              timestamp: now,
              deviceId: UuidUtil.generate(),
            ).toDrift(),
          );
    });

    return (count: count, contactName: contactRow.name);
  }

  static LedgerModel _buildLedger(DateTime now, String locale) {
    final name = _isArabic(locale) ? 'الزبائن' : 'Customers';
    return LedgerModel(
      id: UuidUtil.generate(),
      name: name,
      type: LedgerType.customers,
      icon: 'storefront',
      color: '#78909C',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  static List<ContactModel> _buildContacts(
    String ledgerId,
    DateTime now,
    String locale, {
    required String mohamedPhone,
  }) {
    const avatarColors = [
      '#5C6BC0',
      '#26A69A',
      '#EF5350',
      '#AB47BC',
      '#42A5F5',
      '#FFA726',
      '#66BB6A',
    ];

    final names = _isArabic(locale)
        ? const [
            mohamedNameAr,
            'أحمد',
            'نادية',
            'سالم',
            'ليلى',
            'عمر',
            'يوسف',
          ]
        : const [
            mohamedNameEn,
            'Ahmed',
            'Nadia',
            'Salem',
            'Layla',
            'Omar',
            'Yousef',
          ];

    final notes = _isArabic(locale)
        ? const [
            'هدف التقاط منتصف اليوم',
            'دين حديث',
            'سداد حديث على رصيد قديم',
            null,
            null,
            null,
            null,
          ]
        : const [
            'Mid-day capture target',
            'Recent debt',
            'Recent payment on old balance',
            null,
            null,
            null,
            null,
          ];

    return [
      for (var i = 0; i < names.length; i++)
        ContactModel(
          id: UuidUtil.generate(),
          ledgerId: ledgerId,
          name: names[i],
          phone: i == 0 ? mohamedPhone : DemoSeedUsDid.yemenPlaceholder(i),
          email: DemoSeedEmails.forIndex(i),
          notes: notes[i],
          creditLimit: null,
          creditCurrency: null,
          avatarColor: avatarColors[i % avatarColors.length],
          createdAt: now,
          updatedAt: now,
        ),
    ];
  }

  static List<TransactionModel> _buildTransactions(
    List<ContactModel> contacts,
    DateTime now,
    String locale,
  ) {
    final isAr = _isArabic(locale);
    final paymentItem = isAr ? 'سداد' : 'Payment';
    final specs = <_TxnSpec>[
      // Mohamed — firm 55d, net $801.50, last payment >14d
      _TxnSpec(
        contactIndex: 0,
        type: TransactionType.debt,
        amount: 25_000,
        daysAgo: 70,
        itemName: isAr ? 'أسمنت' : 'Portland cement',
        description: isAr ? 'فاتورة ١٠٠١ · ٥٠ كيس' : 'INV-1001 · 50 bags',
      ),
      _TxnSpec(
        contactIndex: 0,
        type: TransactionType.debt,
        amount: 55_000,
        daysAgo: 55,
        itemName: isAr ? 'حديد تسليح' : 'Rebar',
        description: isAr ? 'فاتورة ١٠٠٢ · ٢ طن' : 'INV-1002 · 2 tons',
      ),
      _TxnSpec(
        contactIndex: 0,
        type: TransactionType.payment,
        amount: 25_000,
        daysAgo: 20,
        itemName: paymentItem,
        description: isAr
            ? 'تحويل بنكي مقابل فاتورة ١٠٠١'
            : 'Bank transfer against INV-1001',
      ),
      _TxnSpec(
        contactIndex: 0,
        type: TransactionType.debt,
        amount: 25_000,
        daysAgo: 25,
        itemName: isAr ? 'بلاط' : 'Ceramic tile',
        description: isAr ? 'فاتورة ١٠٠٣ · على الحساب' : 'INV-1003 · on account',
      ),
      _TxnSpec(
        contactIndex: 0,
        type: TransactionType.debt,
        amount: 150,
        daysAgo: 0,
        itemName: isAr ? 'ماء معدني' : 'Mineral water',
        description: isAr ? 'فاتورة ١١٠١ · توريد اليوم' : 'INV-1101 · today delivery',
        isToday: true,
      ),

      // Ahmed — firm 45d, net $600
      _TxnSpec(
        contactIndex: 1,
        type: TransactionType.debt,
        amount: 25_000,
        daysAgo: 55,
        itemName: isAr ? 'أنابيب PVC' : 'PVC pipe',
        description: isAr ? 'فاتورة ٢٠٠١ · ١٠٠ م' : 'INV-2001 · 100 m',
      ),
      _TxnSpec(
        contactIndex: 1,
        type: TransactionType.debt,
        amount: 35_000,
        daysAgo: 45,
        itemName: isAr ? 'حديد ومستلزمات' : 'Steel and supplies',
        description: isAr ? 'فاتورة ٢٠٠٢ · جملة' : 'INV-2002 · wholesale',
      ),
      _TxnSpec(
        contactIndex: 1,
        type: TransactionType.payment,
        amount: 25_000,
        daysAgo: 38,
        itemName: paymentItem,
        description: isAr
            ? 'نقداً مقابل فاتورة ٢٠٠١'
            : 'Cash against INV-2001',
      ),
      _TxnSpec(
        contactIndex: 1,
        type: TransactionType.debt,
        amount: 25_000,
        daysAgo: 30,
        itemName: isAr ? 'مفاتيح كهرباء' : 'Electrical fittings',
        description: isAr ? 'فاتورة ٢٠٠٣ · على الحساب' : 'INV-2003 · on account',
      ),

      // Nadia — reminder cap (40d open, payment 3d ago), net $80
      _TxnSpec(
        contactIndex: 2,
        type: TransactionType.debt,
        amount: 3_000,
        daysAgo: 45,
        itemName: isAr ? 'زيت طعام' : 'Cooking oil',
        description: isAr ? 'فاتورة ٣٠٠١ · ١٠ عبوات' : 'INV-3001 · 10 cartons',
      ),
      _TxnSpec(
        contactIndex: 2,
        type: TransactionType.payment,
        amount: 3_000,
        daysAgo: 20,
        itemName: paymentItem,
        description: isAr
            ? 'نقداً مقابل فاتورة ٣٠٠١'
            : 'Cash against INV-3001',
      ),
      _TxnSpec(
        contactIndex: 2,
        type: TransactionType.debt,
        amount: 10_000,
        daysAgo: 40,
        itemName: isAr ? 'توريد جملة' : 'Bulk supply',
        description: isAr ? 'فاتورة ٣٠٠٢ · بقالة' : 'INV-3002 · groceries',
      ),
      _TxnSpec(
        contactIndex: 2,
        type: TransactionType.payment,
        amount: 2_000,
        daysAgo: 3,
        itemName: paymentItem,
        description: isAr
            ? 'سداد جزئي · فاتورة ٣٠٠٢'
            : 'Partial payment · INV-3002',
      ),

      // Salem — firm 35d, net $400
      _TxnSpec(
        contactIndex: 3,
        type: TransactionType.debt,
        amount: 10_000,
        daysAgo: 50,
        itemName: isAr ? 'دهان' : 'Paint',
        description: isAr ? 'فاتورة ٤٠٠١ · ٢٠ علبة' : 'INV-4001 · 20 cans',
      ),
      _TxnSpec(
        contactIndex: 3,
        type: TransactionType.payment,
        amount: 10_000,
        daysAgo: 40,
        itemName: paymentItem,
        description: isAr
            ? 'تحويل بنكي مقابل فاتورة ٤٠٠١'
            : 'Bank transfer against INV-4001',
      ),
      _TxnSpec(
        contactIndex: 3,
        type: TransactionType.debt,
        amount: 40_000,
        daysAgo: 35,
        itemName: isAr ? 'مواد بناء' : 'Building materials',
        description: isAr ? 'فاتورة ٤٠٠٢ · على الحساب' : 'INV-4002 · on account',
      ),

      // Layla — firm 31d, net $350
      _TxnSpec(
        contactIndex: 4,
        type: TransactionType.debt,
        amount: 8_000,
        daysAgo: 45,
        itemName: isAr ? 'خيوط' : 'Thread',
        description: isAr ? 'فاتورة ٥٠٠١ · جملة' : 'INV-5001 · wholesale',
      ),
      _TxnSpec(
        contactIndex: 4,
        type: TransactionType.payment,
        amount: 8_000,
        daysAgo: 38,
        itemName: paymentItem,
        description: isAr
            ? 'نقداً مقابل فاتورة ٥٠٠١'
            : 'Cash against INV-5001',
      ),
      _TxnSpec(
        contactIndex: 4,
        type: TransactionType.debt,
        amount: 35_000,
        daysAgo: 31,
        itemName: isAr ? 'أقمشة قطن' : 'Cotton bolts',
        description: isAr ? 'فاتورة ٥٠٠٢ · ١٥ لفة' : 'INV-5002 · 15 bolts',
      ),

      // Omar — reminder 12d, net $150 (older invoices FIFO-cleared)
      _TxnSpec(
        contactIndex: 5,
        type: TransactionType.debt,
        amount: 20_000,
        daysAgo: 60,
        itemName: isAr ? 'أرز' : 'Rice',
        description: isAr ? 'فاتورة ٦٠٠١ · ٢٠ كيس' : 'INV-6001 · 20 sacks',
      ),
      _TxnSpec(
        contactIndex: 5,
        type: TransactionType.payment,
        amount: 20_000,
        daysAgo: 55,
        itemName: paymentItem,
        description: isAr
            ? 'نقداً مقابل فاتورة ٦٠٠١'
            : 'Cash against INV-6001',
      ),
      _TxnSpec(
        contactIndex: 5,
        type: TransactionType.debt,
        amount: 18_000,
        daysAgo: 45,
        itemName: isAr ? 'سكر' : 'Sugar',
        description: isAr ? 'فاتورة ٦٠٠٢ · جملة' : 'INV-6002 · wholesale',
      ),
      _TxnSpec(
        contactIndex: 5,
        type: TransactionType.payment,
        amount: 18_000,
        daysAgo: 42,
        itemName: paymentItem,
        description: isAr
            ? 'تحويل بنكي مقابل فاتورة ٦٠٠٢'
            : 'Bank transfer against INV-6002',
      ),
      _TxnSpec(
        contactIndex: 5,
        type: TransactionType.debt,
        amount: 15_000,
        daysAgo: 12,
        itemName: isAr ? 'بقالة أسبوعية' : 'Weekly groceries',
        description: isAr ? 'فاتورة ٦٠٠٣ · على الحساب' : 'INV-6003 · on account',
      ),

      // Yousef — friendly 4d, net $37, today strip
      _TxnSpec(
        contactIndex: 6,
        type: TransactionType.debt,
        amount: 5_000,
        daysAgo: 25,
        itemName: isAr ? 'خبز' : 'Bread',
        description: isAr ? 'فاتورة ٧٠٠١ · توريد يومي' : 'INV-7001 · daily supply',
      ),
      _TxnSpec(
        contactIndex: 6,
        type: TransactionType.payment,
        amount: 5_000,
        daysAgo: 20,
        itemName: paymentItem,
        description: isAr
            ? 'نقداً مقابل فاتورة ٧٠٠١'
            : 'Cash against INV-7001',
      ),
      _TxnSpec(
        contactIndex: 6,
        type: TransactionType.debt,
        amount: 3_500,
        daysAgo: 4,
        itemName: isAr ? 'مشتريات يومية' : 'Daily purchases',
        description: isAr ? 'فاتورة ٧٠٠٢ · على الحساب' : 'INV-7002 · on account',
      ),
      _TxnSpec(
        contactIndex: 6,
        type: TransactionType.debt,
        amount: 200,
        daysAgo: 0,
        itemName: isAr ? 'بيض' : 'Eggs',
        description: isAr ? 'فاتورة ٧١٠١ · توريد اليوم' : 'INV-7101 · today delivery',
        isToday: true,
      ),
    ];

    return [
      for (final spec in specs)
        TransactionModel(
          id: UuidUtil.generate(),
          contactId: contacts[spec.contactIndex].id,
          type: spec.type,
          amount: spec.amount,
          currency: demoCurrencyCode,
          description: spec.description,
          itemName: spec.itemName,
          transactionDate: spec.isToday
              ? now
              : now.subtract(Duration(days: spec.daysAgo)),
          attachmentPath: null,
          createdAt: spec.isToday
              ? now
              : now.subtract(Duration(days: spec.daysAgo)),
          updatedAt: now,
        ),
    ];
  }
}

class _TxnSpec {
  const _TxnSpec({
    required this.contactIndex,
    required this.type,
    required this.amount,
    required this.daysAgo,
    required this.itemName,
    this.description,
    this.isToday = false,
  });

  final int contactIndex;
  final TransactionType type;
  final int amount;
  final int daysAgo;
  final String itemName;
  final String? description;
  final bool isToday;
}
