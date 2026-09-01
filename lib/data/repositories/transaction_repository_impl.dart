import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/balance_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/datasources/local/transaction_local_ds.dart';
import 'package:daftar/data/mappers/audit_payload_mapper.dart';
import 'package:daftar/data/mappers/transaction_mapper.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/data/repositories/balance_recalculation_service.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/entities/item_suggestion.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:drift/drift.dart' as drift;
import 'package:fpdart/fpdart.dart';

/// Drift-backed implementation of [TransactionRepository].
class TransactionRepositoryImpl implements TransactionRepository {
  /// Creates a transaction repository implementation.
  TransactionRepositoryImpl({
    required TransactionLocalDataSource transactionLocalDataSource,
    required BalanceLocalDataSource balanceLocalDataSource,
    required AuditLogLocalDataSource auditLogLocalDataSource,
  }) : _transactionLocalDataSource = transactionLocalDataSource,
       _auditLogLocalDataSource = auditLogLocalDataSource,
       _balanceRecalculationService = BalanceRecalculationService(
         database: transactionLocalDataSource.database,
         balanceLocalDataSource: balanceLocalDataSource,
       );

  final TransactionLocalDataSource _transactionLocalDataSource;
  final AuditLogLocalDataSource _auditLogLocalDataSource;
  final BalanceRecalculationService _balanceRecalculationService;

  db.AppDatabase get _database => _transactionLocalDataSource.database;

  @override
  Stream<List<Transaction>> watchByContact(String contactId) {
    return _transactionLocalDataSource
        .watchTransactionsByContact(contactId)
        .map(
          (models) =>
              models.map((model) => model.toDomain()).toList(growable: false),
        );
  }

  @override
  Stream<List<Transaction>> watchTransactions(
    String contactId, {
    int limit = 20,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _transactionLocalDataSource
        .watchPaginatedTransactions(
          contactId,
          limit: limit,
          startDate: startDate,
          endDate: endDate,
        )
        .map(
          (models) =>
              models.map((model) => model.toDomain()).toList(growable: false),
        );
  }

  @override
  Stream<int> watchTransactionCount(String contactId) {
    return _transactionLocalDataSource.watchTransactionCountByContact(
      contactId,
    );
  }

  @override
  Future<Either<Failure, List<Transaction>>> getByContact(
    String contactId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _queryActiveTransactions(
        contactId: contactId,
        limit: limit,
        offset: offset,
      );

      return Right(
        rows.map((row) => row.toDomain()).toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<Transaction>>> getByDateRange(
    String contactId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final rows =
          await (_database.select(_database.transactions)
                ..where((table) => table.contactId.equals(contactId))
                ..where((table) => table.isDeleted.equals(false))
                ..where(
                  (table) => table.transactionDate.isBetweenValues(
                    startDate,
                    endDate,
                  ),
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
              .get();

      return Right(
        rows.map((row) => row.toDomain()).toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<Transaction>>> getCreatedOnLocalDay(
    String localDay, {
    DateTime? now,
  }) async {
    final bounds = ClosingAgentConstants.utcBoundsForLocalDay(
      localDay,
      now: now,
    );
    if (bounds == null) {
      return const Left(
        ValidationFailure(
          'localDay must be YYYY-MM-DD.',
          code: 'invalid_local_day',
        ),
      );
    }

    try {
      final rows =
          await (_database.select(_database.transactions)
                ..where((table) => table.isDeleted.equals(false))
                ..where((table) => table.isArchived.equals(false))
                ..where(
                  (table) =>
                      table.createdAt.isBiggerOrEqualValue(bounds.startUtc),
                )
                ..where(
                  (table) => table.createdAt.isSmallerThanValue(bounds.endUtc),
                )
                ..orderBy([
                  (table) => drift.OrderingTerm(
                    expression: table.createdAt,
                    mode: drift.OrderingMode.desc,
                  ),
                ]))
              .get();

      return Right(
        rows.map((row) => row.toDomain()).toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Transaction>> getById(String id) async {
    try {
      final transaction = await _transactionLocalDataSource.getTransactionById(
        id,
      );
      if (transaction == null || transaction.isDeleted) {
        return Left(notFoundFailure('Transaction', id));
      }

      return Right(transaction.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<ItemSuggestion>>> searchRecentItems(
    String query, {
    int limit = 5,
  }) async {
    final normalizedQuery = query.normalizeArabic().trim();
    if (normalizedQuery.isEmpty || limit <= 0) {
      return const Right(<ItemSuggestion>[]);
    }

    try {
      final rows = await _transactionLocalDataSource.searchRecentItems(
        normalizedQuery,
        limit: limit,
      );
      final suggestions = rows
          .map(
            (row) => ItemSuggestion(
              itemName: row.itemName,
              lastAmount: row.lastAmount,
            ),
          )
          .toList(growable: false);

      return Right(suggestions);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<Transaction>>> getRawTransactionsByContact(
    String contactId,
  ) async {
    try {
      final rows =
          await (_database.select(_database.transactions)
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
                ]))
              .get();

      return Right(
        rows.map((row) => row.toDomain()).toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Transaction>> create(
    CreateTransactionParams params,
  ) async {
    try {
      final now = DateTime.now().toUtc();
      final transaction = TransactionModel(
        id: UuidUtil.generate(),
        contactId: params.contactId,
        type: params.type,
        amount: params.amount,
        currency: params.currency,
        description: params.description,
        itemName: params.itemName,
        transactionDate: params.transactionDate.toUtc(),
        attachmentPath: params.attachmentPath,
        createdAt: now,
        updatedAt: now,
        isArchived: params.isArchived,
      );

      late final TransactionModel savedTransaction;

      await _database.transaction(() async {
        savedTransaction = await _transactionLocalDataSource.createTransaction(
          transaction,
        );
        if (!params.isArchived) {
          await _balanceRecalculationService.recalculateBalancesForContact(
            contactId: savedTransaction.contactId,
            lastUpdatedAt: now,
          );
        }
        await _appendAuditLog(
          entityType: 'transaction',
          entityId: savedTransaction.id,
          action: 'CREATE',
          payload: encodePayload(
            transactionCreateAuditPayload(savedTransaction),
          ),
        );
      });

      return Right(savedTransaction.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Transaction>> update(
    UpdateTransactionParams params,
  ) async {
    try {
      final existing = await _transactionLocalDataSource.getTransactionById(
        params.id,
      );
      if (existing == null || existing.isDeleted) {
        return Left(notFoundFailure('Transaction', params.id));
      }

      final updated = TransactionModel(
        id: existing.id,
        contactId: existing.contactId,
        type: params.type ?? existing.type,
        amount: params.amount ?? existing.amount,
        currency: params.currency ?? existing.currency,
        description: params.description ?? existing.description,
        itemName: params.itemName ?? existing.itemName,
        transactionDate: (params.transactionDate ?? existing.transactionDate)
            .toUtc(),
        attachmentPath: params.attachmentPath ?? existing.attachmentPath,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now().toUtc(),
        isDeleted: existing.isDeleted,
        syncVersion: existing.syncVersion + 1,
      );

      await _database.transaction(() async {
        await _transactionLocalDataSource.updateTransaction(updated);
        await _balanceRecalculationService.recalculateBalancesForContact(
          contactId: updated.contactId,
          lastUpdatedAt: updated.updatedAt,
        );
        await _appendAuditLog(
          entityType: 'transaction',
          entityId: updated.id,
          action: 'UPDATE',
          payload: encodePayload({
            'type': updated.type.name,
            'amount': updated.amount,
            'currency': updated.currency,
            'description': updated.description,
            'itemName': updated.itemName,
            'attachmentPath': updated.attachmentPath,
            'transactionDate': updated.transactionDate.toIso8601String(),
          }),
        );
      });

      return Right(updated.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> restoreTransaction(String id) async {
    try {
      final existing = await _transactionLocalDataSource.getTransactionById(id);
      if (existing == null || !existing.isDeleted) {
        return Left(notFoundFailure('Transaction', id));
      }

      final restored = TransactionModel(
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
        syncVersion: existing.syncVersion + 1,
      );

      await _database.transaction(() async {
        await _transactionLocalDataSource.updateTransaction(restored);
        await _balanceRecalculationService.recalculateBalancesForContact(
          contactId: restored.contactId,
          lastUpdatedAt: restored.updatedAt,
        );
        await _appendAuditLog(
          entityType: 'transaction',
          entityId: restored.id,
          action: 'RESTORE',
          payload: encodePayload({
            'id': restored.id,
            'contactId': restored.contactId,
          }),
        );
      });

      return const Right(unit);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteTransaction(String id) async {
    try {
      final existing = await _transactionLocalDataSource.getTransactionById(id);
      if (existing == null || existing.isDeleted) {
        return Left(notFoundFailure('Transaction', id));
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

      await _database.transaction(() async {
        await _transactionLocalDataSource.updateTransaction(deleted);
        await _balanceRecalculationService.recalculateBalancesForContact(
          contactId: deleted.contactId,
          lastUpdatedAt: deleted.updatedAt,
        );
        await _appendAuditLog(
          entityType: 'transaction',
          entityId: deleted.id,
          action: 'DELETE',
          payload: encodePayload({
            'id': deleted.id,
            'contactId': deleted.contactId,
          }),
        );
      });

      return const Right(unit);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  /// Compatibility alias for older call sites that still use `delete`.
  Future<Either<Failure, Unit>> delete(String id) {
    return deleteTransaction(id);
  }

  @override
  Future<Either<Failure, int>> getActiveCount() async {
    try {
      return Right(await _countActiveTransactions());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  Future<List<db.Transaction>> _queryActiveTransactions({
    required String contactId,
    required int limit,
    required int offset,
  }) async {
    return (_database.select(_database.transactions)
          ..where((table) => table.contactId.equals(contactId))
          ..where((table) => table.isDeleted.equals(false))
          ..where((table) => table.isArchived.equals(false))
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
          ..limit(limit, offset: offset))
        .get();
  }

  Future<int> _countActiveTransactions() async {
    final result = await _database
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM transactions '
          'WHERE is_deleted = 0 AND is_archived = 0',
          readsFrom: {_database.transactions},
        )
        .getSingle();
    return result.read<int>('cnt');
  }

  @override
  Future<Either<Failure, int>> getArchivedCount() async {
    try {
      final result = await _database
          .customSelect(
            'SELECT COUNT(*) AS cnt FROM transactions '
            'WHERE is_deleted = 0 AND is_archived = 1',
            readsFrom: {_database.transactions},
          )
          .getSingle();
      return Right(result.read<int>('cnt'));
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, int>> promoteArchived({required int limit}) async {
    if (limit <= 0) {
      return const Right(0);
    }
    try {
      final now = DateTime.now().toUtc();
      final query =
          _database.select(_database.transactions).join([
              drift.innerJoin(
                _database.contacts,
                _database.contacts.id.equalsExp(
                  _database.transactions.contactId,
                ),
              ),
              drift.innerJoin(
                _database.ledgers,
                _database.ledgers.id.equalsExp(_database.contacts.ledgerId),
              ),
            ])
            ..where(
              _database.transactions.isDeleted.equals(false) &
                  _database.transactions.isArchived.equals(true) &
                  _database.contacts.isDeleted.equals(false) &
                  _database.contacts.isArchived.equals(false) &
                  _database.ledgers.isDeleted.equals(false) &
                  _database.ledgers.isArchived.equals(false),
            )
            ..limit(limit);

      final rows = await query.get();
      if (rows.isEmpty) {
        return const Right(0);
      }

      final ids = rows
          .map((row) => row.readTable(_database.transactions).id)
          .toList(growable: false);
      final contactIds = rows
          .map((row) => row.readTable(_database.transactions).contactId)
          .toSet();

      await _database.transaction(() async {
        await (_database.update(
          _database.transactions,
        )..where((table) => table.id.isIn(ids))).write(
          db.TransactionsCompanion(
            isArchived: const drift.Value(false),
            updatedAt: drift.Value(now),
          ),
        );
        for (final id in ids) {
          await _appendAuditLog(
            entityType: 'transaction',
            entityId: id,
            action: 'ACTIVATE_ARCHIVED',
            payload: encodePayload({'id': id}),
          );
        }
        for (final contactId in contactIds) {
          await _balanceRecalculationService.recalculateBalancesForContact(
            contactId: contactId,
            lastUpdatedAt: now,
          );
        }
      });

      return Right(ids.length);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  Future<void> _appendAuditLog({
    required String entityType,
    required String entityId,
    required String action,
    String? payload,
  }) async {
    await _auditLogLocalDataSource.appendLog(
      AuditLogModel(
        id: UuidUtil.generate(),
        entityType: entityType,
        entityId: entityId,
        action: action,
        payload: payload,
        timestamp: DateTime.now().toUtc(),
        deviceId: repositoryDeviceId,
      ),
    );
  }
}
