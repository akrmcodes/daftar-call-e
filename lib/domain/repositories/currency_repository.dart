import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/currency.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for currency reference data operations.
///
/// Implementations must:
/// - Seed built-in currencies (YER, SAR, USD) on database creation.
/// - Return [Left(DatabaseFailure)] for all persistence errors.
/// - Enforce unique constraint on currency `code`.
abstract class CurrencyRepository {
  /// Returns all currencies (both built-in and custom).
  ///
  /// Results include inactive currencies for management UI.
  Future<Either<Failure, List<Currency>>> getAll();

  /// Returns only built-in system currencies (YER, SAR, USD).
  Future<Either<Failure, List<Currency>>> getBuiltIn();

  /// Returns only currencies marked as active.
  ///
  /// Used for currency selection dropdowns in transaction entry.
  Future<Either<Failure, List<Currency>>> getActive();

  /// Adds a custom user-defined currency.
  ///
  /// Returns [Left(ValidationFailure)] if the code already exists.
  /// Returns [Left(DatabaseFailure)] if persistence fails.
  Future<Either<Failure, Currency>> addCustom(AddCurrencyParams params);

  /// Toggles the `isActive` status of a currency.
  ///
  /// Built-in currencies can be deactivated but not deleted.
  /// Returns [Left(DatabaseFailure)] if the currency is not found.
  Future<Either<Failure, Currency>> toggleActive(String id);
}

/// Parameters for adding a custom currency.
class AddCurrencyParams {

  const AddCurrencyParams({
    required this.code,
    required this.symbol,
    required this.nameAr,
    required this.nameEn,
    required this.decimalPlaces,
  });
  final String code;
  final String symbol;
  final String nameAr;
  final String nameEn;
  final int decimalPlaces;
}
