import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:equatable/equatable.dart';

/// Drift-backed inputs for a contact statement PDF (no PDF bytes).
class ContactStatementExport extends Equatable {
  /// Creates the export payload.
  const ContactStatementExport({
    required this.contact,
    required this.balance,
    required this.transactions,
  });

  /// Contact identity from Drift.
  final Contact contact;

  /// Display-currency balance (zero row when the contact has no txns).
  final ContactBalance balance;

  /// All non-deleted transactions (may be empty).
  final List<Transaction> transactions;

  @override
  List<Object?> get props => [contact, balance, transactions];
}
