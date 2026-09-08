import 'package:daftar/domain/value_objects/call_plan_batch.dart';
import 'package:equatable/equatable.dart';

/// J.9 run-batch row status.
enum CallRunRemoteStatus {
  queued,
  rejected,
  failed,
  skippedDuplicate,
}

/// One `run-batch` recipient (handle only — no E.164).
class CallRunRecipient extends Equatable {
  /// Creates a run recipient.
  const CallRunRecipient({
    required this.contactId,
    required this.confirmHandle,
  });

  final String contactId;

  /// Memory-only confirm token. Never log.
  final String confirmHandle;

  Map<String, Object?> toJson() {
    return {
      'contactId': contactId,
      'confirmHandle': confirmHandle,
    };
  }

  @override
  List<Object?> get props => [contactId, confirmHandle];
}

/// `POST /v1/calls/run-batch` body.
class CallRunBatchRequest extends Equatable {
  /// Creates a run-batch request.
  const CallRunBatchRequest({
    required this.batchId,
    required this.correlationId,
    required this.recipients,
    this.attempt = 0,
  });

  final String batchId;
  final String correlationId;
  final List<CallRunRecipient> recipients;

  /// 0 = first create; 1 = one HITL no-answer/voicemail retry.
  final int attempt;

  Map<String, Object?> toJson() {
    return {
      'batchId': batchId,
      'correlationId': correlationId,
      'recipients': [
        for (final recipient in recipients) recipient.toJson(),
      ],
      if (attempt != 0) 'attempt': attempt,
    };
  }

  @override
  List<Object?> get props => [batchId, correlationId, recipients, attempt];
}

/// One run-batch result row.
class CallRunRowResult extends Equatable {
  /// Creates a run row result.
  const CallRunRowResult({
    required this.contactId,
    required this.status,
    this.runId,
    this.reason,
    this.phoneMasked,
  });

  factory CallRunRowResult.fromJson(Map<String, Object?> json) {
    return CallRunRowResult(
      contactId: json['contactId'] as String? ?? '',
      status: _runStatus(json['status'] as String?),
      runId: json['runId'] as String?,
      reason: parseCallRejectReason(json['reason'] as String?),
      phoneMasked: json['phoneMasked'] as String?,
    );
  }

  final String contactId;
  final CallRunRemoteStatus status;
  final String? runId;
  final CallRejectReason? reason;
  final String? phoneMasked;

  @override
  List<Object?> get props => [contactId, status, runId, reason, phoneMasked];
}

/// J.9 run-batch response.
class CallRunBatchResponse extends Equatable {
  /// Creates a run-batch response.
  const CallRunBatchResponse({
    required this.batchId,
    required this.results,
    required this.needsHuman,
  });

  factory CallRunBatchResponse.fromJson(Map<String, Object?> json) {
    final rawResults = json['results'];
    final results = <CallRunRowResult>[];
    if (rawResults is List<dynamic>) {
      for (final item in rawResults) {
        if (item is Map) {
          results.add(
            CallRunRowResult.fromJson(Map<String, Object?>.from(item)),
          );
        }
      }
    }
    return CallRunBatchResponse(
      batchId: json['batchId'] as String? ?? '',
      results: results,
      needsHuman: json['needsHuman'] == true,
    );
  }

  final String batchId;
  final List<CallRunRowResult> results;
  final bool needsHuman;

  @override
  List<Object?> get props => [batchId, results, needsHuman];
}

CallRunRemoteStatus _runStatus(String? raw) {
  return switch (raw) {
    'queued' => CallRunRemoteStatus.queued,
    'skippedDuplicate' => CallRunRemoteStatus.skippedDuplicate,
    'rejected' => CallRunRemoteStatus.rejected,
    _ => CallRunRemoteStatus.failed,
  };
}
