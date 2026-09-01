import 'package:equatable/equatable.dart';

class CarryForwardPreview extends Equatable {
  const CarryForwardPreview({
    required this.contactCount,
    required this.transactionCount,
    required this.totalsByCurrency,
    required this.sourceLedgerName,
    required this.targetLedgerName,
  });

  final int contactCount;
  final int transactionCount;
  final Map<String, int> totalsByCurrency;
  final String sourceLedgerName;
  final String targetLedgerName;

  @override
  List<Object?> get props => [
    contactCount,
    transactionCount,
    totalsByCurrency,
    sourceLedgerName,
    targetLedgerName,
  ];
}
