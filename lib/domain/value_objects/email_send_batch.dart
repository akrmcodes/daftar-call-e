import 'package:equatable/equatable.dart';

/// One J.7 recipient. Extra fields (`body`, `amountMinor`) are forbidden.
class EmailSendBatchRecipient extends Equatable {
  /// Creates a recipient row.
  const EmailSendBatchRecipient({
    required this.contactId,
    required this.to,
    required this.subject,
    required this.customerName,
    required this.storeName,
    required this.amountLine,
    required this.ctaLine,
    this.note = '',
    this.filename,
  });

  final String contactId;
  final String to;
  final String subject;
  final String customerName;
  final String storeName;
  final String amountLine;
  final String ctaLine;
  final String note;
  final String? filename;

  Map<String, Object?> toJson() {
    return {
      'contactId': contactId,
      'to': to,
      'subject': subject,
      'customer_name': customerName,
      'store_name': storeName,
      'amount_line': amountLine,
      'cta_line': ctaLine,
      'note': note,
      if (filename != null && filename!.isNotEmpty) 'filename': filename,
    };
  }

  @override
  List<Object?> get props => [
        contactId,
        to,
        subject,
        customerName,
        storeName,
        amountLine,
        ctaLine,
        note,
        filename,
      ];
}

/// Multipart send-batch request (manifest + PDF bytes).
class EmailSendBatchRequest extends Equatable {
  /// Creates a send-batch request.
  const EmailSendBatchRequest({
    required this.batchId,
    required this.correlationId,
    required this.locale,
    required this.recipients,
    required this.pdfsByContactId,
  });

  final String batchId;
  final String correlationId;
  final String locale;
  final List<EmailSendBatchRecipient> recipients;
  final Map<String, List<int>> pdfsByContactId;

  Map<String, Object?> manifestJson() {
    return {
      'batchId': batchId,
      'correlationId': correlationId,
      'locale': locale,
      'recipients': [
        for (final recipient in recipients) recipient.toJson(),
      ],
    };
  }

  @override
  List<Object?> get props => [
        batchId,
        correlationId,
        locale,
        recipients,
        pdfsByContactId,
      ];
}

/// Per-row SMTP outcome from Cloud Run.
enum EmailSendRowRemoteStatus {
  sent,
  failed,
  skippedDuplicate,
}

/// One send-batch result row.
class EmailSendRowResult extends Equatable {
  /// Creates a result row.
  const EmailSendRowResult({
    required this.contactId,
    required this.toMasked,
    required this.status,
    this.smtpMessageId,
    this.smtpCode,
    this.smtpMessage,
  });

  factory EmailSendRowResult.fromJson(Map<String, Object?> json) {
    final statusRaw = json['status'] as String? ?? 'failed';
    final smtpCodeRaw = json['smtpCode'];
    return EmailSendRowResult(
      contactId: json['contactId'] as String? ?? '',
      toMasked: json['toMasked'] as String? ?? '',
      status: switch (statusRaw) {
        'sent' => EmailSendRowRemoteStatus.sent,
        'skippedDuplicate' => EmailSendRowRemoteStatus.skippedDuplicate,
        _ => EmailSendRowRemoteStatus.failed,
      },
      smtpMessageId: json['smtpMessageId'] as String?,
      smtpCode: smtpCodeRaw is int ? smtpCodeRaw : null,
      smtpMessage: json['smtpMessage'] as String?,
    );
  }

  final String contactId;
  final String toMasked;
  final EmailSendRowRemoteStatus status;
  final String? smtpMessageId;
  final int? smtpCode;
  final String? smtpMessage;

  /// Device `sent` only if SMTP 250 plus a non-empty Message-ID.
  bool get isAcceptedSend {
    final id = smtpMessageId?.trim() ?? '';
    return status == EmailSendRowRemoteStatus.sent &&
        smtpCode == 250 &&
        id.isNotEmpty;
  }

  @override
  List<Object?> get props => [
        contactId,
        toMasked,
        status,
        smtpMessageId,
        smtpCode,
        smtpMessage,
      ];
}

/// J.7 send-batch response.
class EmailSendBatchResponse extends Equatable {
  /// Creates a response.
  const EmailSendBatchResponse({
    required this.batchId,
    required this.results,
    required this.needsHuman,
  });

  factory EmailSendBatchResponse.fromJson(Map<String, Object?> json) {
    final rawResults = json['results'];
    final results = <EmailSendRowResult>[];
    if (rawResults is List<dynamic>) {
      for (final item in rawResults) {
        if (item is Map) {
          results.add(
            EmailSendRowResult.fromJson(
              Map<String, Object?>.from(item),
            ),
          );
        }
      }
    }
    return EmailSendBatchResponse(
      batchId: json['batchId'] as String? ?? '',
      results: results,
      needsHuman: json['needsHuman'] == true,
    );
  }

  final String batchId;
  final List<EmailSendRowResult> results;
  final bool needsHuman;

  @override
  List<Object?> get props => [batchId, results, needsHuman];
}
