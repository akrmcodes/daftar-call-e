import 'dart:convert';

import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';

import 'ledger_archiving_test_harness.dart';

class CarryForwardOpLogReplayResult {
  const CarryForwardOpLogReplayResult({
    required this.appliedCount,
    required this.skippedCount,
    required this.affectedContactIds,
  });

  final int appliedCount;
  final int skippedCount;
  final Set<String> affectedContactIds;
}

Future<CarryForwardOpLogReplayResult> replayCarryForwardAuditLogs({
  required LedgerArchivingTestHarness harness,
  required List<AuditLog> auditLogs,
  required String operationId,
}) async {
  final replayable = auditLogs.where((log) {
    if (log.payload == null || log.payload!.isEmpty) {
      return false;
    }
    if (log.action == 'CREATE' &&
        (log.entityType == 'contact' || log.entityType == 'transaction')) {
      final decoded = jsonDecode(log.payload!) as Map<String, dynamic>;
      return decoded['carryForwardOperationId'] == operationId;
    }
    if (log.action == 'UPDATE' && log.entityType == 'ledger') {
      final decoded = jsonDecode(log.payload!) as Map<String, dynamic>;
      return decoded['isUserArchived'] == true &&
          decoded.containsKey('carryForwardTargetLedgerId');
    }
    return false;
  }).toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final appliedKeys = <String>{};
  var appliedCount = 0;
  var skippedCount = 0;
  final affectedContactIds = <String>{};
  final now = DateTime.now().toUtc();

  for (final log in replayable) {
    final payload = jsonDecode(log.payload!) as Map<String, dynamic>;
    final operationKey = payload['carryForwardOperationId'] as String? ?? operationId;
    final dedupeKey = '${log.entityType}:${log.entityId}:$operationKey';
    if (appliedKeys.contains(dedupeKey)) {
      skippedCount++;
      continue;
    }

    if (log.entityType == 'contact' && log.action == 'CREATE') {
      final contactId = payload['id'] as String;
      final existingContact = await (harness.database.select(
        harness.database.contacts,
      )..where((table) => table.id.equals(contactId))).getSingleOrNull();
      if (existingContact != null) {
        appliedKeys.add(dedupeKey);
        skippedCount++;
        continue;
      }

      final contact = ContactModel(
        id: contactId,
        ledgerId: payload['ledgerId'] as String,
        name: payload['name'] as String,
        phone: payload['phone'] as String?,
        notes: payload['notes'] as String?,
        creditLimit: payload['creditLimit'] as int?,
        creditCurrency: payload['creditCurrency'] as String?,
        avatarColor: payload['avatarColor'] as String? ?? '#FF9800',
        createdAt: now,
        updatedAt: now,
      );
      await harness.database
          .into(harness.database.contacts)
          .insert(contact.toDrift());
      appliedKeys.add(dedupeKey);
      appliedCount++;
      continue;
    }

    if (log.entityType == 'transaction' && log.action == 'CREATE') {
      final transactionId = payload['id'] as String;
      final existingTransaction = await (harness.database.select(
        harness.database.transactions,
      )..where((table) => table.id.equals(transactionId))).getSingleOrNull();
      if (existingTransaction != null) {
        appliedKeys.add(dedupeKey);
        skippedCount++;
        continue;
      }

      final transaction = TransactionModel(
        id: transactionId,
        contactId: payload['contactId'] as String,
        type: TransactionType.values.byName(payload['type'] as String),
        amount: payload['amount'] as int,
        currency: payload['currency'] as String,
        description: payload['description'] as String?,
        itemName: payload['itemName'] as String?,
        attachmentPath: payload['attachmentPath'] as String?,
        transactionDate: DateTime.parse(payload['transactionDate'] as String),
        createdAt: now,
        updatedAt: now,
      );
      await harness.database
          .into(harness.database.transactions)
          .insert(transaction.toDrift());
      affectedContactIds.add(transaction.contactId);
      appliedKeys.add(dedupeKey);
      appliedCount++;
      continue;
    }

    if (log.entityType == 'ledger' && log.action == 'UPDATE') {
      final ledger = await expectRight(harness.ledgerRepository.getById(log.entityId));
      final targetId = payload['carryForwardTargetLedgerId'] as String?;
      if (ledger.isUserArchived && ledger.carryForwardTargetLedgerId == targetId) {
        appliedKeys.add(dedupeKey);
        skippedCount++;
        continue;
      }

      await harness.setLedgerFlags(
        log.entityId,
        isUserArchived: payload['isUserArchived'] as bool? ?? true,
        carryForwardTargetLedgerId:
            payload['carryForwardTargetLedgerId'] as String?,
      );
      appliedKeys.add(dedupeKey);
      appliedCount++;
    }
  }

  for (final contactId in affectedContactIds) {
    await expectRight(harness.balanceRepository.recalculate(contactId));
  }

  return CarryForwardOpLogReplayResult(
    appliedCount: appliedCount,
    skippedCount: skippedCount,
    affectedContactIds: affectedContactIds,
  );
}

Future<void> seedLedgerWithId(
  LedgerArchivingTestHarness harness, {
  required String id,
  required String name,
}) async {
  final now = DateTime.now().toUtc();
  await harness.database.into(harness.database.ledgers).insert(
    Ledger(
      id: id,
      name: name,
      type: LedgerType.custom,
      icon: 'folder',
      color: '#424242',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      isArchived: false,
      isUserArchived: false,
      syncVersion: 0,
    ),
  );
}
