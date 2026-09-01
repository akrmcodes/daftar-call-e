import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/value_objects/carry_forward_preview.dart';
import 'package:daftar/domain/value_objects/carry_forward_result.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for ledger persistence operations.
///
/// Implementations must:
/// - Return [Left(DatabaseFailure)] for all persistence errors.
/// - Exclude soft-deleted records from query results unless specified.
/// - Append to `AuditLog` on every write operation.
/// - Filter out records where `isDeleted = true` by default.
abstract class LedgerRepository {
  /// Streams all non-deleted ledgers ordered by `sortOrder`.
  ///
  /// The stream auto-emits on any data change (Drift reactive query).
  Stream<List<Ledger>> watchAll();

  /// Returns a ledger by [id], or [Left(DatabaseFailure)] if not found.
  Future<Either<Failure, Ledger>> getById(String id);

  /// Creates a new ledger. Returns the created entity on success.
  ///
  /// Returns [Left(DatabaseFailure)] if persistence fails.
  Future<Either<Failure, Ledger>> create(CreateLedgerParams params);

  /// Updates an existing ledger's mutable fields.
  ///
  /// Returns [Left(DatabaseFailure)] if the ledger is not found or
  /// persistence fails.
  Future<Either<Failure, Ledger>> update(UpdateLedgerParams params);

  /// Soft-deletes a ledger by setting `isDeleted = true`.
  ///
  /// Implementations should cascade soft-delete to child contacts
  /// and their transactions within a single Drift transaction.
  ///
  /// Returns [Left(DatabaseFailure)] if persistence fails.
  Future<Either<Failure, Unit>> delete(String id);

  /// Restores a soft-deleted ledger by setting `isDeleted = false`.
  ///
  /// Implementations should restore the cascade that was soft-deleted with
  /// the ledger, including child contacts, their transactions, and derived
  /// balance rows, within a single Drift transaction.
  ///
  /// Returns [Left(DatabaseFailure)] if persistence fails.
  Future<Either<Failure, Ledger>> restore(String id);

  /// Returns the count of active (non-deleted) ledgers.
  ///
  /// Used by `CreateLedgerUseCase` for free-tier limit enforcement.
  /// Returns [Left(DatabaseFailure)] if the count query fails.
  Future<Either<Failure, int>> getActiveCount();

  /// Count of non-deleted archived ledgers awaiting promotion.
  Future<Either<Failure, int>> getArchivedCount();

  /// Promotes up to [limit] archived ledgers into the live workspace.
  Future<Either<Failure, int>> promoteArchived({required int limit});

  Stream<List<Ledger>> watchArchived();

  Future<Either<Failure, int>> getArchivedLedgerCount();

  Future<Either<Failure, Ledger>> archiveLedger(String ledgerId);

  Future<Either<Failure, Ledger>> unarchiveLedger(String ledgerId);

  Future<Either<Failure, CarryForwardPreview>> previewCarryForward({
    required String sourceLedgerId,
    required String targetLedgerId,
  });

  Future<Either<Failure, CarryForwardResult>> archiveWithCarryForward(
    ArchiveWithCarryForwardParams params,
  );
}

/// Parameters for creating a new ledger.
class CreateLedgerParams {
  const CreateLedgerParams({
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.isArchived = false,
  });
  final String name;
  final LedgerType type;
  final String icon;
  final String color;
  final bool isArchived;
}

/// Parameters for updating an existing ledger.
class UpdateLedgerParams {
  const UpdateLedgerParams({
    required this.id,
    this.name,
    this.icon,
    this.color,
    this.sortOrder,
  });
  final String id;
  final String? name;
  final String? icon;
  final String? color;
  final int? sortOrder;
}

class ArchiveWithCarryForwardParams {
  const ArchiveWithCarryForwardParams({
    required this.sourceLedgerId,
    required this.targetLedgerId,
    required this.operationId,
    required this.openingBalanceItemName,
    required this.openingBalanceDescription,
  });

  final String sourceLedgerId;
  final String targetLedgerId;
  final String operationId;
  final String openingBalanceItemName;
  final String openingBalanceDescription;
}
