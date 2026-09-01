import 'package:daftar/domain/entities/audit_log.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/transaction.dart';

class CsvBulkPersistBatch {
  const CsvBulkPersistBatch({
    this.contacts = const [],
    this.transactions = const [],
    this.auditLogs = const [],
  });

  final List<Contact> contacts;
  final List<Transaction> transactions;
  final List<AuditLog> auditLogs;

  bool get isEmpty =>
      contacts.isEmpty && transactions.isEmpty && auditLogs.isEmpty;
}
