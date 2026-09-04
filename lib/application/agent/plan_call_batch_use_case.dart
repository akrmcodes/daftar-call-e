import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/repositories/closing_agent_runtime_repository.dart';
import 'package:daftar/domain/value_objects/call_plan_batch.dart';
import 'package:fpdart/fpdart.dart';

/// Device `POST /v1/calls/plan-batch`. Providers call this use case only.
class PlanCallBatchUseCase {
  /// Creates the use case.
  const PlanCallBatchUseCase({
    required ClosingAgentRuntimeRepository runtimeRepository,
  }) : _runtimeRepository = runtimeRepository;

  final ClosingAgentRuntimeRepository _runtimeRepository;

  /// Forwards a validated 1–5 recipient plan. Never logs handles or E.164.
  Future<Either<Failure, CallPlanBatchResponse>> execute(
    CallPlanBatchRequest request,
  ) async {
    final count = request.recipients.length;
    if (count < 1 || count > ClosingAgentConstants.maxCallRecipients) {
      return const Left(
        ValidationFailure(
          'Call plan batch must have 1 to '
          '${ClosingAgentConstants.maxCallRecipients} recipients.',
          code: 'collections_call_cap',
        ),
      );
    }
    return _runtimeRepository.planCallBatch(request);
  }
}
