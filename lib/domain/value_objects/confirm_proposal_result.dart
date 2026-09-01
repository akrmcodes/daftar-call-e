import 'package:daftar/domain/enums/confirm_proposal_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'confirm_proposal_result.freezed.dart';

/// Device confirm-gate result (OpenAPI `ConfirmProposalResult`).
@freezed
abstract class ConfirmProposalResult with _$ConfirmProposalResult {
  const factory ConfirmProposalResult({
    required String proposalId,
    required ConfirmProposalStatus status,
    String? entityId,
    String? message,
  }) = _ConfirmProposalResult;
}
