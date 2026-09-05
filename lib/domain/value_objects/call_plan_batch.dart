import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:equatable/equatable.dart';

/// J.9 plan-batch reject reason (server `RejectReason`).
enum CallRejectReason {
  notAllowlisted,
  unsupportedRegion,
  killSwitch,
  dnc,
  invalidPhone,
  invalidHandle,
}

/// J.9 plan-batch row status.
enum CallPlanRowStatus {
  planned,
  dryRun,
  rejected,
  failed,
}

/// One J.9 `plan-batch` recipient. Extra money fields are forbidden.
class CallPlanRecipient extends Equatable {
  /// Creates a plan recipient.
  const CallPlanRecipient({
    required this.contactId,
    required this.phoneE164,
    required this.region,
    required this.locale,
    required this.task,
    required this.customerName,
    required this.storeName,
    required this.amountLine,
    this.doNotCall = false,
  });

  final String contactId;
  final String phoneE164;
  final String region;
  final String locale;
  final String task;
  final String customerName;
  final String storeName;
  final String amountLine;
  final bool doNotCall;

  Map<String, Object?> toJson() {
    return {
      'contactId': contactId,
      'phoneE164': phoneE164,
      'region': region,
      'locale': locale,
      'task': task,
      'customer_name': customerName,
      'store_name': storeName,
      'amount_line': amountLine,
      'doNotCall': doNotCall,
    };
  }

  @override
  List<Object?> get props => [
        contactId,
        phoneE164,
        region,
        locale,
        task,
        customerName,
        storeName,
        amountLine,
        doNotCall,
      ];
}

/// `POST /v1/calls/plan-batch` body.
class CallPlanBatchRequest extends Equatable {
  /// Creates a plan-batch request.
  const CallPlanBatchRequest({
    required this.batchId,
    required this.correlationId,
    required this.trigger,
    required this.dryRun,
    required this.locale,
    required this.recipients,
  });

  final String batchId;
  final String correlationId;
  final CallBatchTrigger trigger;
  final bool dryRun;

  /// `ar` or `en`.
  final String locale;
  final List<CallPlanRecipient> recipients;

  Map<String, Object?> toJson() {
    return {
      'batchId': batchId,
      'correlationId': correlationId,
      'trigger': trigger.name,
      'dryRun': dryRun,
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
        trigger,
        dryRun,
        locale,
        recipients,
      ];
}

/// One plan-batch result row.
class CallPlanRowResult extends Equatable {
  /// Creates a plan row result.
  const CallPlanRowResult({
    required this.contactId,
    required this.phoneMasked,
    required this.readyToRun,
    required this.status,
    this.reason,
    this.task,
    this.confirmHandle,
  });

  factory CallPlanRowResult.fromJson(Map<String, Object?> json) {
    return CallPlanRowResult(
      contactId: json['contactId'] as String? ?? '',
      phoneMasked: json['phoneMasked'] as String? ?? '',
      readyToRun: json['readyToRun'] == true,
      status: _planStatus(json['status'] as String?),
      reason: parseCallRejectReason(json['reason'] as String?),
      task: json['task'] as String?,
      confirmHandle: json['confirmHandle'] as String?,
    );
  }

  final String contactId;
  final String phoneMasked;
  final bool readyToRun;
  final CallPlanRowStatus status;
  final CallRejectReason? reason;
  final String? task;

  /// Memory-only confirm token. Never log.
  final String? confirmHandle;

  @override
  List<Object?> get props => [
        contactId,
        phoneMasked,
        readyToRun,
        status,
        reason,
        task,
        confirmHandle,
      ];
}

/// J.9 plan-batch response.
class CallPlanBatchResponse extends Equatable {
  /// Creates a plan-batch response.
  const CallPlanBatchResponse({
    required this.batchId,
    required this.results,
  });

  factory CallPlanBatchResponse.fromJson(Map<String, Object?> json) {
    final rawResults = json['results'];
    final results = <CallPlanRowResult>[];
    if (rawResults is List<dynamic>) {
      for (final item in rawResults) {
        if (item is Map) {
          results.add(
            CallPlanRowResult.fromJson(Map<String, Object?>.from(item)),
          );
        }
      }
    }
    return CallPlanBatchResponse(
      batchId: json['batchId'] as String? ?? '',
      results: results,
    );
  }

  final String batchId;
  final List<CallPlanRowResult> results;

  @override
  List<Object?> get props => [batchId, results];
}

CallPlanRowStatus _planStatus(String? raw) {
  return switch (raw) {
    'planned' => CallPlanRowStatus.planned,
    'dryRun' => CallPlanRowStatus.dryRun,
    'rejected' => CallPlanRowStatus.rejected,
    _ => CallPlanRowStatus.failed,
  };
}

/// Parses a server reject reason wire value.
CallRejectReason? parseCallRejectReason(String? raw) {
  return switch (raw) {
    'notAllowlisted' => CallRejectReason.notAllowlisted,
    'unsupportedRegion' => CallRejectReason.unsupportedRegion,
    'killSwitch' => CallRejectReason.killSwitch,
    'dnc' => CallRejectReason.dnc,
    'invalidPhone' => CallRejectReason.invalidPhone,
    'invalidHandle' => CallRejectReason.invalidHandle,
    _ => null,
  };
}
