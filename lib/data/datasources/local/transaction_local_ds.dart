import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/transaction_mapper.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:drift/drift.dart' as drift;

typedef RecentItemSuggestionRow = ({String itemName, int lastAmount});

/// Local data source for transaction persistence.
class TransactionLocalDataSource {
  /// Creates a transaction local data source.
  TransactionLocalDataSource(this.database);

  /// Drift database dependency.
  final db.AppDatabase database;

  /// Creates a transaction row.
  Future<TransactionModel> createTransaction(
    TransactionModel transaction,
  ) async {
    await database.into(database.transactions).insert(transaction.toDrift());

    final saved = await getTransactionById(transaction.id);
    if (saved == null) {
      throw StateError('Transaction not found after insert: ${transaction.id}');
    }

    return saved;
  }

  /// Updates an existing transaction row.
  Future<TransactionModel> updateTransaction(
    TransactionModel transaction,
  ) async {
    final updatedRows =
        await (database.update(database.transactions)
              ..where((table) => table.id.equals(transaction.id)))
            .write(transaction.toCompanion());

    if (updatedRows == 0) {
      throw StateError('Transaction not found: ${transaction.id}');
    }

    return transaction;
  }

  /// Soft-deletes a transaction row.
  Future<TransactionModel> deleteTransaction(String transactionId) async {
    final existing = await getTransactionById(transactionId);
    if (existing == null) {
      throw StateError('Transaction not found: $transactionId');
    }

    final deleted = TransactionModel(
      id: existing.id,
      contactId: existing.contactId,
      type: existing.type,
      amount: existing.amount,
      currency: existing.currency,
      description: existing.description,
      itemName: existing.itemName,
      transactionDate: existing.transactionDate,
      attachmentPath: existing.attachmentPath,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().toUtc(),
      isDeleted: true,
      syncVersion: existing.syncVersion + 1,
    );

    await updateTransaction(deleted);
    return deleted;
  }

  Future<int> bulkSoftDeleteTransactionsByContactIds(
    List<String> contactIds, {
    required DateTime updatedAt,
  }) async {
    if (contactIds.isEmpty) {
      return 0;
    }

    return (database.update(database.transactions)
          ..where((table) => table.contactId.isIn(contactIds))
          ..where((table) => table.isDeleted.equals(false)))
        .write(
      db.TransactionsCompanion.custom(
        isDeleted: const drift.Constant(true),
        updatedAt: drift.Variable(updatedAt),
        syncVersion:
            database.transactions.syncVersion + const drift.Constant(1),
      ),
    );
  }

  Future<int> bulkRestoreTransactionsByContactIds({
    required List<String> contactIds,
    required DateTime deletedAt,
    required DateTime restoredAt,
  }) async {
    if (contactIds.isEmpty) {
      return 0;
    }

    return (database.update(database.transactions)
          ..where((table) => table.contactId.isIn(contactIds))
          ..where((table) => table.isDeleted.equals(true))
          ..where((table) => table.updatedAt.equals(deletedAt)))
        .write(
      db.TransactionsCompanion.custom(
        isDeleted: const drift.Constant(false),
        updatedAt: drift.Variable(restoredAt),
        syncVersion:
            database.transactions.syncVersion + const drift.Constant(1),
      ),
    );
  }

  Future<void> bulkCreateTransactions(List<TransactionModel> transactions) async {
    if (transactions.isEmpty) {
      return;
    }

    await database.batch((batch) {
      batch.insertAll(
        database.transactions,
        transactions.map((transaction) => transaction.toDrift()).toList(
          growable: false,
        ),
      );
    });
  }

  /// Watches active transactions for a contact sorted by date.
  Stream<List<TransactionModel>> watchTransactionsByContact(String contactId) {
    return (database.select(database.transactions)
          ..where((table) => table.contactId.equals(contactId))
          ..where(
            (table) =>
                table.isDeleted.equals(false) & table.isArchived.equals(false),
          )
          ..orderBy([
            (table) => drift.OrderingTerm(
              expression: table.transactionDate,
              mode: drift.OrderingMode.desc,
            ),
            (table) => drift.OrderingTerm(
              expression: table.createdAt,
              mode: drift.OrderingMode.desc,
            ),
          ]))
        .watch()
        .map(
          (rows) => rows.map((row) => row.toModel()).toList(growable: false),
        );
  }

  /// Watches a paginated set of active transactions for a contact.
  ///
  /// Uses SQL-level `LIMIT` for efficient pagination. Optional date
  /// filters are applied via SQL `WHERE` clauses, not in-memory.
  /// Results are ordered by `transactionDate DESC`, `createdAt DESC`.
  Stream<List<TransactionModel>> watchPaginatedTransactions(
    String contactId, {
    required int limit,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final query = database.select(database.transactions)
      ..where((table) => table.contactId.equals(contactId))
      ..where((table) => table.isDeleted.equals(false))
      ..orderBy([
        (table) => drift.OrderingTerm(
          expression: table.transactionDate,
          mode: drift.OrderingMode.desc,
        ),
        (table) => drift.OrderingTerm(
          expression: table.createdAt,
          mode: drift.OrderingMode.desc,
        ),
      ])
      ..limit(limit);

    if (startDate != null) {
      query.where(
        (table) => table.transactionDate.isBiggerOrEqualValue(startDate),
      );
    }
    if (endDate != null) {
      query.where(
        (table) => table.transactionDate.isSmallerOrEqualValue(endDate),
      );
    }

    return query.watch().map(
      (rows) => rows.map((row) => row.toModel()).toList(growable: false),
    );
  }

  /// Streams the count of active transactions for a contact.
  ///
  /// Uses SQL `COUNT(*)` — no row materialization. Ultra-lightweight.
  Stream<int> watchTransactionCountByContact(String contactId) {
    return database
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM transactions '
          'WHERE contact_id = ? AND is_deleted = 0',
          variables: [drift.Variable.withString(contactId)],
          readsFrom: {database.transactions},
        )
        .watchSingle()
        .map((row) => row.read<int>('cnt'));
  }

  /// Returns transactions for a contact in a date range.
  Future<List<TransactionModel>> getTransactionsByDateRange(
    String contactId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final rows =
        await (database.select(database.transactions)
              ..where((table) => table.contactId.equals(contactId))
              ..where(
            (table) =>
                table.isDeleted.equals(false) & table.isArchived.equals(false),
          )
              ..where(
                (table) =>
                    table.transactionDate.isBetweenValues(startDate, endDate),
              )
              ..orderBy([
                (table) => drift.OrderingTerm(
                  expression: table.transactionDate,
                  mode: drift.OrderingMode.desc,
                ),
              ]))
            .get();

    return rows.map((row) => row.toModel()).toList(growable: false);
  }

  /// Returns a transaction by ID.
  Future<TransactionModel?> getTransactionById(String transactionId) async {
    final row = await (database.select(
      database.transactions,
    )..where((table) => table.id.equals(transactionId))).getSingleOrNull();
    return row?.toModel();
  }

  /// Searches recent item names using Arabic normalization.
  ///
  /// IMPORTANT: Raw SQL must use the actual snake_case column names that Drift
  /// generates (e.g. `item_name`, `created_at`, `is_deleted`), NOT the
  /// camelCase Dart property names.
  Future<List<RecentItemSuggestionRow>> searchRecentItems(
    String query, {
    int limit = 5,
  }) async {
    final normalizedQuery = query.normalizeArabic().toLowerCase().trim();
    if (normalizedQuery.isEmpty || limit <= 0) {
      return const <RecentItemSuggestionRow>[];
    }

    final normalizedItemNameExpression = _normalizedArabicSqlExpression(
      'item_name',
    );

    final rows = await database
        .customSelect(
          '''
      SELECT item_name AS itemName, amount AS lastAmount, created_at
      FROM (
        SELECT item_name, amount, created_at, id,
               ROW_NUMBER() OVER (
                 PARTITION BY $normalizedItemNameExpression
                 ORDER BY created_at DESC, id DESC
               ) AS rn
        FROM transactions
        WHERE is_deleted = 0
          AND item_name IS NOT NULL
          AND TRIM(item_name) <> ''
          AND $normalizedItemNameExpression LIKE '%' || ? || '%'
      )
      WHERE rn = 1
      ORDER BY created_at DESC, item_name ASC
      LIMIT ?
      ''',
          variables: [
            drift.Variable.withString(normalizedQuery),
            drift.Variable.withInt(limit),
          ],
          readsFrom: {database.transactions},
        )
        .get();

    return rows
        .map(
          (row) => (
            itemName: row.read<String>('itemName'),
            lastAmount: row.read<int>('lastAmount'),
          ),
        )
        .toList(growable: false);
  }

  String _normalizedArabicSqlExpression(String column) {
    var expression = 'LOWER(TRIM($column))';

    for (final diacritic in _arabicDiacritics) {
      expression =
          "REPLACE($expression, '${_escapeSqlLiteral(diacritic)}', '')";
    }

    for (final replacement in _arabicNormalizationPairs) {
      expression =
          "REPLACE($expression, '${_escapeSqlLiteral(replacement.$1)}', '${_escapeSqlLiteral(replacement.$2)}')";
    }

    return expression;
  }

  String _escapeSqlLiteral(String value) => value.replaceAll("'", "''");
}

const List<String> _arabicDiacritics = [
  '\u{064B}',
  '\u{064C}',
  '\u{064D}',
  '\u{064E}',
  '\u{064F}',
  '\u{0650}',
  '\u{0651}',
  '\u{0652}',
  '\u{0653}',
  '\u{0654}',
  '\u{0655}',
  '\u{0656}',
  '\u{0657}',
  '\u{0658}',
  '\u{0659}',
  '\u{065A}',
  '\u{065B}',
  '\u{065C}',
  '\u{065D}',
  '\u{065E}',
  '\u{065F}',
];

const List<(String, String)> _arabicNormalizationPairs = [
  ('أ', 'ا'),
  ('إ', 'ا'),
  ('آ', 'ا'),
  ('ٱ', 'ا'),
  ('ة', 'ه'),
  ('ى', 'ي'),
];
