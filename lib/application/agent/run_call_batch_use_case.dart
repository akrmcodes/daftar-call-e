import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/repositories/closing_agent_runtime_repository.dart';
import 'package:daftar/domain/value_objects/call_run_batch.dart';
import 'package:fpdart/fpdart.dart';

/// Device `POST /v1/calls/run-batch`. Providers call this use case only.
class RunCallBatchUseCase {
  /// Creates the use case.
  const RunCallBatchUseCase({
    required ClosingAgentRuntimeRepository runtimeRepository,
  }) : _runtimeRepository = runtimeRepository;

  final ClosingAgentRuntimeRepository _runtimeRepository;

  /// Forwards a validated 1–5 recipient run. Never logs handles.
  Future<Either<Failure, CallRunBatchResponse>> execute(
    CallRunBatchRequest request,
  ) async {
    final count = request.recipients.length;
    if (count < 1 || count > ClosingAgentConstants.maxCallRecipients) {
      return const Left(
        ValidationFailure(
          'Call run batch must have 1 to '
          '${ClosingAgentConstants.maxCallRecipients} recipients.',
          code: 'collections_call_cap',
        ),
      );
    }
    return _runtimeRepository.runCallBatch(request);
  }
}
