import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/core/utils/validators.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/currency_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/models/currency_model.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/entities/currency.dart';
import 'package:daftar/domain/repositories/currency_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Drift-backed implementation of [CurrencyRepository].
class CurrencyRepositoryImpl implements CurrencyRepository {
  /// Creates a currency repository implementation.
  CurrencyRepositoryImpl({
    required CurrencyLocalDataSource currencyLocalDataSource,
    required AuditLogLocalDataSource auditLogLocalDataSource,
  }) : _currencyLocalDataSource = currencyLocalDataSource,
       _auditLogLocalDataSource = auditLogLocalDataSource;

  final CurrencyLocalDataSource _currencyLocalDataSource;
  final AuditLogLocalDataSource _auditLogLocalDataSource;

  db.AppDatabase get _database => _currencyLocalDataSource.database;

  @override
  Future<Either<Failure, List<Currency>>> getAll() async {
    try {
      final currencies = await _currencyLocalDataSource.getAllCurrencies();
      return Right(
        currencies
            .map((currency) => currency.toDomain())
            .toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<Currency>>> getBuiltIn() async {
    try {
      final currencies = await _currencyLocalDataSource.getBuiltInCurrencies();
      return Right(
        currencies
            .map((currency) => currency.toDomain())
            .toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<Currency>>> getActive() async {
    try {
      final currencies = await _currencyLocalDataSource.getActiveCurrencies();
      return Right(
        currencies
            .map((currency) => currency.toDomain())
            .toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Currency>> addCustom(AddCurrencyParams params) async {
    try {
      final normalizedCode = params.code.trim().toUpperCase();
      final validationMessage = Validators.validateCurrencyCode(normalizedCode);
      if (validationMessage != null) {
        return Left(
          validationFailure(
            validationMessage,
            code: 'invalid_currency_code',
          ),
        );
      }

      final existing = await (_database.select(
        _database.currencies,
      )..where((table) => table.code.equals(normalizedCode))).getSingleOrNull();
      if (existing != null) {
        return Left(
          validationFailure(
            'Currency code already exists.',
            code: 'currency_code_exists',
          ),
        );
      }

      final currency = CurrencyModel(
        id: UuidUtil.generate(),
        code: normalizedCode,
        symbol: params.symbol.trim(),
        nameAr: params.nameAr.trim(),
        nameEn: params.nameEn.trim(),
        decimalPlaces: params.decimalPlaces,
      );

      await _database.transaction(() async {
        await _currencyLocalDataSource.addCustomCurrency(currency);
        await _appendAuditLog(
          entityType: 'currency',
          entityId: currency.id,
          action: 'CREATE',
          payload: encodePayload({
            'id': currency.id,
            'code': currency.code,
            'symbol': currency.symbol,
            'nameAr': currency.nameAr,
            'nameEn': currency.nameEn,
            'decimalPlaces': currency.decimalPlaces,
          }),
        );
      });

      return Right(currency.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Currency>> toggleActive(String id) async {
    try {
      final row = await (_database.select(
        _database.currencies,
      )..where((table) => table.id.equals(id))).getSingleOrNull();
      if (row == null) {
        return Left(notFoundFailure('Currency', id));
      }

      CurrencyModel? toggled;
      await _database.transaction(() async {
        toggled = await _currencyLocalDataSource.toggleCurrencyActive(
          row.code,
          isActive: !row.isActive,
        );
        if (toggled == null) {
          return;
        }
        await _appendAuditLog(
          entityType: 'currency',
          entityId: toggled!.id,
          action: 'UPDATE',
          payload: encodePayload({
            'isActive': toggled!.isActive,
          }),
        );
      });
      if (toggled == null) {
        return Left(notFoundFailure('Currency', id));
      }

      return Right(toggled!.toDomain());
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
