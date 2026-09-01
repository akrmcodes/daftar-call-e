import 'package:daftar/domain/entities/ledger.dart';
import 'package:equatable/equatable.dart';

class CarryForwardResult extends Equatable {
  const CarryForwardResult({
    required this.archivedLedger,
    required this.contactsCreated,
    required this.transactionsCreated,
    required this.targetLedgerId,
  });

  final Ledger archivedLedger;
  final int contactsCreated;
  final int transactionsCreated;
  final String targetLedgerId;

  @override
  List<Object?> get props => [
    archivedLedger,
    contactsCreated,
    transactionsCreated,
    targetLedgerId,
  ];
}
