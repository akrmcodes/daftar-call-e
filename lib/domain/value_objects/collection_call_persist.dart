import 'package:daftar/domain/enums/call_batch_status.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:equatable/equatable.dart';

/// Seed a `collection_call_runs` row after `run-batch` queues.
class CollectionCallRunSeed extends Equatable {
  /// Creates a queued-run seed.
  const CollectionCallRunSeed({
    required this.contactId,
    required this.region,
    required this.locale,
    required this.runId,
  });

  final String contactId;
  final String region;
  final String locale;
  final String runId;

  @override
  List<Object?> get props => [contactId, region, locale, runId];
}

/// Header + queued runs after Confirm & Call `run-batch`.
class CollectionCallBatchSeed extends Equatable {
  /// Creates a batch seed.
  const CollectionCallBatchSeed({
    required this.batchId,
    required this.correlationId,
    required this.trigger,
    required this.status,
    required this.runs,
  });

  final String batchId;
  final String correlationId;
  final CallBatchTrigger trigger;
  final CallBatchStatus status;
  final List<CollectionCallRunSeed> runs;

  @override
  List<Object?> get props => [batchId, correlationId, trigger, status, runs];
}

/// Terminal GET write-back for one run.
class CollectionCallTerminalWrite extends Equatable {
  /// Creates a terminal write.
  const CollectionCallTerminalWrite({
    required this.runId,
    required this.contactId,
    required this.rawStatus,
    required this.needsHuman,
    this.outcome,
    this.promisedAmountMinor,
    this.promisedCurrency,
    this.promisedDate,
    this.acknowledgedHold,
    this.evidenceQuote,
    this.amountInvalid = false,
  });

  final String runId;
  final String contactId;
  final String rawStatus;
  final bool needsHuman;
  final CallRunOutcome? outcome;
  final int? promisedAmountMinor;
  final String? promisedCurrency;
  final String? promisedDate;
  final bool? acknowledgedHold;
  final String? evidenceQuote;
  final bool amountInvalid;

  /// Promise card only when outcome is promised, amount is a valid int, and
  /// date is a calendar day.
  bool get shouldUpsertPromise {
    if (outcome != CallRunOutcome.promised || amountInvalid) {
      return false;
    }
    final amount = promisedAmountMinor;
    final date = promisedDate?.trim() ?? '';
    final currency = promisedCurrency?.trim() ?? '';
    return amount != null && date.isNotEmpty && currency.isNotEmpty;
  }

  @override
  List<Object?> get props => [
        runId,
        contactId,
        rawStatus,
        needsHuman,
        outcome,
        promisedAmountMinor,
        promisedCurrency,
        promisedDate,
        acknowledgedHold,
        evidenceQuote,
        amountInvalid,
      ];
}
