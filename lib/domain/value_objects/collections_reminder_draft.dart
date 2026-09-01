import 'package:equatable/equatable.dart';

/// Device-owned Appendix C.2 subject, body, and named params.
class CollectionsReminderDraft extends Equatable {
  /// Creates a filled C.2 draft.
  const CollectionsReminderDraft({
    required this.subject,
    required this.body,
    required this.customerName,
    required this.storeName,
    required this.amountLine,
    required this.ctaLine,
    required this.note,
  });

  /// C.2 subject line.
  final String subject;

  /// C.2 single-paragraph body.
  final String body;

  /// `customer_name`.
  final String customerName;

  /// `store_name`.
  final String storeName;

  /// Device-formatted integer `amount_line`.
  final String amountLine;

  /// Tone CTA.
  final String ctaLine;

  /// Age sentence or empty (Friendly).
  final String note;

  @override
  List<Object?> get props => [
        subject,
        body,
        customerName,
        storeName,
        amountLine,
        ctaLine,
        note,
      ];
}
