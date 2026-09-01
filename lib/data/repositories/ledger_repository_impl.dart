import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/balance_local_ds.dart';
import 'package:daftar/data/datasources/local/contact_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/datasources/local/ledger_local_ds.dart';
import 'package:daftar/data/datasources/local/transaction_local_ds.dart';
import 'package:daftar/data/mappers/audit_payload_mapper.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/ledger_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/data/repositories/balance_recalculation_service.dart';
import 'package:daftar/data/repositories/contact_search_index_utils.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/value_objects/carry_forward_preview.dart';
import 'package:daftar/domain/value_objects/carry_forward_result.dart';
import 'package:drift/drift.dart' as drift;
import 'package:fpdart/fpdart.dart';

class CarryForwardTestFaults {
  const CarryForwardTestFaults({this.throwBeforeNewContactInsertAt});

  final int? throwBeforeNewContactInsertAt;
}

/// Drift-backed implementation of [LedgerRepository].
class LedgerRepositoryImpl implements LedgerRepository {
  /// Creates a ledger repository implementation.
  LedgerRepositoryImpl({
    required LedgerLocalDataSource ledgerLocalDataSource,
    required ContactLocalDataSource contactLocalDataSource,
    required TransactionLocalDataSource transactionLocalDataSource,
    required BalanceLocalDataSource balanceLocalDataSource,
    required AuditLogLocalDataSource auditLogLocalDataSource,
    CarryForwardTestFaults? carryForwardTestFaults,
  }) : _ledgerLocalDataSource = ledgerLocalDataSource,
       _contactLocalDataSource = contactLocalDataSource,
       _transactionLocalDataSource = transactionLocalDataSource,
       _auditLogLocalDataSource = auditLogLocalDataSource,
       _carryForwardTestFaults = carryForwardTestFaults,
       _balanceRecalculationService = BalanceRecalculationService(
         database: ledgerLocalDataSource.database,
         balanceLocalDataSource: balanceLocalDataSource,
       );

  final LedgerLocalDataSource _ledgerLocalDataSource;
  final ContactLocalDataSource _contactLocalDataSource;
  final TransactionLocalDataSource _transactionLocalDataSource;
  final AuditLogLocalDataSource _auditLogLocalDataSource;
  final CarryForwardTestFaults? _carryForwardTestFaults;
  final BalanceRecalculationService _balanceRecalculationService;

  db.AppDatabase get _database => _ledgerLocalDataSource.database;

  @override
  Stream<List<Ledger>> watchAll() {
    return _ledgerLocalDataSource.watchAllLedgers().map(
      (models) =>
          models.map((model) => model.toDomain()).toList(growable: false),
    );
  }

  @override
  Future<Either<Failure, Ledger>> getById(String id) async {
    try {
      final ledger = await _ledgerLocalDataSource.getLedgerById(id);
      if (ledger == null || ledger.isDeleted) {
        return Left(notFoundFailure('Ledger', id));
      }

      return Right(ledger.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Ledger>> create(CreateLedgerParams params) async {
    try {
      final activeCount = await _countActiveLedgers();
      final now = DateTime.now().toUtc();
      final ledger = LedgerModel(
        id: UuidUtil.generate(),
        name: params.name.trim(),
        type: params.type,
        icon: params.icon,
        color: params.color,
        sortOrder: activeCount,
        createdAt: now,
        updatedAt: now,
        isArchived: params.isArchived,
      );

      await _database.transaction(() async {
        await _ledgerLocalDataSource.createLedger(ledger);
        await _appendAuditLog(
          entityType: 'ledger',
          entityId: ledger.id,
          action: 'CREATE',
          payload: encodePayload({
            'id': ledger.id,
            'name': ledger.name,
            'type': ledger.type.name,
            'icon': ledger.icon,
            'color': ledger.color,
            'sortOrder': ledger.sortOrder,
          }),
        );
      });

      return Right(ledger.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Ledger>> update(UpdateLedgerParams params) async {
    try {
      final existing = await _ledgerLocalDataSource.getLedgerById(params.id);
      if (existing == null || existing.isDeleted) {
        return Left(notFoundFailure('Ledger', params.id));
      }

      final updated = LedgerModel(
        id: existing.id,
        name: params.name?.trim() ?? existing.name,
        type: existing.type,
        icon: params.icon ?? existing.icon,
        color: params.color ?? existing.color,
        sortOrder: params.sortOrder ?? existing.sortOrder,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now().toUtc(),
        isDeleted: existing.isDeleted,
        syncVersion: existing.syncVersion + 1,
      );

      await _database.transaction(() async {
        await _ledgerLocalDataSource.updateLedger(updated);
        await _appendAuditLog(
          entityType: 'ledger',
          entityId: updated.id,
          action: 'UPDATE',
          payload: encodePayload({
            'name': updated.name,
            'icon': updated.icon,
            'color': updated.color,
            'sortOrder': updated.sortOrder,
          }),
        );
      });

      return Right(updated.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(String id) async {
    try {
      final existing = await _ledgerLocalDataSource.getLedgerById(id);
      if (existing == null || existing.isDeleted) {
        return Left(notFoundFailure('Ledger', id));
      }

      final now = DateTime.now().toUtc();
      final contactIds =
          (await (_database.select(_database.contacts)
                ..where((table) => table.ledgerId.equals(id))
                ..where((table) => table.isDeleted.equals(false)))
              .get())
              .map((row) => row.id)
              .toList(growable: false);

      await _database.transaction(() async {
        await _ledgerLocalDataSource.updateLedger(
          LedgerModel(
            id: existing.id,
            name: existing.name,
            type: existing.type,
            icon: existing.icon,
            color: existing.color,
            sortOrder: existing.sortOrder,
            createdAt: existing.createdAt,
            updatedAt: now,
            isDeleted: true,
            syncVersion: existing.syncVersion + 1,
          ),
        );

        final contactCount =
            await _contactLocalDataSource.bulkSoftDeleteContactsByLedgerId(
          id,
          updatedAt: now,
        );
        await bulkRemoveContactSearchIndex(_database, contactIds);
        final transactionCount =
            await _transactionLocalDataSource
                .bulkSoftDeleteTransactionsByContactIds(
          contactIds,
          updatedAt: now,
        );

        if (contactIds.isNotEmpty) {
          await (_database.delete(
            _database.contactBalances,
          )..where((table) => table.contactId.isIn(contactIds))).go();
        }

        // TODO(aiAudit): record child-level audit logs for cascaded contact and transaction deletes.
        await _appendAuditLog(
          entityType: 'ledger',
          entityId: id,
          action: 'DELETE',
          payload: encodePayload({
            'id': id,
            'contactCount': contactCount,
            'transactionCount': transactionCount,
          }),
        );
      });

      return const Right(unit);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Ledger>> restore(String id) async {
    try {
      final existing = await _ledgerLocalDataSource.getLedgerById(id);
      if (existing == null || !existing.isDeleted) {
        return Left(notFoundFailure('Ledger', id));
      }

      final deletedAt = existing.updatedAt;
      final restoredAt = DateTime.now().toUtc();

      final contactRows =
          await (_database.select(_database.contacts)
                ..where((table) => table.ledgerId.equals(id))
                ..where((table) => table.isDeleted.equals(true))
                ..where((table) => table.updatedAt.equals(deletedAt)))
              .get();
      final contactIds = contactRows
          .map((row) => row.id)
          .toList(growable: false);

      final restoredLedger = LedgerModel(
        id: existing.id,
        name: existing.name,
        type: existing.type,
        icon: existing.icon,
        color: existing.color,
        sortOrder: existing.sortOrder,
        createdAt: existing.createdAt,
        updatedAt: restoredAt,
        syncVersion: existing.syncVersion + 1,
      );

      await _database.transaction(() async {
        await _ledgerLocalDataSource.updateLedger(restoredLedger);

        final contactCount =
            await _contactLocalDataSource.bulkRestoreContactsByLedgerId(
          ledgerId: id,
          deletedAt: deletedAt,
          restoredAt: restoredAt,
        );
        if (contactCount != contactRows.length) {
          throw StateError(
            'Contact restore count mismatch: expected ${contactRows.length}, got $contactCount',
          );
        }

        for (final contactRow in contactRows) {
          await upsertContactSearchIndex(
            _database,
            contactRow.id,
            contactRow.name,
          );
        }

        final transactionCount =
            await _transactionLocalDataSource.bulkRestoreTransactionsByContactIds(
          contactIds: contactIds,
          deletedAt: deletedAt,
          restoredAt: restoredAt,
        );

        for (final contactId in contactIds) {
          await _balanceRecalculationService.recalculateBalancesForContact(
            contactId: contactId,
            lastUpdatedAt: restoredAt,
          );
        }

        // TODO(aiAudit): record child-level audit logs for cascaded contact and transaction restores.
        await _appendAuditLog(
          entityType: 'ledger',
          entityId: id,
          action: 'RESTORE',
          payload: encodePayload({
            'id': id,
            'contactCount': contactCount,
            'transactionCount': transactionCount,
          }),
        );
      });

      return Right(restoredLedger.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, int>> getActiveCount() async {
    try {
      return Right(await _countActiveLedgers());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  Future<int> _countActiveLedgers() async {
    final result = await _database
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM ledgers '
          'WHERE is_deleted = 0 AND is_archived = 0',
          readsFrom: {_database.ledgers},
        )
        .getSingle();
    return result.read<int>('cnt');
  }

  @override
  Future<Either<Failure, int>> getArchivedCount() async {
    try {
      final result = await _database
          .customSelect(
            'SELECT COUNT(*) AS cnt FROM ledgers '
            'WHERE is_deleted = 0 AND is_archived = 1',
            readsFrom: {_database.ledgers},
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
      final targets =
          await (_database.select(_database.ledgers)
                ..where(
                  (table) =>
                      table.isDeleted.equals(false) &
                      table.isArchived.equals(true),
                )
                ..limit(limit))
              .get();
      if (targets.isEmpty) {
        return const Right(0);
      }
      final ids = targets.map((row) => row.id).toList(growable: false);
      await _database.transaction(() async {
        await (_database.update(_database.ledgers)
              ..where((table) => table.id.isIn(ids)))
            .write(
          db.LedgersCompanion(
            isArchived: const drift.Value(false),
            updatedAt: drift.Value(now),
          ),
        );
        for (final id in ids) {
          await _appendAuditLog(
            entityType: 'ledger',
            entityId: id,
            action: 'ACTIVATE_ARCHIVED',
            payload: encodePayload({'id': id}),
          );
        }
      });
      return Right(ids.length);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Stream<List<Ledger>> watchArchived() {
    return _ledgerLocalDataSource.watchArchivedLedgers().map(
      (models) =>
          models.map((model) => model.toDomain()).toList(growable: false),
    );
  }

  @override
  Future<Either<Failure, int>> getArchivedLedgerCount() async {
    try {
      final count = await _ledgerLocalDataSource.countUserArchivedLedgers();
      return Right(count);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Ledger>> archiveLedger(String ledgerId) async {
    try {
      final existing = await _ledgerLocalDataSource.getLedgerById(ledgerId);
      if (existing == null || existing.isDeleted) {
        return Left(notFoundFailure('Ledger', ledgerId));
      }

      final now = DateTime.now().toUtc();
      final updated = LedgerModel(
        id: existing.id,
        name: existing.name,
        type: existing.type,
        icon: existing.icon,
        color: existing.color,
        sortOrder: existing.sortOrder,
        createdAt: existing.createdAt,
        updatedAt: now,
        isDeleted: existing.isDeleted,
        isArchived: existing.isArchived,
        isUserArchived: true,
        carryForwardTargetLedgerId: existing.carryForwardTargetLedgerId,
        syncVersion: existing.syncVersion + 1,
      );

      await _database.transaction(() async {
        await _ledgerLocalDataSource.updateLedger(updated);
        await _appendAuditLog(
          entityType: 'ledger',
          entityId: updated.id,
          action: 'USER_ARCHIVE',
          payload: encodePayload({'id': updated.id}),
        );
      });

      return Right(updated.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Ledger>> unarchiveLedger(String ledgerId) async {
    try {
      final existing = await _ledgerLocalDataSource.getLedgerById(ledgerId);
      if (existing == null || existing.isDeleted) {
        return Left(notFoundFailure('Ledger', ledgerId));
      }

      final now = DateTime.now().toUtc();
      final updated = LedgerModel(
        id: existing.id,
        name: existing.name,
        type: existing.type,
        icon: existing.icon,
        color: existing.color,
        sortOrder: existing.sortOrder,
        createdAt: existing.createdAt,
        updatedAt: now,
        isDeleted: existing.isDeleted,
        isArchived: existing.isArchived,
        carryForwardTargetLedgerId: existing.carryForwardTargetLedgerId,
        syncVersion: existing.syncVersion + 1,
      );

      await _database.transaction(() async {
        await _ledgerLocalDataSource.updateLedger(updated);
        await _appendAuditLog(
          entityType: 'ledger',
          entityId: updated.id,
          action: 'USER_UNARCHIVE',
          payload: encodePayload({'id': updated.id}),
        );
      });

      return Right(updated.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, CarryForwardPreview>> previewCarryForward({
    required String sourceLedgerId,
    required String targetLedgerId,
  }) async {
    try {
      final validation = await _validateCarryForwardLedgers(
        sourceLedgerId: sourceLedgerId,
        targetLedgerId: targetLedgerId,
      );
      if (validation.isLeft()) {
        return Left(validation.getLeft().toNullable()!);
      }

      final (source, target) = validation.getRight().toNullable()!;
      final rows = await _loadCarryForwardRows(source.id);
      return Right(_buildCarryForwardPreview(source, target, rows));
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, CarryForwardResult>> archiveWithCarryForward(
    ArchiveWithCarryForwardParams params,
  ) async {
    try {
      final sourceId = params.sourceLedgerId.trim();
      final targetId = params.targetLedgerId.trim();
      if (sourceId.isEmpty || targetId.isEmpty) {
        return const Left(
          ValidationFailure(
            'Source and target ledger ids are required.',
            code: 'ledger_id_required',
          ),
        );
      }

      final sourceModel = await _ledgerLocalDataSource.getLedgerById(sourceId);
      if (sourceModel == null || sourceModel.isDeleted) {
        return Left(notFoundFailure('Ledger', sourceId));
      }

      if (sourceModel.carryForwardTargetLedgerId != null) {
        return Right(
          CarryForwardResult(
            archivedLedger: sourceModel.toDomain(),
            contactsCreated: 0,
            transactionsCreated: 0,
            targetLedgerId: sourceModel.carryForwardTargetLedgerId!,
          ),
        );
      }

      final validation = await _validateCarryForwardLedgers(
        sourceLedgerId: sourceId,
        targetLedgerId: targetId,
        sourceModel: sourceModel,
      );
      if (validation.isLeft()) {
        return Left(validation.getLeft().toNullable()!);
      }

      final (source, target) = validation.getRight().toNullable()!;
      final rows = await _loadCarryForwardRows(source.id);
      if (rows.isEmpty) {
        return const Left(
          ValidationFailure(
            'No balances to carry forward.',
            code: 'no_balances_to_carry',
          ),
        );
      }

      final ceremonyAt = DateTime.now().toUtc();
      var contactsCreated = 0;
      var transactionsCreated = 0;
      final totalsByCurrency = <String, int>{};
      for (final row in rows) {
        final currency = row.currencyCode.trim().toUpperCase();
        totalsByCurrency[currency] =
            (totalsByCurrency[currency] ?? 0) + row.netBalance;
      }

      final archivedLedger = await _database.transaction(() async {
        final targetContacts = await (_database.select(_database.contacts)
              ..where((table) => table.ledgerId.equals(targetId))
              ..where((table) => table.isDeleted.equals(false))
              ..where((table) => table.isArchived.equals(false)))
            .get();
        final targetContactsByName = {
          for (final row in targetContacts)
            row.name.trim().normalizeArabic(): ContactModel.fromDrift(row),
        };

        final grouped = <String, List<_CarryForwardRow>>{};
        for (final row in rows) {
          grouped.putIfAbsent(row.contact.id, () => []).add(row);
        }

        for (final entry in grouped.entries) {
          final sourceContact = entry.value.first.contact;
          final normalizedName = sourceContact.name.trim().normalizeArabic();
          final existingTarget = targetContactsByName[normalizedName];
          late final String targetContactId;

          if (existingTarget != null) {
            targetContactId = existingTarget.id;
          } else {
            final newContact = ContactModel(
              id: UuidUtil.generate(),
              ledgerId: targetId,
              name: sourceContact.name,
              phone: sourceContact.phone,
              email: sourceContact.email,
              notes: sourceContact.notes,
              creditLimit: sourceContact.creditLimit,
              creditCurrency: sourceContact.creditCurrency,
              avatarColor: sourceContact.avatarColor,
              createdAt: ceremonyAt,
              updatedAt: ceremonyAt,
            );
            final faultIndex =
                _carryForwardTestFaults?.throwBeforeNewContactInsertAt;
            if (faultIndex != null && faultIndex == contactsCreated) {
              throw StateError('carry_forward_test_fault');
            }
            await _database
                .into(_database.contacts)
                .insert(newContact.toDrift());
            await upsertContactSearchIndex(
              _database,
              newContact.id,
              newContact.name,
            );
            await _appendAuditLog(
              entityType: 'contact',
              entityId: newContact.id,
              action: 'CREATE',
              payload: encodePayload(
                contactCreateAuditPayload(
                  newContact,
                  carryForwardOperationId: params.operationId,
                ),
              ),
            );
            targetContactsByName[normalizedName] = newContact;
            targetContactId = newContact.id;
            contactsCreated++;
          }

          for (final balanceRow in entry.value) {
            final net = balanceRow.netBalance;
            if (net == 0) {
              continue;
            }

            final transaction = TransactionModel(
              id: UuidUtil.generate(),
              contactId: targetContactId,
              type: net < 0 ? TransactionType.debt : TransactionType.payment,
              amount: net.abs(),
              currency: balanceRow.currencyCode,
              description: params.openingBalanceDescription,
              itemName: params.openingBalanceItemName,
              transactionDate: ceremonyAt,
              attachmentPath: null,
              createdAt: ceremonyAt,
              updatedAt: ceremonyAt,
            );

            await _database
                .into(_database.transactions)
                .insert(transaction.toDrift());
            await _appendAuditLog(
              entityType: 'transaction',
              entityId: transaction.id,
              action: 'CREATE',
              payload: encodePayload(
                transactionCreateAuditPayload(
                  transaction,
                  carryForwardOperationId: params.operationId,
                ),
              ),
            );
            transactionsCreated++;
          }

          await _balanceRecalculationService.recalculateBalancesForContact(
            contactId: targetContactId,
            lastUpdatedAt: ceremonyAt,
          );
        }

        final archived = LedgerModel(
          id: source.id,
          name: source.name,
          type: source.type,
          icon: source.icon,
          color: source.color,
          sortOrder: source.sortOrder,
          createdAt: source.createdAt,
          updatedAt: ceremonyAt,
          isDeleted: source.isDeleted,
          isArchived: source.isArchived,
          isUserArchived: true,
          carryForwardTargetLedgerId: targetId,
          syncVersion: source.syncVersion + 1,
        );

        await _ledgerLocalDataSource.updateLedger(archived);
        await _appendAuditLog(
          entityType: 'ledger',
          entityId: archived.id,
          action: 'UPDATE',
          payload: encodePayload(ledgerCarryForwardUpdateAuditPayload(archived)),
        );
        await _appendAuditLog(
          entityType: 'ledger',
          entityId: archived.id,
          action: 'CARRY_FORWARD',
          payload: encodePayload(
            ledgerCarryForwardCeremonyAuditPayload(
              operationId: params.operationId,
              sourceLedgerId: sourceId,
              targetLedgerId: targetId,
              targetLedgerName: target.name,
              contactsCreated: contactsCreated,
              transactionsCreated: transactionsCreated,
              totalsByCurrency: totalsByCurrency,
            ),
          ),
        );

        return archived;
      });

      return Right(
        CarryForwardResult(
          archivedLedger: archivedLedger.toDomain(),
          contactsCreated: contactsCreated,
          transactionsCreated: transactionsCreated,
          targetLedgerId: targetId,
        ),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  Future<Either<Failure, (LedgerModel, LedgerModel)>> _validateCarryForwardLedgers({
    required String sourceLedgerId,
    required String targetLedgerId,
    LedgerModel? sourceModel,
  }) async {
    if (sourceLedgerId == targetLedgerId) {
      return const Left(
        ValidationFailure(
          'Source and target ledger must differ.',
          code: 'carry_forward_same_ledger',
        ),
      );
    }

    final source =
        sourceModel ?? await _ledgerLocalDataSource.getLedgerById(sourceLedgerId);
    if (source == null || source.isDeleted) {
      return Left(notFoundFailure('Ledger', sourceLedgerId));
    }
    if (source.isUserArchived) {
      return const Left(
        ValidationFailure(
          'Source ledger is already archived.',
          code: 'ledger_archived',
        ),
      );
    }

    final target = await _ledgerLocalDataSource.getLedgerById(targetLedgerId);
    if (target == null || target.isDeleted) {
      return Left(notFoundFailure('Ledger', targetLedgerId));
    }
    if (target.isUserArchived || target.isArchived) {
      return const Left(
        ValidationFailure(
          'Target ledger is not eligible for carry forward.',
          code: 'carry_forward_invalid_target',
        ),
      );
    }

    return Right((source, target));
  }

  Future<List<_CarryForwardRow>> _loadCarryForwardRows(String sourceLedgerId) async {
    final contacts = _database.contacts;
    final balances = _database.contactBalances;
    final rows =
        await (_database.select(contacts).join([
              drift.innerJoin(
                balances,
                balances.contactId.equalsExp(contacts.id),
              ),
            ])
              ..where(
                contacts.ledgerId.equals(sourceLedgerId) &
                    contacts.isDeleted.equals(false) &
                    contacts.isArchived.equals(false) &
                    balances.netBalance.equals(0).not(),
              )
              ..orderBy([
                drift.OrderingTerm(expression: contacts.name),
                drift.OrderingTerm(expression: balances.currencyCode),
              ]))
            .get();

    return rows
        .map(
          (row) => _CarryForwardRow(
            contact: ContactModel.fromDrift(row.readTable(contacts)),
            currencyCode: row.readTable(balances).currencyCode,
            netBalance: row.readTable(balances).netBalance,
          ),
        )
        .toList(growable: false);
  }

  CarryForwardPreview _buildCarryForwardPreview(
    LedgerModel source,
    LedgerModel target,
    List<_CarryForwardRow> rows,
  ) {
    final contactIds = <String>{};
    final totalsByCurrency = <String, int>{};

    for (final row in rows) {
      contactIds.add(row.contact.id);
      final currency = row.currencyCode.trim().toUpperCase();
      totalsByCurrency[currency] =
          (totalsByCurrency[currency] ?? 0) + row.netBalance;
    }

    return CarryForwardPreview(
      contactCount: contactIds.length,
      transactionCount: rows.length,
      totalsByCurrency: totalsByCurrency,
      sourceLedgerName: source.name,
      targetLedgerName: target.name,
    );
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

class _CarryForwardRow {
  const _CarryForwardRow({
    required this.contact,
    required this.currencyCode,
    required this.netBalance,
  });

  final ContactModel contact;
  final String currencyCode;
  final int netBalance;
}
