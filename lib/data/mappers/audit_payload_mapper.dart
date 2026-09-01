import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/ledger_model.dart';
import 'package:daftar/data/models/transaction_model.dart';

Map<String, Object?> contactCreateAuditPayload(
  ContactModel model, {
  String? carryForwardOperationId,
}) {
  final payload = <String, Object?>{
    'id': model.id,
    'ledgerId': model.ledgerId,
    'name': model.name,
    'phone': model.phone,
    'email': model.email,
    'notes': model.notes,
    'creditLimit': model.creditLimit,
    'creditCurrency': model.creditCurrency,
    'avatarColor': model.avatarColor,
  };
  if (carryForwardOperationId != null) {
    payload['carryForwardOperationId'] = carryForwardOperationId;
  }
  return payload;
}

Map<String, Object?> transactionCreateAuditPayload(
  TransactionModel model, {
  String? carryForwardOperationId,
}) {
  final payload = <String, Object?>{
    'id': model.id,
    'contactId': model.contactId,
    'type': model.type.name,
    'amount': model.amount,
    'currency': model.currency,
    'description': model.description,
    'itemName': model.itemName,
    'attachmentPath': model.attachmentPath,
    'transactionDate': model.transactionDate.toIso8601String(),
  };
  if (carryForwardOperationId != null) {
    payload['carryForwardOperationId'] = carryForwardOperationId;
  }
  return payload;
}

Map<String, Object?> ledgerCarryForwardUpdateAuditPayload(LedgerModel model) {
  return {
    'isUserArchived': model.isUserArchived,
    'carryForwardTargetLedgerId': model.carryForwardTargetLedgerId,
  };
}

Map<String, Object?> ledgerCarryForwardCeremonyAuditPayload({
  required String operationId,
  required String sourceLedgerId,
  required String targetLedgerId,
  required String targetLedgerName,
  required int contactsCreated,
  required int transactionsCreated,
  required Map<String, int> totalsByCurrency,
}) {
  return {
    'operationId': operationId,
    'sourceLedgerId': sourceLedgerId,
    'targetLedgerId': targetLedgerId,
    'targetLedgerName': targetLedgerName,
    'contactsCreated': contactsCreated,
    'transactionsCreated': transactionsCreated,
    'totalsByCurrency': totalsByCurrency,
  };
}
