import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/audit_log.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for audit log operations.
///
/// The audit log is append-only. Entries are never modified or deleted.
/// Every CREATE, UPDATE, and DELETE operation on core entities must
/// append an entry.
///
/// Implementations must:
/// - Return [Left(DatabaseFailure)] for all persistence errors.
/// - Index on (entityType, entityId) and timestamp for efficient queries.
abstract class AuditLogRepository {
  /// Appends a new audit log entry.
  ///
  /// Called by repository implementations after every successful
  /// write operation.
  ///
  /// Returns [Left(DatabaseFailure)] if persistence fails.
  Future<Either<Failure, Unit>> append(AppendAuditLogParams params);

  /// Returns all audit log entries for a specific entity.
  ///
  /// Results are ordered by `timestamp` descending (newest first).
  Future<Either<Failure, List<AuditLog>>> getByEntity(
    String entityType,
    String entityId,
  );

  /// Returns the most recent audit log entries across all entities.
  ///
  /// Used for activity feed and sync replay.
  /// [limit] defaults to 50 entries.
  Future<Either<Failure, List<AuditLog>>> getRecent({int limit = 50});
}

/// Parameters for appending an audit log entry.
class AppendAuditLogParams {

  const AppendAuditLogParams({
    required this.entityType,
    required this.entityId,
    required this.action,
    this.payload,
  });
  /// Type of entity (e.g., 'ledger', 'contact', 'transaction').
  final String entityType;

  /// UUID of the modified entity.
  final String entityId;

  /// The operation performed: 'CREATE', 'UPDATE', or 'DELETE'.
  final String action;

  /// Optional JSON payload containing changed field values.
  final String? payload;
}
