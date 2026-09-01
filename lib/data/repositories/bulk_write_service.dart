import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/contact_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/datasources/local/transaction_local_ds.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/data/repositories/balance_recalculation_service.dart';
import 'package:daftar/data/repositories/contact_search_index_utils.dart';

class BulkWritePayload {
  const BulkWritePayload({
    required this.contacts,
    required this.contactSearchIndex,
    required this.transactions,
    required this.auditLogs,
  });

  final List<ContactModel> contacts;
  final Map<String, String> contactSearchIndex;
  final List<TransactionModel> transactions;
  final List<AuditLogModel> auditLogs;
}

class BulkWriteService {
  BulkWriteService({
    required db.AppDatabase database,
    required ContactLocalDataSource contactLocalDataSource,
    required TransactionLocalDataSource transactionLocalDataSource,
    required AuditLogLocalDataSource auditLogLocalDataSource,
    required BalanceRecalculationService balanceRecalculationService,
  }) : _database = database,
       _contactLocalDataSource = contactLocalDataSource,
       _transactionLocalDataSource = transactionLocalDataSource,
       _auditLogLocalDataSource = auditLogLocalDataSource,
       _balanceRecalculationService = balanceRecalculationService;

  final db.AppDatabase _database;
  final ContactLocalDataSource _contactLocalDataSource;
  final TransactionLocalDataSource _transactionLocalDataSource;
  final AuditLogLocalDataSource _auditLogLocalDataSource;
  final BalanceRecalculationService _balanceRecalculationService;

  Future<void> execute(BulkWritePayload payload) async {
    if (payload.contacts.isEmpty &&
        payload.transactions.isEmpty &&
        payload.auditLogs.isEmpty) {
      return;
    }

    await _database.transaction(() async {
      await _contactLocalDataSource.bulkCreateContacts(payload.contacts);
      await bulkUpsertContactSearchIndex(
        _database,
        payload.contactSearchIndex,
      );
      await _transactionLocalDataSource.bulkCreateTransactions(
        payload.transactions,
      );

      final contactIds = <String>{};
      DateTime? lastUpdatedAt;
      for (final transaction in payload.transactions) {
        if (!transaction.isArchived) {
          contactIds.add(transaction.contactId);
        }
        lastUpdatedAt = transaction.updatedAt;
      }
      lastUpdatedAt ??= payload.contacts.isNotEmpty
          ? payload.contacts.first.updatedAt
          : DateTime.now().toUtc();

      for (final contactId in contactIds) {
        await _balanceRecalculationService.recalculateBalancesForContact(
          contactId: contactId,
          lastUpdatedAt: lastUpdatedAt,
        );
      }

      await _auditLogLocalDataSource.bulkAppendAuditLogs(payload.auditLogs);
    });
  }
}
