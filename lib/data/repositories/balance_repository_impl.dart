import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/local/balance_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/datasources/local/transaction_local_ds.dart';
import 'package:daftar/data/models/balance_model.dart';
import 'package:daftar/data/repositories/balance_recalculation_service.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Drift-backed implementation of [BalanceRepository].
class BalanceRepositoryImpl implements BalanceRepository {
  /// Creates a balance repository implementation.
  BalanceRepositoryImpl({
    required BalanceLocalDataSource balanceLocalDataSource,
    required TransactionLocalDataSource transactionLocalDataSource,
  }) : _balanceLocalDataSource = balanceLocalDataSource,
       _transactionLocalDataSource = transactionLocalDataSource,
       _balanceRecalculationService = BalanceRecalculationService(
         database: transactionLocalDataSource.database,
         balanceLocalDataSource: balanceLocalDataSource,
       );

  final BalanceLocalDataSource _balanceLocalDataSource;
  final TransactionLocalDataSource _transactionLocalDataSource;
  final BalanceRecalculationService _balanceRecalculationService;

  db.AppDatabase get _database => _transactionLocalDataSource.database;

  @override
  Future<Either<Failure, List<ContactBalance>>> getByContact(
    String contactId,
  ) async {
    try {
      final balances = await _balanceLocalDataSource.getBalanceByContact(
        contactId,
      );
      return Right(
        balances.map((balance) => balance.toDomain()).toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Stream<List<ContactBalance>> watchByContact(String contactId) {
    return _balanceLocalDataSource
        .watchBalanceByContact(contactId)
        .map(
          (balances) => balances
              .map((balance) => balance.toDomain())
              .toList(growable: false),
        );
  }

  @override
  Stream<List<ContactBalance>> watchAllBalances() {
    return _balanceLocalDataSource.watchAllBalances().map(
      (balances) =>
          balances.map((balance) => balance.toDomain()).toList(growable: false),
    );
  }

  @override
  Stream<List<ContactBalance>> watchBalancesByLedger(String ledgerId) {
    return _balanceLocalDataSource.watchBalancesByLedger(ledgerId).map(
      (balances) =>
          balances.map((balance) => balance.toDomain()).toList(growable: false),
    );
  }

  @override
  Future<Either<Failure, List<ContactBalance>>> recalculate(
    String contactId,
  ) async {
    try {
      late final List<BalanceModel> balances;
      await _database.transaction(() async {
        balances = await _balanceRecalculationService.recalculateBalancesForContact(
          contactId: contactId,
          lastUpdatedAt: DateTime.now().toUtc(),
        );
      });

      return Right(
        balances.map((balance) => balance.toDomain()).toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }
}
