import 'package:freezed_annotation/freezed_annotation.dart';

part 'cancel_proposal_result.freezed.dart';

/// Device cancel-gate result (OpenAPI `CancelProposalResult`).
@freezed
abstract class CancelProposalResult with _$CancelProposalResult {
  const factory CancelProposalResult({
    required String proposalId,
    @Default(false) bool journalSkipped,
  }) = _CancelProposalResult;
}
