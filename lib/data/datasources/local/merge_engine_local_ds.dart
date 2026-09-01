import 'dart:convert';

import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/merge_conflict_mapper.dart';
import 'package:daftar/data/models/merge_conflict_model.dart';
import 'package:daftar/data/models/sync_operation_model.dart';
import 'package:daftar/domain/enums/conflict_type.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:drift/drift.dart';

/// Core merge engine data source — all conflict resolution logic.
///
/// The entire merge pipeline runs inside a single Drift [transaction()]
/// for ACID guarantees. No partial state is ever visible.
///
/// ## Merge Pipeline
///
/// 1. **Idempotency guard**: Check `(entityId, deviceId, opId)` existence.
/// 2. **Entity-type routing**: Dispatch to `_mergeLedger`, `_mergeContact`,
///    or `_mergeTransaction`.
/// 3. **Field-level LWW**: Per-field last-write-wins with deterministic
///    tiebreaker (Owner > Editor > lowest deviceId).
/// 4. **Safety rules**: Modification > deletion, transactions additive.
/// 5. **Conflict surfacing**: Ambiguous cases flagged to merge_conflicts.
/// 6. **Balance recalculation**: Triggered after transaction merges.
class MergeEngineLocalDs {
  /// Creates the merge engine local data source.
  ///
  /// [localDeviceId] and [localRole] feed the deterministic LWW tiebreaker
  /// (Owner > Editor > lowest deviceId).
  MergeEngineLocalDs(
    this._db, {
    this.localDeviceId = 'local-device',
    this.localRole = 'editor',
  });

  final db.AppDatabase _db;

  /// This device's stable id for LWW device-id tiebreaks.
  final String localDeviceId;

  /// This device's workspace role for LWW role tiebreaks.
  final String localRole;

  /// Role priority for the deterministic tiebreaker.
  /// Higher value = higher priority.
  static const Map<String, int> _rolePriority = {
    'owner': 2,
    'editor': 1,
    'viewer': 0,
  };

  /// Entity types this engine knows how to merge.
  static const Set<String> _syncableEntityTypes = {
    'ledger',
    'contact',
    'transaction',
  };

  // ══════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ══════════════════════════════════════════════════════════════════════

  /// Applies a batch of remote operations inside a single ACID transaction.
  ///
  /// Returns the merge result with applied/skipped counts, conflicts,
  /// and contact IDs needing balance recalculation.
  ///
  /// [localRoleOverride] is scoped to this call only — concurrent invocations
  /// never observe each other's role.
  Future<MergeEngineResult> applyRemoteOps(
    List<SyncOperationModel> ops, {
    String? localRoleOverride,
  }) async {
    return _applyRemoteOps(
      ops,
      _MergeContext(localRole: localRoleOverride ?? localRole),
    );
  }

  Future<MergeEngineResult> _applyRemoteOps(
    List<SyncOperationModel> ops,
    _MergeContext ctx,
  ) async {
    // Sort by server-assigned sequence number (ordering authority).
    // Every device replays the identical order, which is what makes the
    // tiebreaker below convergent.
    final sorted = List<SyncOperationModel>.of(ops)
      ..sort((a, b) => a.opSeq.compareTo(b.opSeq));

    var applied = 0;
    var skipped = 0;
    final conflicts = <MergeConflictModel>[];
    final affectedContactIds = <String>{};
    final auditNotes = <String>[];

    await _db.transaction(() async {
      for (final op in sorted) {
        // ── Step 1: Idempotency guard ────────────────────────────────
        final alreadyApplied = await _isAlreadyApplied(op);
        if (alreadyApplied) {
          skipped++;
          continue;
        }

        // ── Step 2: Route by entity type ─────────────────────────────
        // A hostile or malformed payload must never abort the batch: a
        // single uncaught cast would roll back every op merged before it
        // and, because nothing is recorded, wedge sync on the next pull.
        _OpResult result;
        try {
          result = await _applyOp(op, ctx);
        } on Object catch (error) {
          result = await _surfaceAmbiguousConflict(
            op,
            'Rejected malformed op payload: $error',
          );
        }

        // ── Step 3: Record for idempotency ───────────────────────────
        // Every decided op is recorded — including rejected ones — so a
        // replayed pull can never re-surface the same conflict.
        await _recordAppliedOp(op);
        if (result.conflicts.isEmpty) {
          applied++;
        } else {
          skipped++;
        }

        // ── Step 4: Accumulate results ───────────────────────────────
        conflicts.addAll(result.conflicts);
        affectedContactIds.addAll(result.affectedContactIds);
        auditNotes.addAll(result.auditNotes);
      }

      // ── Step 5: Recalculate balances for all affected contacts ─────
      for (final contactId in affectedContactIds) {
        await _recalculateBalance(contactId);
      }
    });

    return MergeEngineResult(
      applied: applied,
      skipped: skipped,
      conflicts: conflicts,
      recalculatedContactIds: affectedContactIds.toList(),
      auditNotes: auditNotes,
    );
  }

  /// Returns all unresolved merge conflicts.
  Future<List<MergeConflictModel>> getUnresolvedConflicts() async {
    final rows =
        await (_db.select(_db.mergeConflicts)
              ..where((t) => t.isResolved.equals(false))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.detectedAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    return rows.map((r) => r.toModel()).toList(growable: false);
  }

  /// Resolves a specific merge conflict by applying the chosen snapshot.
  Future<void> resolveConflict({
    required String conflictId,
    required bool chooseLocal,
  }) async {
    await _db.transaction(() async {
      final conflict = await (_db.select(_db.mergeConflicts)
            ..where((t) => t.id.equals(conflictId)))
          .getSingleOrNull();
      if (conflict == null || conflict.isResolved) {
        return;
      }

      if (!chooseLocal) {
        await _applyChosenRemoteSnapshot(conflict);
      }
      // chooseLocal: keep current local entity state (already winning).

      await (_db.update(_db.mergeConflicts)
            ..where((t) => t.id.equals(conflictId)))
          .write(
        db.MergeConflictsCompanion(
          isResolved: const Value(true),
          resolvedAt: Value(DateTime.now().toUtc()),
        ),
      );
    });
  }

  /// Applies remote snapshot fields when the user chooses remote.
  Future<void> _applyChosenRemoteSnapshot(db.MergeConflict conflict) async {
    final remote = _parseFieldDeltas(conflict.remoteSnapshot) ?? {};
    final now = DateTime.now().toUtc();
    final isDeleteVsEdit =
        conflict.conflictType == ConflictType.deleteVsEdit.name;

    switch (conflict.entityType) {
      case 'ledger':
        if (isDeleteVsEdit) {
          await (_db.update(_db.ledgers)
                ..where((t) => t.id.equals(conflict.entityId)))
              .write(
            db.LedgersCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(now),
            ),
          );
          await _cascadeDeleteLedgerChildren(conflict.entityId, now);
        } else if (remote.isNotEmpty) {
          await (_db.update(_db.ledgers)
                ..where((t) => t.id.equals(conflict.entityId)))
              .write(
            db.LedgersCompanion(
              name: _snapshotValue(remote, 'name', _asString),
              icon: _snapshotValue(remote, 'icon', _asString),
              color: _snapshotValue(remote, 'color', _asString),
              sortOrder: _snapshotValue(remote, 'sortOrder', _asInt),
              updatedAt: Value(now),
            ),
          );
        }
      case 'contact':
        if (isDeleteVsEdit) {
          await (_db.update(_db.contacts)
                ..where((t) => t.id.equals(conflict.entityId)))
              .write(
            db.ContactsCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(now),
            ),
          );
          await _cascadeDeleteContactTransactions(conflict.entityId, now);
          await _recalculateBalance(conflict.entityId);
        } else if (remote.isNotEmpty) {
          await (_db.update(_db.contacts)
                ..where((t) => t.id.equals(conflict.entityId)))
              .write(
            db.ContactsCompanion(
              name: _snapshotValue(remote, 'name', _asString),
              phone: _snapshotNullable(remote, 'phone', _asString),
              email: _snapshotNullable(remote, 'email', _asString),
              notes: _snapshotNullable(remote, 'notes', _asString),
              updatedAt: Value(now),
            ),
          );
        }
      case 'transaction':
        final existing = await (_db.select(_db.transactions)
              ..where((t) => t.id.equals(conflict.entityId)))
            .getSingleOrNull();
        if (existing == null) {
          return;
        }
        if (isDeleteVsEdit) {
          await (_db.update(_db.transactions)
                ..where((t) => t.id.equals(conflict.entityId)))
              .write(
            db.TransactionsCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(now),
            ),
          );
          await _recalculateBalance(existing.contactId);
        } else {
          final amount = _asInt(remote['amount']);
          if (amount == null || amount < 0) {
            return;
          }
          await (_db.update(_db.transactions)
                ..where((t) => t.id.equals(conflict.entityId)))
              .write(
            db.TransactionsCompanion(
              amount: Value(amount),
              updatedAt: Value(now),
            ),
          );
          await _recalculateBalance(existing.contactId);
        }
    }
  }

  /// Returns the highest applied op_seq (watermark).
  Future<int> getLastAppliedOpSeq() async {
    final result = await _db.customSelect(
      'SELECT MAX(op_seq) AS max_seq FROM sync_operations',
    ).getSingleOrNull();

    return result?.read<int?>('max_seq') ?? 0;
  }

  /// Returns the cursor for the next `since_op_seq` request.
  ///
  /// Takes the greater of the server's last cursor and the applied high
  /// water mark: the stored cursor can legitimately run ahead (the server
  /// withholds ops it will not replay), and the applied log protects a
  /// device whose cursor predates this column.
  Future<int> getPullWatermark() async {
    final stored = await (_db.select(_db.appSettingsTable)
          ..where((t) => t.id.equals(DbConstants.appSettingsId)))
        .getSingleOrNull();
    final applied = await getLastAppliedOpSeq();
    final cursor = stored?.syncPullWatermarkOpSeq ?? 0;
    return cursor > applied ? cursor : applied;
  }

  /// Persists the server-supplied cursor, never rewinding it.
  Future<void> recordPullWatermark(int nextSinceOpSeq) async {
    final current = await getPullWatermark();
    if (nextSinceOpSeq <= current) {
      return;
    }
    await (_db.update(_db.appSettingsTable)
          ..where((t) => t.id.equals(DbConstants.appSettingsId)))
        .write(
      db.AppSettingsTableCompanion(
        syncPullWatermarkOpSeq: Value(nextSinceOpSeq),
      ),
    );
  }

  /// Returns the latest server_updated_at among applied remote ops.
  Future<DateTime?> getLastAppliedServerUpdatedAt() async {
    final row = await (_db.select(_db.syncOperations)
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.serverUpdatedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(1))
        .getSingleOrNull();
    return row?.serverUpdatedAt.toUtc();
  }

  /// Returns the count of unresolved conflicts.
  Future<int> getUnresolvedConflictCount() async {
    final count = _db.mergeConflicts.isResolved.count(
      filter: _db.mergeConflicts.isResolved.equals(false),
    );
    final query = _db.selectOnly(_db.mergeConflicts)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  // ══════════════════════════════════════════════════════════════════════
  // IDEMPOTENCY
  // ══════════════════════════════════════════════════════════════════════

  /// Checks if an operation has already been applied (idempotency guard).
  ///
  /// Keyed on the op id alone: the id is the originating device's audit-log
  /// UUID and is the primary key here, so a replayed pull whose entityId or
  /// deviceId drifted must still be treated as a duplicate rather than
  /// colliding on insert.
  Future<bool> _isAlreadyApplied(SyncOperationModel op) async {
    final existing = await (_db.select(_db.syncOperations)
          ..where((t) => t.id.equals(op.id))
          ..limit(1))
        .getSingleOrNull();

    return existing != null;
  }

  /// Records a successfully applied operation for idempotency tracking.
  Future<void> _recordAppliedOp(SyncOperationModel op) async {
    await _db.into(_db.syncOperations).insert(
          op.toDrift(),
          mode: InsertMode.insertOrReplace,
        );
  }

  // ══════════════════════════════════════════════════════════════════════
  // OP ROUTING
  // ══════════════════════════════════════════════════════════════════════

  /// Routes an operation to the correct entity-type handler.
  Future<_OpResult> _applyOp(SyncOperationModel op, _MergeContext ctx) async {
    if (!_syncableEntityTypes.contains(op.entityType)) {
      // Unknown entity type — surface as ambiguous conflict.
      return _surfaceAmbiguousConflict(op, 'Unknown entity type');
    }

    // Ledger-scoped ceremony log with no field payload of its own; the
    // actual rows arrive as their own CREATE ops.
    if (op.action == 'CARRY_FORWARD') {
      return _OpResult.empty();
    }

    switch (op.entityType) {
      case 'ledger':
        return _mergeLedger(op, ctx);
      case 'contact':
        return _mergeContact(op, ctx);
      default:
        return _mergeTransaction(op, ctx);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // LEDGER MERGE
  // ══════════════════════════════════════════════════════════════════════

  Future<_OpResult> _mergeLedger(
    SyncOperationModel op,
    _MergeContext ctx,
  ) async {
    switch (op.action) {
      case 'CREATE':
        return _createLedger(op);
      case 'UPDATE':
        return _updateLedger(op, ctx);
      case 'DELETE':
        return _deleteLedger(op);
      case 'RESTORE':
        return _restoreLedger(op);
      case 'ACTIVATE_ARCHIVED':
        return _setLedgerFlag(op, isArchived: false);
      case 'USER_ARCHIVE':
        return _setLedgerFlag(op, isUserArchived: true);
      case 'USER_UNARCHIVE':
        return _setLedgerFlag(op, isUserArchived: false);
      default:
        return _surfaceAmbiguousConflict(op, 'Unknown action: ${op.action}');
    }
  }

  Future<_OpResult> _createLedger(SyncOperationModel op) async {
    final existing =
        await (_db.select(_db.ledgers)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();

    if (existing != null) {
      if (op.deviceId == localDeviceId) {
        // Echo of this device's own push — already in local state.
        return _OpResult.empty();
      }
      // Entity already exists — this could be a concurrent create.
      // Surface as conflict for user resolution.
      return _surfaceConcurrentCreate(op, 'ledger', existing.toCompanion(false).toString());
    }

    final deltas = _parseFieldDeltas(op.fieldDeltas);
    if (deltas == null) {
      return _surfaceAmbiguousConflict(op, 'CREATE op missing field deltas');
    }

    await _db.into(_db.ledgers).insert(
      db.LedgersCompanion.insert(
        id: op.entityId,
        name: _asString(deltas['name']) ?? '',
        type: _parseLedgerType(_asString(deltas['type'])),
        icon: _asString(deltas['icon']) ?? 'store',
        color: _asString(deltas['color']) ?? '#6E6E76',
        sortOrder: _asInt(deltas['sortOrder']) ?? 0,
        createdAt: Value(op.localTimestamp),
        updatedAt: Value(op.serverUpdatedAt),
        syncVersion: Value(op.opSeq),
      ),
    );

    return _OpResult.empty();
  }

  Future<_OpResult> _updateLedger(
    SyncOperationModel op,
    _MergeContext ctx,
  ) async {
    final existing =
        await (_db.select(_db.ledgers)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();

    if (existing == null) {
      return _surfaceAmbiguousConflict(
        op,
        'UPDATE for missing ledger — pull gap; refusing invent-from-defaults CREATE',
      );
    }

    // ── Modification > Deletion safety rule ──────────────────────────
    // If the entity is deleted locally but being edited remotely,
    // the edit survives — un-delete the entity.
    final auditNotes = <String>[];
    var wasUndeleted = false;
    if (existing.isDeleted) {
      wasUndeleted = true;
      auditNotes.add(
        'Ledger "${existing.name}" un-deleted: remote edit survived '
        'delete-vs-edit race (device: ${op.deviceId})',
      );
    }

    // ── Field-level LWW merge ────────────────────────────────────────
    final deltas = _parseFieldDeltas(op.fieldDeltas);
    if (deltas == null) {
      return _surfaceAmbiguousConflict(op, 'UPDATE op missing/malformed field deltas');
    }

    final authority = await _localAuthority(
      op.entityId,
      existing.updatedAt,
      ctx,
    );

    final companion = db.LedgersCompanion(
      name: _lwwField(deltas, 'name', op, existing.updatedAt, authority,
          _asString),
      icon: _lwwField(deltas, 'icon', op, existing.updatedAt, authority,
          _asString),
      color: _lwwField(deltas, 'color', op, existing.updatedAt, authority,
          _asString),
      sortOrder: _lwwField(deltas, 'sortOrder', op, existing.updatedAt,
          authority, _asInt),
      isUserArchived: _lwwField(deltas, 'isUserArchived', op,
          existing.updatedAt, authority, _asBool),
      carryForwardTargetLedgerId: _lwwNullableField(
          deltas, 'carryForwardTargetLedgerId', op, existing.updatedAt,
          authority, _asString),
      isDeleted: wasUndeleted ? const Value(false) : const Value<bool>.absent(),
      updatedAt: Value(_serverOrderedUpdatedAt(existing.updatedAt, op)),
      syncVersion: Value(op.opSeq),
    );

    await (_db.update(_db.ledgers)..where((t) => t.id.equals(op.entityId)))
        .write(companion);

    return _OpResult(auditNotes: auditNotes);
  }

  Future<_OpResult> _deleteLedger(SyncOperationModel op) async {
    final existing =
        await (_db.select(_db.ledgers)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();

    if (existing == null) {
      return _OpResult.empty();
    }

    // Check if there are newer local edits that should survive.
    if (!existing.isDeleted && existing.updatedAt.isAfter(op.serverUpdatedAt)) {
      return _surfaceDeleteVsEdit(
        op,
        localSnapshot: jsonEncode({'name': existing.name}),
        auditNote:
            'Ledger "${existing.name}" delete-vs-edit conflict: local edit survived (device: ${op.deviceId})',
      );
    }

    if (existing.isDeleted) {
      return _OpResult.empty();
    }

    // Apply soft delete (tombstone) with server clock.
    await (_db.update(_db.ledgers)..where((t) => t.id.equals(op.entityId)))
        .write(
      db.LedgersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(op.serverUpdatedAt),
        syncVersion: Value(op.opSeq),
      ),
    );

    // The originating device cascaded to contacts and transactions without
    // emitting child ops, so mirror that cascade here or the two devices
    // disagree about which transactions are alive — and therefore about
    // every balance under this ledger.
    final contactIds = await _cascadeDeleteLedgerChildren(
      op.entityId,
      op.serverUpdatedAt,
    );

    return _OpResult(affectedContactIds: contactIds);
  }

  Future<_OpResult> _restoreLedger(SyncOperationModel op) async {
    final existing =
        await (_db.select(_db.ledgers)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();

    if (existing == null) {
      return _surfaceAmbiguousConflict(
        op,
        'RESTORE for missing ledger — pull gap',
      );
    }
    if (!existing.isDeleted) {
      return _OpResult.empty();
    }

    // Only the rows tombstoned by the matching cascade delete come back,
    // identified by the delete timestamp they were stamped with.
    final deletedAt = existing.updatedAt;
    final restoredAt = op.serverUpdatedAt;

    await (_db.update(_db.ledgers)..where((t) => t.id.equals(op.entityId)))
        .write(
      db.LedgersCompanion(
        isDeleted: const Value(false),
        updatedAt: Value(restoredAt),
        syncVersion: Value(op.opSeq),
      ),
    );

    final contactIds = (await (_db.select(_db.contacts)
              ..where(
                (t) =>
                    t.ledgerId.equals(op.entityId) &
                    t.isDeleted.equals(true) &
                    t.updatedAt.equals(deletedAt),
              ))
            .get())
        .map((row) => row.id)
        .toList(growable: false);

    if (contactIds.isEmpty) {
      return _OpResult.empty();
    }

    await (_db.update(_db.contacts)
          ..where(
            (t) =>
                t.ledgerId.equals(op.entityId) &
                t.isDeleted.equals(true) &
                t.updatedAt.equals(deletedAt),
          ))
        .write(
      db.ContactsCompanion(
        isDeleted: const Value(false),
        updatedAt: Value(restoredAt),
      ),
    );

    await (_db.update(_db.transactions)
          ..where(
            (t) =>
                t.contactId.isIn(contactIds) &
                t.isDeleted.equals(true) &
                t.updatedAt.equals(deletedAt),
          ))
        .write(
      db.TransactionsCompanion(
        isDeleted: const Value(false),
        updatedAt: Value(restoredAt),
      ),
    );

    return _OpResult(affectedContactIds: contactIds.toSet());
  }

  Future<_OpResult> _setLedgerFlag(
    SyncOperationModel op, {
    bool? isArchived,
    bool? isUserArchived,
  }) async {
    final existing =
        await (_db.select(_db.ledgers)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();
    if (existing == null) {
      return _surfaceAmbiguousConflict(
        op,
        '${op.action} for missing ledger — pull gap',
      );
    }

    await (_db.update(_db.ledgers)..where((t) => t.id.equals(op.entityId)))
        .write(
      db.LedgersCompanion(
        isArchived:
            isArchived == null ? const Value.absent() : Value(isArchived),
        isUserArchived: isUserArchived == null
            ? const Value.absent()
            : Value(isUserArchived),
        updatedAt: Value(_serverOrderedUpdatedAt(existing.updatedAt, op)),
        syncVersion: Value(op.opSeq),
      ),
    );

    return _OpResult.empty();
  }

  // ══════════════════════════════════════════════════════════════════════
  // CONTACT MERGE
  // ══════════════════════════════════════════════════════════════════════

  Future<_OpResult> _mergeContact(
    SyncOperationModel op,
    _MergeContext ctx,
  ) async {
    switch (op.action) {
      case 'CREATE':
        return _createContact(op);
      case 'UPDATE':
        return _updateContact(op, ctx);
      case 'DELETE':
        return _deleteContact(op);
      case 'RESTORE':
        return _restoreContact(op);
      case 'ACTIVATE_ARCHIVED':
        return _activateArchivedContact(op);
      default:
        return _surfaceAmbiguousConflict(op, 'Unknown action: ${op.action}');
    }
  }

  Future<_OpResult> _createContact(SyncOperationModel op) async {
    final existing =
        await (_db.select(_db.contacts)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();

    if (existing != null) {
      if (op.deviceId == localDeviceId) {
        return _OpResult.empty();
      }
      return _surfaceConcurrentCreate(
        op,
        'contact',
        existing.toCompanion(false).toString(),
      );
    }

    final deltas = _parseFieldDeltas(op.fieldDeltas);
    if (deltas == null) {
      return _surfaceAmbiguousConflict(op, 'CREATE op missing field deltas');
    }

    final ledgerId = _asString(deltas['ledgerId']);
    if (ledgerId == null || ledgerId.isEmpty) {
      return _surfaceAmbiguousConflict(
        op,
        'CREATE contact missing ledgerId — refusing orphan row',
      );
    }

    await _db.into(_db.contacts).insert(
      db.ContactsCompanion.insert(
        id: op.entityId,
        ledgerId: ledgerId,
        name: _asString(deltas['name']) ?? '',
        avatarColor: _asString(deltas['avatarColor']) ?? '#6E6E76',
        createdAt: Value(op.localTimestamp),
        updatedAt: Value(op.serverUpdatedAt),
        syncVersion: Value(op.opSeq),
        phone: Value(_asString(deltas['phone'])),
        email: Value(_asString(deltas['email'])),
        notes: Value(_asString(deltas['notes'])),
        creditLimit: Value(_asInt(deltas['creditLimit'])),
        creditCurrency: Value(_asString(deltas['creditCurrency'])),
      ),
    );

    return _OpResult.empty();
  }

  Future<_OpResult> _updateContact(
    SyncOperationModel op,
    _MergeContext ctx,
  ) async {
    final existing =
        await (_db.select(_db.contacts)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();

    if (existing == null) {
      return _surfaceAmbiguousConflict(
        op,
        'UPDATE for missing contact — pull gap; refusing invent-from-defaults CREATE',
      );
    }

    final auditNotes = <String>[];
    var wasUndeleted = false;
    if (existing.isDeleted) {
      wasUndeleted = true;
      auditNotes.add(
        'Contact "${existing.name}" un-deleted: remote edit survived '
        'delete-vs-edit race (device: ${op.deviceId})',
      );
    }

    final deltas = _parseFieldDeltas(op.fieldDeltas);
    if (deltas == null) {
      return _surfaceAmbiguousConflict(op, 'UPDATE op missing/malformed field deltas');
    }

    final authority = await _localAuthority(
      op.entityId,
      existing.updatedAt,
      ctx,
    );

    final companion = db.ContactsCompanion(
      name: _lwwField(deltas, 'name', op, existing.updatedAt, authority,
          _asString),
      phone: _lwwNullableField(deltas, 'phone', op, existing.updatedAt,
          authority, _asString),
      email: _lwwNullableField(deltas, 'email', op, existing.updatedAt,
          authority, _asString),
      notes: _lwwNullableField(deltas, 'notes', op, existing.updatedAt,
          authority, _asString),
      creditLimit: _lwwNullableField(deltas, 'creditLimit', op,
          existing.updatedAt, authority, _asInt),
      creditCurrency: _lwwNullableField(deltas, 'creditCurrency', op,
          existing.updatedAt, authority, _asString),
      avatarColor: _lwwField(deltas, 'avatarColor', op, existing.updatedAt,
          authority, _asString),
      isDeleted: wasUndeleted ? const Value(false) : const Value<bool>.absent(),
      updatedAt: Value(_serverOrderedUpdatedAt(existing.updatedAt, op)),
      syncVersion: Value(op.opSeq),
    );

    await (_db.update(_db.contacts)..where((t) => t.id.equals(op.entityId)))
        .write(companion);

    // Un-deleting a contact resurrects its balance row.
    return _OpResult(
      auditNotes: auditNotes,
      affectedContactIds: wasUndeleted ? {op.entityId} : const {},
    );
  }

  Future<_OpResult> _deleteContact(SyncOperationModel op) async {
    final existing =
        await (_db.select(_db.contacts)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();

    if (existing == null) {
      return _OpResult.empty();
    }

    if (!existing.isDeleted && existing.updatedAt.isAfter(op.serverUpdatedAt)) {
      return _surfaceDeleteVsEdit(
        op,
        localSnapshot: jsonEncode({
          'name': existing.name,
          'phone': existing.phone,
          'email': existing.email,
        }),
        auditNote:
            'Contact "${existing.name}" delete-vs-edit conflict: local edit survived (device: ${op.deviceId})',
      );
    }

    if (existing.isDeleted) {
      return _OpResult.empty();
    }

    await (_db.update(_db.contacts)..where((t) => t.id.equals(op.entityId)))
        .write(
      db.ContactsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(op.serverUpdatedAt),
        syncVersion: Value(op.opSeq),
      ),
    );

    // Mirror the originating device's cascade — see [_deleteLedger].
    await _cascadeDeleteContactTransactions(op.entityId, op.serverUpdatedAt);

    // Contact deletion affects balance display.
    return _OpResult(affectedContactIds: {op.entityId});
  }

  Future<_OpResult> _restoreContact(SyncOperationModel op) async {
    final existing =
        await (_db.select(_db.contacts)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();

    if (existing == null) {
      return _surfaceAmbiguousConflict(
        op,
        'RESTORE for missing contact — pull gap',
      );
    }
    if (!existing.isDeleted) {
      return _OpResult.empty();
    }

    final deletedAt = existing.updatedAt;
    final restoredAt = op.serverUpdatedAt;

    await (_db.update(_db.contacts)..where((t) => t.id.equals(op.entityId)))
        .write(
      db.ContactsCompanion(
        isDeleted: const Value(false),
        updatedAt: Value(restoredAt),
        syncVersion: Value(op.opSeq),
      ),
    );

    await (_db.update(_db.transactions)
          ..where(
            (t) =>
                t.contactId.equals(op.entityId) &
                t.isDeleted.equals(true) &
                t.updatedAt.equals(deletedAt),
          ))
        .write(
      db.TransactionsCompanion(
        isDeleted: const Value(false),
        updatedAt: Value(restoredAt),
      ),
    );

    return _OpResult(affectedContactIds: {op.entityId});
  }

  Future<_OpResult> _activateArchivedContact(SyncOperationModel op) async {
    final existing =
        await (_db.select(_db.contacts)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();
    if (existing == null) {
      return _surfaceAmbiguousConflict(
        op,
        'ACTIVATE_ARCHIVED for missing contact — pull gap',
      );
    }

    await (_db.update(_db.contacts)..where((t) => t.id.equals(op.entityId)))
        .write(
      db.ContactsCompanion(
        isArchived: const Value(false),
        updatedAt: Value(_serverOrderedUpdatedAt(existing.updatedAt, op)),
        syncVersion: Value(op.opSeq),
      ),
    );

    return _OpResult(affectedContactIds: {op.entityId});
  }

  // ══════════════════════════════════════════════════════════════════════
  // TRANSACTION MERGE — FINANCIAL SAFETY CRITICAL
  // ══════════════════════════════════════════════════════════════════════

  Future<_OpResult> _mergeTransaction(
    SyncOperationModel op,
    _MergeContext ctx,
  ) async {
    switch (op.action) {
      case 'CREATE':
        // Transactions are immutable ledger facts.
        // Concurrent inserts are ALWAYS additive — they NEVER conflict.
        return _createTransaction(op);
      case 'UPDATE':
        return _updateTransaction(op, ctx);
      case 'DELETE':
        return _deleteTransaction(op);
      case 'RESTORE':
        return _restoreTransaction(op);
      case 'ACTIVATE_ARCHIVED':
        return _activateArchivedTransaction(op);
      default:
        return _surfaceAmbiguousConflict(op, 'Unknown action: ${op.action}');
    }
  }

  /// Creates a transaction — always additive, never conflicts.
  Future<_OpResult> _createTransaction(SyncOperationModel op) async {
    final existing =
        await (_db.select(_db.transactions)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();

    if (existing != null) {
      final deltas = _parseFieldDeltas(op.fieldDeltas);
      if (deltas != null && !_transactionPayloadMatches(existing, deltas)) {
        // Same ID, divergent financial payload — never silently discard.
        return _surfaceAmbiguousConflict(
          op,
          'Duplicate transaction CREATE with divergent payload',
        );
      }
      // Exact idempotent retry — skip without re-insert.
      return _OpResult.empty();
    }

    final deltas = _parseFieldDeltas(op.fieldDeltas);
    if (deltas == null) {
      return _surfaceAmbiguousConflict(op, 'CREATE op missing field deltas');
    }

    // A transaction is money. Refuse to invent one from defaults: an
    // orphaned row or a silent zero amount is worse than a visible conflict.
    final contactId = _asString(deltas['contactId']);
    if (contactId == null || contactId.isEmpty) {
      return _surfaceAmbiguousConflict(
        op,
        'CREATE transaction missing contactId — refusing orphan row',
      );
    }

    final amount = _asInt(deltas['amount']);
    if (amount == null || amount < 0) {
      return _surfaceAmbiguousConflict(
        op,
        'CREATE transaction has missing or negative amount',
      );
    }

    final type = _parseTransactionType(_asString(deltas['type']));
    if (type == null) {
      return _surfaceAmbiguousConflict(
        op,
        'CREATE transaction has unknown type',
      );
    }

    final currency = _asString(deltas['currency']);
    if (currency == null || currency.isEmpty) {
      return _surfaceAmbiguousConflict(
        op,
        'CREATE transaction missing currency',
      );
    }

    await _db.into(_db.transactions).insert(
      db.TransactionsCompanion.insert(
        id: op.entityId,
        contactId: contactId,
        type: type,
        amount: amount,
        currency: currency,
        transactionDate:
            _asDateTime(deltas['transactionDate']) ?? op.localTimestamp,
        createdAt: Value(op.localTimestamp),
        updatedAt: Value(op.serverUpdatedAt),
        syncVersion: Value(op.opSeq),
        description: Value(_asString(deltas['description'])),
        itemName: Value(_asString(deltas['itemName'])),
        attachmentPath: Value(_asString(deltas['attachmentPath'])),
      ),
    );

    return _OpResult(affectedContactIds: {contactId});
  }

  Future<_OpResult> _updateTransaction(
    SyncOperationModel op,
    _MergeContext ctx,
  ) async {
    final existing =
        await (_db.select(_db.transactions)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();

    if (existing == null) {
      return _surfaceAmbiguousConflict(
        op,
        'UPDATE for missing transaction — pull gap; refusing invent-from-defaults CREATE',
      );
    }

    final auditNotes = <String>[];
    var wasUndeleted = false;
    if (existing.isDeleted) {
      wasUndeleted = true;
      auditNotes.add(
        'Transaction ${op.entityId} un-deleted: remote edit survived '
        'delete-vs-edit race (device: ${op.deviceId})',
      );
    }

    final deltas = _parseFieldDeltas(op.fieldDeltas);
    if (deltas == null) {
      return _surfaceAmbiguousConflict(op, 'UPDATE op missing/malformed field deltas');
    }

    // A negative amount would flip the sign of a balance — reject the whole
    // op rather than merge a poisoned field.
    final proposedAmount = _asInt(deltas['amount']);
    if (deltas.containsKey('amount') &&
        (proposedAmount == null || proposedAmount < 0)) {
      return _surfaceAmbiguousConflict(
        op,
        'UPDATE transaction has missing or negative amount',
      );
    }

    final authority = await _localAuthority(
      op.entityId,
      existing.updatedAt,
      ctx,
    );

    // type/currency/transactionDate are merged too: dropping them would let
    // one device show a payment where another shows a debt of the same size.
    final companion = db.TransactionsCompanion(
      amount:
          _lwwField(deltas, 'amount', op, existing.updatedAt, authority, _asInt),
      currency: _lwwField(deltas, 'currency', op, existing.updatedAt, authority,
          _asString),
      type: _lwwField(deltas, 'type', op, existing.updatedAt, authority,
          _parseTransactionTypeValue),
      transactionDate: _lwwField(deltas, 'transactionDate', op,
          existing.updatedAt, authority, _asDateTime),
      description: _lwwNullableField(deltas, 'description', op,
          existing.updatedAt, authority, _asString),
      itemName: _lwwNullableField(deltas, 'itemName', op, existing.updatedAt,
          authority, _asString),
      attachmentPath: _lwwNullableField(deltas, 'attachmentPath', op,
          existing.updatedAt, authority, _asString),
      isDeleted: wasUndeleted ? const Value(false) : const Value<bool>.absent(),
      updatedAt: Value(_serverOrderedUpdatedAt(existing.updatedAt, op)),
      syncVersion: Value(op.opSeq),
    );

    await (_db.update(_db.transactions)
          ..where((t) => t.id.equals(op.entityId)))
        .write(companion);

    return _OpResult(
      affectedContactIds: {existing.contactId},
      auditNotes: auditNotes,
    );
  }

  Future<_OpResult> _deleteTransaction(SyncOperationModel op) async {
    final existing =
        await (_db.select(_db.transactions)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();

    if (existing == null) {
      return _OpResult.empty();
    }

    if (!existing.isDeleted && existing.updatedAt.isAfter(op.serverUpdatedAt)) {
      return _surfaceDeleteVsEdit(
        op,
        localSnapshot: jsonEncode({
          'amount': existing.amount,
          'type': existing.type.name,
          'contactId': existing.contactId,
        }),
        auditNote:
            'Transaction ${op.entityId} delete-vs-edit conflict: local edit survived (device: ${op.deviceId})',
      );
    }

    if (existing.isDeleted) {
      return _OpResult.empty();
    }

    await (_db.update(_db.transactions)
          ..where((t) => t.id.equals(op.entityId)))
        .write(
      db.TransactionsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(op.serverUpdatedAt),
        syncVersion: Value(op.opSeq),
      ),
    );

    return _OpResult(affectedContactIds: {existing.contactId});
  }

  Future<_OpResult> _restoreTransaction(SyncOperationModel op) async {
    final existing =
        await (_db.select(_db.transactions)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();

    if (existing == null) {
      return _surfaceAmbiguousConflict(
        op,
        'RESTORE for missing transaction — pull gap',
      );
    }
    if (!existing.isDeleted) {
      return _OpResult.empty();
    }

    await (_db.update(_db.transactions)
          ..where((t) => t.id.equals(op.entityId)))
        .write(
      db.TransactionsCompanion(
        isDeleted: const Value(false),
        updatedAt: Value(op.serverUpdatedAt),
        syncVersion: Value(op.opSeq),
      ),
    );

    return _OpResult(affectedContactIds: {existing.contactId});
  }

  Future<_OpResult> _activateArchivedTransaction(SyncOperationModel op) async {
    final existing =
        await (_db.select(_db.transactions)
              ..where((t) => t.id.equals(op.entityId)))
            .getSingleOrNull();
    if (existing == null) {
      return _surfaceAmbiguousConflict(
        op,
        'ACTIVATE_ARCHIVED for missing transaction — pull gap',
      );
    }

    await (_db.update(_db.transactions)
          ..where((t) => t.id.equals(op.entityId)))
        .write(
      db.TransactionsCompanion(
        isArchived: const Value(false),
        updatedAt: Value(_serverOrderedUpdatedAt(existing.updatedAt, op)),
        syncVersion: Value(op.opSeq),
      ),
    );

    return _OpResult(affectedContactIds: {existing.contactId});
  }

  // ══════════════════════════════════════════════════════════════════════
  // CASCADES — MIRROR LOCAL DELETE SEMANTICS
  // ══════════════════════════════════════════════════════════════════════

  /// Soft-deletes every live transaction of [contactId] and drops its
  /// balance rows, stamping [deletedAt] so a later RESTORE can find them.
  Future<void> _cascadeDeleteContactTransactions(
    String contactId,
    DateTime deletedAt,
  ) async {
    await (_db.update(_db.transactions)
          ..where(
            (t) => t.contactId.equals(contactId) & t.isDeleted.equals(false),
          ))
        .write(
      db.TransactionsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(deletedAt),
      ),
    );

    await (_db.delete(_db.contactBalances)
          ..where((t) => t.contactId.equals(contactId)))
        .go();
  }

  /// Soft-deletes every live contact of [ledgerId] and their transactions.
  ///
  /// Returns the affected contact ids.
  Future<Set<String>> _cascadeDeleteLedgerChildren(
    String ledgerId,
    DateTime deletedAt,
  ) async {
    final contactIds = (await (_db.select(_db.contacts)
              ..where(
                (t) => t.ledgerId.equals(ledgerId) & t.isDeleted.equals(false),
              ))
            .get())
        .map((row) => row.id)
        .toList(growable: false);

    if (contactIds.isEmpty) {
      return const {};
    }

    await (_db.update(_db.contacts)
          ..where(
            (t) => t.ledgerId.equals(ledgerId) & t.isDeleted.equals(false),
          ))
        .write(
      db.ContactsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(deletedAt),
      ),
    );

    await (_db.update(_db.transactions)
          ..where(
            (t) => t.contactId.isIn(contactIds) & t.isDeleted.equals(false),
          ))
        .write(
      db.TransactionsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(deletedAt),
      ),
    );

    await (_db.delete(_db.contactBalances)
          ..where((t) => t.contactId.isIn(contactIds)))
        .go();

    return contactIds.toSet();
  }

  // ══════════════════════════════════════════════════════════════════════
  // BALANCE RECALCULATION — FINANCIAL-GRADE INTEGRITY
  // ══════════════════════════════════════════════════════════════════════

  /// Recalculates a contact's balance from the surviving transaction set.
  ///
  /// Money is NEVER merged arithmetically across devices — only the
  /// transaction *set* is merged; the balance is derived from scratch.
  /// Every currency row is rebuilt, so a currency whose last transaction was
  /// deleted leaves no stale balance behind.
  Future<void> _recalculateBalance(String contactId) async {
    if (contactId.isEmpty) {
      return;
    }

    // Aggregate surviving (non-deleted, non-archived) transactions by currency.
    final rows = await (_db.select(_db.transactions)
          ..where(
            (t) =>
                t.contactId.equals(contactId) &
                t.isDeleted.equals(false) &
                t.isArchived.equals(false),
          ))
        .get();

    // Group by currency and sum.
    final balances = <String, _BalanceAccumulator>{};
    for (final txn in rows) {
      final acc = balances.putIfAbsent(
        txn.currency,
        _BalanceAccumulator.new,
      );
      if (txn.type == TransactionType.debt) {
        acc.totalDebt += txn.amount;
      } else {
        acc.totalPayment += txn.amount;
      }
    }

    // Delete existing balance rows for this contact.
    await (_db.delete(_db.contactBalances)
          ..where((t) => t.contactId.equals(contactId)))
        .go();

    // Insert recalculated balances.
    final now = DateTime.now().toUtc();
    for (final entry in balances.entries) {
      final acc = entry.value;
      await _db.into(_db.contactBalances).insert(
        db.ContactBalancesCompanion.insert(
          contactId: contactId,
          currencyCode: entry.key,
          totalDebt: Value(acc.totalDebt),
          totalPayment: Value(acc.totalPayment),
          netBalance: Value(acc.totalPayment - acc.totalDebt),
          lastUpdatedAt: Value(now),
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // FIELD-LEVEL LWW WITH DETERMINISTIC TIEBREAKER
  // ══════════════════════════════════════════════════════════════════════

  /// Identifies the author of the local row's current logical clock.
  ///
  /// The tiebreaker must compare the incoming op against *whoever wrote the
  /// value it is competing with*, not against the device doing the merging —
  /// otherwise two devices replaying the same op log reach different states.
  /// The authoring op is the recorded op whose `serverUpdatedAt` equals the
  /// row's `updatedAt`; when there is none the value is an unpushed local
  /// edit and this device is the author.
  Future<_LwwAuthority> _localAuthority(
    String entityId,
    DateTime localUpdatedAt,
    _MergeContext ctx,
  ) async {
    final row = await (_db.select(_db.syncOperations)
          ..where(
            (t) =>
                t.entityId.equals(entityId) &
                t.serverUpdatedAt.equals(localUpdatedAt),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.opSeq, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();

    if (row == null) {
      return _LwwAuthority(role: ctx.localRole, deviceId: localDeviceId);
    }
    return _LwwAuthority(role: row.role, deviceId: row.deviceId);
  }

  /// Applies field-level Last-Write-Wins for a non-nullable column.
  ///
  /// Returns a [Value] with the new field value if the remote op wins,
  /// or [Value.absent()] if the local value should be kept. A remote value
  /// that fails [parse] is treated as absent rather than crashing the batch.
  ///
  /// Deterministic tiebreaker for identical timestamps:
  /// 1. Owner > Editor (role priority)
  /// 2. Lowest deviceId (lexicographic)
  Value<T> _lwwField<T extends Object>(
    Map<String, dynamic> deltas,
    String fieldName,
    SyncOperationModel remoteOp,
    DateTime localUpdatedAt,
    _LwwAuthority localAuthority,
    T? Function(Object? raw) parse,
  ) {
    if (!deltas.containsKey(fieldName)) {
      return const Value.absent();
    }
    final remoteValue = parse(deltas[fieldName]);
    if (remoteValue == null) {
      return const Value.absent();
    }
    if (!_remoteWins(remoteOp, localUpdatedAt, localAuthority)) {
      return const Value.absent();
    }
    return Value(remoteValue);
  }

  /// [_lwwField] for nullable columns, where an explicit JSON `null` is a
  /// meaningful "clear this field" instruction.
  Value<T?> _lwwNullableField<T extends Object>(
    Map<String, dynamic> deltas,
    String fieldName,
    SyncOperationModel remoteOp,
    DateTime localUpdatedAt,
    _LwwAuthority localAuthority,
    T? Function(Object? raw) parse,
  ) {
    if (!deltas.containsKey(fieldName)) {
      return const Value.absent();
    }
    final raw = deltas[fieldName];
    final remoteValue = parse(raw);
    if (remoteValue == null && raw != null) {
      // Present but wrong type — keep the local value.
      return const Value.absent();
    }
    if (!_remoteWins(remoteOp, localUpdatedAt, localAuthority)) {
      return const Value.absent();
    }
    return Value(remoteValue);
  }

  bool _remoteWins(
    SyncOperationModel remoteOp,
    DateTime localUpdatedAt,
    _LwwAuthority localAuthority,
  ) {
    // Remote is strictly newer — remote wins.
    if (remoteOp.serverUpdatedAt.isAfter(localUpdatedAt)) {
      return true;
    }
    // Local is strictly newer — local wins.
    if (localUpdatedAt.isAfter(remoteOp.serverUpdatedAt)) {
      return false;
    }

    // Identical timestamps — deterministic tiebreaker.
    // 1. Higher role priority wins (Owner > Editor > Viewer).
    final remoteRolePriority = _rolePriority[remoteOp.role] ?? 0;
    final localRolePriority = _rolePriority[localAuthority.role] ?? 0;

    if (remoteRolePriority != localRolePriority) {
      return remoteRolePriority > localRolePriority;
    }

    // 2. Same role — lowest deviceId wins (lexicographic).
    return remoteOp.deviceId.compareTo(localAuthority.deviceId) < 0;
  }

  // ══════════════════════════════════════════════════════════════════════
  // CONFLICT SURFACING
  // ══════════════════════════════════════════════════════════════════════

  Future<_OpResult> _surfaceAmbiguousConflict(
    SyncOperationModel op,
    String reason,
  ) async {
    final conflict = MergeConflictModel(
      id: UuidUtil.generate(),
      entityType: op.entityType,
      entityId: op.entityId,
      conflictType: ConflictType.ambiguous,
      localSnapshot: '{}',
      remoteSnapshot: op.fieldDeltas ?? '{}',
      detectedAt: DateTime.now().toUtc(),
    );

    await _db.into(_db.mergeConflicts).insert(conflict.toDrift());

    return _OpResult(
      conflicts: [conflict],
      auditNotes: ['Ambiguous conflict surfaced: $reason'],
    );
  }

  Future<_OpResult> _surfaceDeleteVsEdit(
    SyncOperationModel op, {
    required String localSnapshot,
    required String auditNote,
    Set<String> affectedContactIds = const {},
  }) async {
    final conflict = MergeConflictModel(
      id: UuidUtil.generate(),
      entityType: op.entityType,
      entityId: op.entityId,
      conflictType: ConflictType.deleteVsEdit,
      localSnapshot: localSnapshot,
      remoteSnapshot: op.fieldDeltas ?? '{}',
      detectedAt: DateTime.now().toUtc(),
    );

    await _db.into(_db.mergeConflicts).insert(conflict.toDrift());

    return _OpResult(
      conflicts: [conflict],
      auditNotes: [auditNote],
      affectedContactIds: affectedContactIds,
    );
  }

  Future<_OpResult> _surfaceConcurrentCreate(
    SyncOperationModel op,
    String entityType,
    String localSnapshot,
  ) async {
    final conflict = MergeConflictModel(
      id: UuidUtil.generate(),
      entityType: entityType,
      entityId: op.entityId,
      conflictType: ConflictType.concurrentCreate,
      localSnapshot: localSnapshot,
      remoteSnapshot: op.fieldDeltas ?? '{}',
      detectedAt: DateTime.now().toUtc(),
    );

    await _db.into(_db.mergeConflicts).insert(conflict.toDrift());

    return _OpResult(
      conflicts: [conflict],
      auditNotes: [
        'Concurrent create conflict for $entityType ${op.entityId}',
      ],
    );
  }

  /// True when remote CREATE deltas match the existing transaction financially.
  bool _transactionPayloadMatches(
    db.Transaction existing,
    Map<String, dynamic> deltas,
  ) {
    final contactId = _asString(deltas['contactId']);
    final amount = _asInt(deltas['amount']);
    final currency = _asString(deltas['currency']);
    final type = _parseTransactionType(_asString(deltas['type']));

    if (contactId != null && contactId != existing.contactId) return false;
    if (amount != null && amount != existing.amount) return false;
    if (currency != null && currency != existing.currency) return false;
    if (type != null && type != existing.type) return false;
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════

  /// Advances the entity logical clock using server ordering authority.
  ///
  /// Never regresses below [existing]; never uses wall-clock time.
  DateTime _serverOrderedUpdatedAt(DateTime existing, SyncOperationModel op) {
    return op.serverUpdatedAt.isAfter(existing) ? op.serverUpdatedAt : existing;
  }

  /// Parses the JSON field deltas from an op payload.
  Map<String, dynamic>? _parseFieldDeltas(String? fieldDeltas) {
    if (fieldDeltas == null || fieldDeltas.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(fieldDeltas);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  Value<T> _snapshotValue<T extends Object>(
    Map<String, dynamic> snapshot,
    String key,
    T? Function(Object? raw) parse,
  ) {
    final value = parse(snapshot[key]);
    return value == null ? const Value.absent() : Value(value);
  }

  Value<T?> _snapshotNullable<T extends Object>(
    Map<String, dynamic> snapshot,
    String key,
    T? Function(Object? raw) parse,
  ) {
    if (!snapshot.containsKey(key)) {
      return const Value.absent();
    }
    return Value(parse(snapshot[key]));
  }

  /// Parses a [LedgerType] from the string stored in field deltas.
  static LedgerType _parseLedgerType(String? value) {
    if (value == null) return LedgerType.customers;
    return LedgerType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LedgerType.customers,
    );
  }

  /// Strict transaction type parse — unknown values are rejected, never
  /// silently coerced to `debt`.
  static TransactionType? _parseTransactionType(String? value) {
    return switch (value) {
      'debt' => TransactionType.debt,
      'payment' => TransactionType.payment,
      _ => null,
    };
  }

  static TransactionType? _parseTransactionTypeValue(Object? raw) {
    return _parseTransactionType(_asString(raw));
  }

  // Remote payloads are untrusted JSON. Every accessor below returns null on
  // a type mismatch so a hostile op degrades into a surfaced conflict rather
  // than an exception that rolls back the whole merge transaction.

  static String? _asString(Object? raw) => raw is String ? raw : null;

  static int? _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is double) return raw == raw.roundToDouble() ? raw.toInt() : null;
    return null;
  }

  static bool? _asBool(Object? raw) => raw is bool ? raw : null;

  static DateTime? _asDateTime(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// INTERNAL RESULT TYPES
// ════════════════════════════════════════════════════════════════════════════

/// Per-run merge state. Kept off the instance so concurrent
/// [MergeEngineLocalDs.applyRemoteOps] calls cannot overwrite each other.
class _MergeContext {
  const _MergeContext({required this.localRole});

  final String localRole;
}

/// Identity credited with the local row's current value, for LWW tiebreaks.
class _LwwAuthority {
  const _LwwAuthority({required this.role, required this.deviceId});

  final String role;
  final String deviceId;
}

/// Internal result of applying a single op.
class _OpResult {
  _OpResult({
    this.conflicts = const [],
    this.affectedContactIds = const {},
    this.auditNotes = const [],
  });

  factory _OpResult.empty() => _OpResult();

  final List<MergeConflictModel> conflicts;
  final Set<String> affectedContactIds;
  final List<String> auditNotes;
}

/// Accumulator for balance recalculation.
class _BalanceAccumulator {
  int totalDebt = 0;
  int totalPayment = 0;
}

/// Public result type returned by [MergeEngineLocalDs.applyRemoteOps].
class MergeEngineResult {
  const MergeEngineResult({
    required this.applied,
    required this.skipped,
    required this.conflicts,
    required this.recalculatedContactIds,
    required this.auditNotes,
  });

  final int applied;
  final int skipped;
  final List<MergeConflictModel> conflicts;
  final List<String> recalculatedContactIds;
  final List<String> auditNotes;
}
