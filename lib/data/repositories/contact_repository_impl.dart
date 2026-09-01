import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/balance_local_ds.dart';
import 'package:daftar/data/datasources/local/contact_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/datasources/local/transaction_local_ds.dart';
import 'package:daftar/data/mappers/audit_payload_mapper.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/contact_summary_row.dart';
import 'package:daftar/data/repositories/balance_recalculation_service.dart';
import 'package:daftar/data/repositories/contact_search_index_utils.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:daftar/domain/value_objects/contact_with_summary.dart';
import 'package:daftar/domain/value_objects/reminder_eligible_contact_entry.dart';
import 'package:daftar/domain/value_objects/voice_entity_resolution_entry.dart';
import 'package:drift/drift.dart' as drift;
import 'package:fpdart/fpdart.dart';

/// Drift-backed implementation of [ContactRepository].
class ContactRepositoryImpl implements ContactRepository {
  /// Creates a contact repository implementation.
  ContactRepositoryImpl({
    required ContactLocalDataSource contactLocalDataSource,
    required TransactionLocalDataSource transactionLocalDataSource,
    required BalanceLocalDataSource balanceLocalDataSource,
    required AuditLogLocalDataSource auditLogLocalDataSource,
  }) : _contactLocalDataSource = contactLocalDataSource,
       _transactionLocalDataSource = transactionLocalDataSource,
       _auditLogLocalDataSource = auditLogLocalDataSource,
       _balanceRecalculationService = BalanceRecalculationService(
         database: contactLocalDataSource.database,
         balanceLocalDataSource: balanceLocalDataSource,
       );

  final ContactLocalDataSource _contactLocalDataSource;
  final TransactionLocalDataSource _transactionLocalDataSource;
  final AuditLogLocalDataSource _auditLogLocalDataSource;
  final BalanceRecalculationService _balanceRecalculationService;

  db.AppDatabase get _database => _contactLocalDataSource.database;

  @override
  Stream<List<Contact>> watchByLedger(String ledgerId) {
    return _contactLocalDataSource
        .watchContactsByLedger(ledgerId)
        .map(
          (models) =>
              models.map((model) => model.toDomain()).toList(growable: false),
        );
  }

  @override
  Stream<int> watchContactCountByLedger(String ledgerId) {
    return _contactLocalDataSource.watchContactCountByLedger(ledgerId);
  }

  @override
  Stream<List<ContactWithSummary>> watchContactSummariesByLedger(
    String ledgerId,
  ) {
    return _contactLocalDataSource
        .watchContactSummariesByLedger(ledgerId)
        .map((rows) => _groupSummaryRows(ledgerId, rows));
  }

  @override
  Future<Either<Failure, List<Contact>>> getByLedger(String ledgerId) async {
    try {
      final contacts = await _contactLocalDataSource
          .watchContactsByLedger(ledgerId)
          .first;
      return Right(
        contacts.map((model) => model.toDomain()).toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Contact>> getById(String id) async {
    try {
      final contact = await _contactLocalDataSource.getContactById(id);
      if (contact == null || contact.isDeleted) {
        return Left(notFoundFailure('Contact', id));
      }

      return Right(contact.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<ContactSearchHit>>> search(
    String query, {
    bool excludeUserArchivedLedgers = false,
  }) async {
    try {
      final rows = await _contactLocalDataSource.searchContacts(
        query,
        excludeUserArchivedLedgers: excludeUserArchivedLedgers,
      );
      return Right(
        rows
            .map(
              (row) => ContactSearchHit(
                contact: row.contact.toDomain(),
                ledgerName: row.ledgerName,
                isLedgerUserArchived: row.isLedgerUserArchived,
              ),
            )
            .toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<VoiceEntityResolutionEntry>>>
  getVoiceEntityResolutionContext() async {
    try {
      final rows =
          await _contactLocalDataSource.getVoiceEntityResolutionContext();
      return Right(
        rows
            .map(
              (row) => VoiceEntityResolutionEntry(
                contactId: row.contactId,
                contactName: row.contactName,
                ledgerId: row.ledgerId,
              ),
            )
            .toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<ReminderEligibleContactEntry>>>
  getContactsEligibleForAutomatedReminders() async {
    try {
      final rows = await _contactLocalDataSource
          .getContactsEligibleForAutomatedReminders();
      return Right(
        rows
            .map(
              (row) => ReminderEligibleContactEntry(
                contactId: row.contactId,
                contactName: row.contactName,
                ledgerId: row.ledgerId,
                phone: row.phone,
                email: row.email,
              ),
            )
            .toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Contact>> create(CreateContactParams params) async {
    try {
      final now = DateTime.now().toUtc();
      final contact = ContactModel(
        id: UuidUtil.generate(),
        ledgerId: params.ledgerId,
        name: params.name.trim(),
        phone: params.phone,
        email: params.email,
        notes: params.notes,
        creditLimit: params.creditLimit,
        creditCurrency: params.creditCurrency,
        avatarColor: params.avatarColor,
        createdAt: now,
        updatedAt: now,
        isArchived: params.isArchived,
      );

      await _database.transaction(() async {
        await _database.into(_database.contacts).insert(contact.toDrift());
        if (!params.isArchived) {
          await upsertContactSearchIndex(_database, contact.id, contact.name);
        }
        await _appendAuditLog(
          entityType: 'contact',
          entityId: contact.id,
          action: 'CREATE',
          payload: encodePayload(contactCreateAuditPayload(contact)),
        );
      });

      return Right(contact.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Contact>> update(UpdateContactParams params) async {
    try {
      final existing = await _contactLocalDataSource.getContactById(params.id);
      if (existing == null || existing.isDeleted) {
        return Left(notFoundFailure('Contact', params.id));
      }

      final updated = ContactModel(
        id: existing.id,
        ledgerId: existing.ledgerId,
        name: params.name?.trim() ?? existing.name,
        phone: params.phone ?? existing.phone,
        email: params.updateEmail ? params.email : existing.email,
        notes: params.notes ?? existing.notes,
        creditLimit: params.creditLimit ?? existing.creditLimit,
        creditCurrency: params.creditCurrency ?? existing.creditCurrency,
        avatarColor: existing.avatarColor,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now().toUtc(),
        isDeleted: existing.isDeleted,
        syncVersion: existing.syncVersion + 1,
      );

      await _database.transaction(() async {
        await (_database.update(_database.contacts)
              ..where((table) => table.id.equals(updated.id)))
            .write(updated.toCompanion());
        await upsertContactSearchIndex(_database, updated.id, updated.name);
        await _appendAuditLog(
          entityType: 'contact',
          entityId: updated.id,
          action: 'UPDATE',
          payload: encodePayload({
            'name': updated.name,
            'phone': updated.phone,
            'email': updated.email,
            'notes': updated.notes,
            'creditLimit': updated.creditLimit,
            'creditCurrency': updated.creditCurrency,
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
      final existing = await _contactLocalDataSource.getContactById(id);
      if (existing == null || existing.isDeleted) {
        return Left(notFoundFailure('Contact', id));
      }

      final transactionRows = await (_database.select(
        _database.transactions,
      )..where((table) => table.contactId.equals(id))).get();
      final now = _cascadeDeleteTimestamp(
        transactionRows.map((row) => row.updatedAt),
      );

      await _database.transaction(() async {
        await (_database.update(
          _database.contacts,
        )..where((table) => table.id.equals(id))).write(
          ContactModel(
            id: existing.id,
            ledgerId: existing.ledgerId,
            name: existing.name,
            phone: existing.phone,
            email: existing.email,
            notes: existing.notes,
            creditLimit: existing.creditLimit,
            creditCurrency: existing.creditCurrency,
            avatarColor: existing.avatarColor,
            createdAt: existing.createdAt,
            updatedAt: now,
            isDeleted: true,
            syncVersion: existing.syncVersion + 1,
          ).toCompanion(),
        );

        final deletedTransactionCount =
            await _transactionLocalDataSource
                .bulkSoftDeleteTransactionsByContactIds(
          [id],
          updatedAt: now,
        );

        await (_database.delete(
          _database.contactBalances,
        )..where((table) => table.contactId.equals(id))).go();

        await removeContactSearchIndex(_database, id);
        // TODO(aiAudit): record child-level audit logs for cascaded transaction deletes.
        await _appendAuditLog(
          entityType: 'contact',
          entityId: id,
          action: 'DELETE',
          payload: encodePayload({
            'id': id,
            'deletedTransactionCount': deletedTransactionCount,
          }),
        );
      });

      return const Right(unit);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Contact>> restore(String id) async {
    try {
      final existing = await _contactLocalDataSource.getContactById(id);
      if (existing == null || !existing.isDeleted) {
        return Left(notFoundFailure('Contact', id));
      }

      final deletedAt = existing.updatedAt;
      final restoredAt = DateTime.now().toUtc();

      final restoredContact = ContactModel(
        id: existing.id,
        ledgerId: existing.ledgerId,
        name: existing.name,
        phone: existing.phone,
        email: existing.email,
        notes: existing.notes,
        creditLimit: existing.creditLimit,
        creditCurrency: existing.creditCurrency,
        avatarColor: existing.avatarColor,
        createdAt: existing.createdAt,
        updatedAt: restoredAt,
        syncVersion: existing.syncVersion + 1,
      );

      await _database.transaction(() async {
        await (_database.update(
          _database.contacts,
        )..where((table) => table.id.equals(id))).write(
          restoredContact.toCompanion(),
        );
        await upsertContactSearchIndex(_database, id, restoredContact.name);

        final restoredTransactionCount =
            await _transactionLocalDataSource.bulkRestoreTransactionsByContactIds(
          contactIds: [id],
          deletedAt: deletedAt,
          restoredAt: restoredAt,
        );

        await _balanceRecalculationService.recalculateBalancesForContact(
          contactId: id,
          lastUpdatedAt: restoredAt,
        );
        // TODO(aiAudit): record child-level audit logs for cascaded transaction restores.
        await _appendAuditLog(
          entityType: 'contact',
          entityId: id,
          action: 'RESTORE',
          payload: encodePayload({
            'id': id,
            'restoredTransactionCount': restoredTransactionCount,
          }),
        );
      });

      return Right(restoredContact.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, int>> getActiveCount() async {
    try {
      return Right(await _countActiveContacts());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  Future<int> _countActiveContacts() async {
    final result = await _database
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM contacts '
          'WHERE is_deleted = 0 AND is_archived = 0',
          readsFrom: {_database.contacts},
        )
        .getSingle();
    return result.read<int>('cnt');
  }

  @override
  Future<Either<Failure, int>> getArchivedCount() async {
    try {
      final result = await _database
          .customSelect(
            'SELECT COUNT(*) AS cnt FROM contacts '
            'WHERE is_deleted = 0 AND is_archived = 1',
            readsFrom: {_database.contacts},
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
      final query = _database.select(_database.contacts).join([
        drift.innerJoin(
          _database.ledgers,
          _database.ledgers.id.equalsExp(_database.contacts.ledgerId),
        ),
      ])
        ..where(
          _database.contacts.isDeleted.equals(false) &
              _database.contacts.isArchived.equals(true) &
              _database.ledgers.isDeleted.equals(false) &
              _database.ledgers.isArchived.equals(false),
        )
        ..limit(limit);

      final rows = await query.get();
      if (rows.isEmpty) {
        return const Right(0);
      }

      final ids = rows
          .map((row) => row.readTable(_database.contacts).id)
          .toList(growable: false);

      await _database.transaction(() async {
        await (_database.update(_database.contacts)
              ..where((table) => table.id.isIn(ids)))
            .write(
          db.ContactsCompanion(
            isArchived: const drift.Value(false),
            updatedAt: drift.Value(now),
          ),
        );
        for (final row in rows) {
          final contact = row.readTable(_database.contacts);
          await upsertContactSearchIndex(
            _database,
            contact.id,
            contact.name,
          );
          await _appendAuditLog(
            entityType: 'contact',
            entityId: contact.id,
            action: 'ACTIVATE_ARCHIVED',
            payload: encodePayload({'id': contact.id}),
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

  static List<ContactWithSummary> _groupSummaryRows(
    String ledgerId,
    List<ContactSummaryRow> rows,
  ) {
    final contactFields = <String, ContactSummaryRow>{};
    final groupedBalances = <String, List<ContactBalanceSummary>>{};
    final order = <String>[];

    for (final row in rows) {
      if (!contactFields.containsKey(row.contactId)) {
        contactFields[row.contactId] = row;
        order.add(row.contactId);
        groupedBalances[row.contactId] = [];
      }

      final currencyCode = row.currencyCode;
      if (currencyCode != null) {
        groupedBalances[row.contactId]!.add(
          ContactBalanceSummary(
            currencyCode: currencyCode,
            totalDebt: row.totalDebt!,
            totalPayment: row.totalPayment!,
            netBalance: row.netBalance!,
          ),
        );
      }
    }

    return order
        .map((contactId) {
          final row = contactFields[contactId]!;
          return ContactWithSummary(
            contactId: contactId,
            ledgerId: ledgerId,
            name: row.name,
            phone: row.phone,
            avatarColor: row.avatarColor,
            creditLimit: row.creditLimit,
            creditCurrency: row.creditCurrency,
            transactionCount: row.transactionCount,
            balances: groupedBalances[contactId]!.toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  static DateTime _cascadeDeleteTimestamp(Iterable<DateTime> priorUpdatedAts) {
    final now = DateTime.now().toUtc();
    var stamp = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
    for (final prior in priorUpdatedAts) {
      final priorSecond = DateTime.utc(
        prior.year,
        prior.month,
        prior.day,
        prior.hour,
        prior.minute,
        prior.second,
      );
      if (!stamp.isAfter(priorSecond)) {
        stamp = priorSecond.add(const Duration(seconds: 1));
      }
    }
    return stamp;
  }
}
