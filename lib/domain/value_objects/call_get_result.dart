import 'package:daftar/domain/constants/promised_amount_minor.dart';
import 'package:daftar/domain/constants/promised_calendar_day.dart';
import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:equatable/equatable.dart';

/// Structured CALL-E result after integer coercion.
class CallStructuredOutcome extends Equatable {
  /// Creates a structured outcome.
  const CallStructuredOutcome({
    this.completedCount,
    this.outcome,
    this.promisedAmountMinor,
    this.promisedCurrency,
    this.promisedDate,
    this.language,
    this.acknowledgedHold,
    this.evidenceQuote,
    this.amountInvalid = false,
    this.dateInvalid = false,
  });

  factory CallStructuredOutcome.fromJson(Map<String, Object?> json) {
    final amountRaw = json['promised_amount_minor'] ?? json['promisedAmountMinor'];
    final dateRaw = json['promised_date'] ?? json['promisedDate'];
    return CallStructuredOutcome(
      completedCount: PromisedAmountMinor.tryParse(
        json['completed_count'] ?? json['completedCount'],
      ),
      outcome: parseCallRunOutcome(
        json['outcome'] as String?,
      ),
      promisedAmountMinor: PromisedAmountMinor.tryParse(amountRaw),
      promisedCurrency: json['promised_currency'] as String? ??
          json['promisedCurrency'] as String?,
      promisedDate: PromisedCalendarDay.tryParse(dateRaw),
      language: json['language'] as String?,
      acknowledgedHold: json['acknowledged_hold'] as bool? ??
          json['acknowledgedHold'] as bool?,
      evidenceQuote: json['evidence_quote'] as String? ??
          json['evidenceQuote'] as String?,
      amountInvalid: PromisedAmountMinor.isInvalidPresent(amountRaw),
      dateInvalid: PromisedCalendarDay.isInvalidPresent(dateRaw),
    );
  }

  final int? completedCount;
  final CallRunOutcome? outcome;
  final int? promisedAmountMinor;
  final String? promisedCurrency;
  final String? promisedDate;
  final String? language;
  final bool? acknowledgedHold;
  final String? evidenceQuote;
  final bool amountInvalid;
  final bool dateInvalid;

  @override
  List<Object?> get props => [
        completedCount,
        outcome,
        promisedAmountMinor,
        promisedCurrency,
        promisedDate,
        language,
        acknowledgedHold,
        evidenceQuote,
        amountInvalid,
        dateInvalid,
      ];
}

/// `GET /v1/calls/{runId}` response.
class CallGetResult extends Equatable {
  /// Creates a GET result.
  const CallGetResult({
    required this.runId,
    required this.status,
    required this.terminal,
    required this.phoneMasked,
    required this.needsHuman,
    this.taskCompleted,
    this.structuredResult,
  });

  factory CallGetResult.fromJson(Map<String, Object?> json) {
    final structuredRaw = json['structuredResult'] ?? json['structured_result'];
    final structured = structuredRaw is Map
        ? CallStructuredOutcome.fromJson(
            Map<String, Object?>.from(structuredRaw),
          )
        : null;
    final taskCompleted = json['taskCompleted'] as bool? ??
        json['task_completed'] as bool?;
    final terminal = json['terminal'] == true;
    final status = json['status'] as String? ?? 'unknown';
    final completedOk = status == 'completed';
    final schemaInvalid = (structured?.amountInvalid ?? false) ||
        (structured?.dateInvalid ?? false);
    final wireNeedsHuman =
        json['needsHuman'] == true || json['needs_human'] == true;
    final failedTerminal = status == 'failed' || status == 'canceled';
    final needsHuman = schemaInvalid ||
        (!completedOk && (wireNeedsHuman || failedTerminal));
    return CallGetResult(
      runId: json['runId'] as String? ?? json['run_id'] as String? ?? '',
      status: status,
      terminal: terminal,
      taskCompleted: taskCompleted,
      structuredResult: structured,
      phoneMasked: json['phoneMasked'] as String? ??
          json['phone_masked'] as String? ??
          '',
      needsHuman: needsHuman,
    );
  }

  final String runId;
  final String status;
  final bool terminal;
  final bool? taskCompleted;
  final CallStructuredOutcome? structuredResult;
  final String phoneMasked;
  final bool needsHuman;

  /// Desk rail status from this GET (never `delivered` / `paid`).
  CollectionsCallRowStatus get deskStatus {
    if (structuredResult?.amountInvalid == true ||
        structuredResult?.dateInvalid == true) {
      return CollectionsCallRowStatus.failed;
    }
    if (status == 'failed' || status == 'canceled') {
      return CollectionsCallRowStatus.failed;
    }
    if (terminal && status == 'completed') {
      return CollectionsCallRowStatus.completed;
    }
    if (needsHuman || terminal) {
      return CollectionsCallRowStatus.failed;
    }
    return switch (status) {
      'planned' || 'queued' || 'preparing' || 'unknown' =>
        CollectionsCallRowStatus.planned,
      'ringing' || 'in_progress' => CollectionsCallRowStatus.ringing,
      _ => CollectionsCallRowStatus.ringing,
    };
  }

  @override
  List<Object?> get props => [
        runId,
        status,
        terminal,
        taskCompleted,
        structuredResult,
        phoneMasked,
        needsHuman,
      ];
}

/// Parses J.9 outcome wire values (snake_case).
CallRunOutcome? parseCallRunOutcome(String? raw) {
  return switch (raw) {
    'promised' => CallRunOutcome.promised,
    'refused' => CallRunOutcome.refused,
    'voicemail' => CallRunOutcome.voicemail,
    'no_answer' => CallRunOutcome.noAnswer,
    'wrong_number' => CallRunOutcome.wrongNumber,
    'callback_requested' => CallRunOutcome.callbackRequested,
    _ => null,
  };
}
