import 'package:equatable/equatable.dart';

/// Device-owned Appendix C.3 CALL-E task and named params.
class CollectionsCallTask extends Equatable {
  /// Creates a filled C.3 task.
  const CollectionsCallTask({
    required this.task,
    required this.customerName,
    required this.storeName,
    required this.amountLine,
  });

  /// Full CALL-E `task` string (preview == wire).
  final String task;

  /// `customer_name`.
  final String customerName;

  /// `store_name`.
  final String storeName;

  /// Device-formatted integer `amount_line`.
  final String amountLine;

  @override
  List<Object?> get props => [task, customerName, storeName, amountLine];
}
