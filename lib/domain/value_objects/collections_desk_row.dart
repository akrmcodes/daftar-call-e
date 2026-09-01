import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:equatable/equatable.dart';

/// One ranked Collections Desk draft, owned on-device.
class CollectionsDeskRow extends Equatable {
  /// Creates a desk row.
  const CollectionsDeskRow({
    required this.candidate,
    required this.body,
    required this.toneBand,
    required this.attachPdf,
    this.subject = '',
    this.customerName = '',
    this.storeName = '',
    this.amountLine = '',
    this.ctaLine = '',
    this.note = '',
    this.status = CollectionsDeskRowStatus.pending,
    this.smtpMessageId,
    this.smtpCode,
  });

  /// Drift-backed candidate (integer [CollectionsCandidate.owedMinor]).
  final CollectionsCandidate candidate;

  /// Appendix C.2 subject (AR/EN). Never Cloud Run text.
  final String subject;

  /// Appendix C.2 body (AR/EN). Never Cloud Run text.
  final String body;

  /// Named C.2 `customer_name`.
  final String customerName;

  /// Named C.2 `store_name`.
  final String storeName;

  /// Named C.2 `amount_line` (device-formatted integer money).
  final String amountLine;

  /// Named C.2 `cta_line`.
  final String ctaLine;

  /// Named C.2 `note` (empty for Friendly).
  final String note;

  /// Displayed tone; may differ from [CollectionsCandidate.toneBand] after override.
  final ReminderToneBand toneBand;

  /// When true, SMTP attaches a statement PDF (Approve default). Leftover Open uses share sheet.
  final bool attachPdf;

  /// Pending / skipped / opened / sending / sent / failed.
  final CollectionsDeskRowStatus status;

  /// Gmail Message-ID when [status] is sent.
  final String? smtpMessageId;

  /// SMTP reply code.
  final int? smtpCode;

  /// Device `sent` only if SMTP 250 plus a non-empty Message-ID.
  bool get isAcceptedSend {
    final id = smtpMessageId?.trim() ?? '';
    return status == CollectionsDeskRowStatus.sent &&
        smtpCode == 250 &&
        id.isNotEmpty;
  }

  /// Copies this row with selected fields replaced.
  CollectionsDeskRow copyWith({
    CollectionsCandidate? candidate,
    String? subject,
    String? body,
    String? customerName,
    String? storeName,
    String? amountLine,
    String? ctaLine,
    String? note,
    ReminderToneBand? toneBand,
    bool? attachPdf,
    CollectionsDeskRowStatus? status,
    String? smtpMessageId,
    int? smtpCode,
    bool clearSmtp = false,
  }) {
    return CollectionsDeskRow(
      candidate: candidate ?? this.candidate,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      customerName: customerName ?? this.customerName,
      storeName: storeName ?? this.storeName,
      amountLine: amountLine ?? this.amountLine,
      ctaLine: ctaLine ?? this.ctaLine,
      note: note ?? this.note,
      toneBand: toneBand ?? this.toneBand,
      attachPdf: attachPdf ?? this.attachPdf,
      status: status ?? this.status,
      smtpMessageId:
          clearSmtp ? null : (smtpMessageId ?? this.smtpMessageId),
      smtpCode: clearSmtp ? null : (smtpCode ?? this.smtpCode),
    );
  }

  @override
  List<Object?> get props => [
        candidate,
        subject,
        body,
        customerName,
        storeName,
        amountLine,
        ctaLine,
        note,
        toneBand,
        attachPdf,
        status,
        smtpMessageId,
        smtpCode,
      ];
}
