import 'dart:isolate';

import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/mappers/audit_payload_mapper.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/data/repositories/bulk_write_service.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/entities/audit_log.dart';
import 'package:daftar/domain/repositories/bulk_write_repository.dart';
import 'package:daftar/domain/value_objects/csv_bulk_persist_batch.dart';
import 'package:fpdart/fpdart.dart';

class BulkWriteRepositoryImpl implements BulkWriteRepository {
  BulkWriteRepositoryImpl({
    required BulkWriteService bulkWriteService,
  }) : _bulkWriteService = bulkWriteService;

  final BulkWriteService _bulkWriteService;

  @override
  Future<Either<Failure, Unit>> persist(CsvBulkPersistBatch batch) async {
    if (batch.isEmpty) {
      return const Right(unit);
    }

    try {
      final mapped = await Isolate.run(
        () => _mapBulkPersistBatchSync(batch, repositoryDeviceId),
      );

      await _bulkWriteService.execute(
        BulkWritePayload(
          contacts: mapped.contactModels,
          contactSearchIndex: mapped.contactSearchIndex,
          transactions: mapped.transactionModels,
          auditLogs: mapped.auditModels,
        ),
      );

      return const Right(unit);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }
}

final class _BulkWriteMappedBatch {
  const _BulkWriteMappedBatch({
    required this.contactModels,
    required this.contactSearchIndex,
    required this.transactionModels,
    required this.auditModels,
  });

  final List<ContactModel> contactModels;
  final Map<String, String> contactSearchIndex;
  final List<TransactionModel> transactionModels;
  final List<AuditLogModel> auditModels;
}

_BulkWriteMappedBatch _mapBulkPersistBatchSync(
  CsvBulkPersistBatch batch,
  String deviceId,
) {
  final contactModels = batch.contacts
      .map(ContactModel.fromDomain)
      .toList(growable: false);
  final transactionModels = batch.transactions
      .map(TransactionModel.fromDomain)
      .toList(growable: false);

  final contactSearchIndex = <String, String>{};
  for (final contact in contactModels) {
    if (!contact.isArchived) {
      contactSearchIndex[contact.id] = contact.name;
    }
  }

  final contactById = {
    for (final contact in contactModels) contact.id: contact,
  };
  final transactionById = {
    for (final transaction in transactionModels) transaction.id: transaction,
  };

  final auditModels = batch.auditLogs
      .map(
        (log) => _mapBulkAuditLog(
          log,
          deviceId: deviceId,
          contactById: contactById,
          transactionById: transactionById,
        ),
      )
      .toList(growable: false);

  return _BulkWriteMappedBatch(
    contactModels: contactModels,
    contactSearchIndex: contactSearchIndex,
    transactionModels: transactionModels,
    auditModels: auditModels,
  );
}

AuditLogModel _mapBulkAuditLog(
  AuditLog log, {
  required String deviceId,
  required Map<String, ContactModel> contactById,
  required Map<String, TransactionModel> transactionById,
}) {
  final payload = log.payload ?? _resolveBulkAuditPayload(
    log,
    contactById: contactById,
    transactionById: transactionById,
  );

  return AuditLogModel(
    id: log.id,
    entityType: log.entityType,
    entityId: log.entityId,
    action: log.action,
    payload: payload,
    timestamp: log.timestamp,
    deviceId: log.deviceId.isEmpty ? deviceId : log.deviceId,
  );
}

String? _resolveBulkAuditPayload(
  AuditLog log, {
  required Map<String, ContactModel> contactById,
  required Map<String, TransactionModel> transactionById,
}) {
  if (log.entityType == 'contact') {
    final contact = contactById[log.entityId];
    if (contact == null) {
      return null;
    }
    return encodePayload(contactCreateAuditPayload(contact));
  }

  if (log.entityType == 'transaction') {
    final transaction = transactionById[log.entityId];
    if (transaction == null) {
      return null;
    }
    return encodePayload(transactionCreateAuditPayload(transaction));
  }

  return null;
}
