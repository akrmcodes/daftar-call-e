import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/closing_agent_runtime_repository.dart';
import 'package:daftar/domain/value_objects/call_get_result.dart';
import 'package:fpdart/fpdart.dart';

/// Device `GET /v1/calls/{runId}`. Providers call this use case only.
class GetCallRunUseCase {
  /// Creates the use case.
  const GetCallRunUseCase({
    required ClosingAgentRuntimeRepository runtimeRepository,
  }) : _runtimeRepository = runtimeRepository;

  final ClosingAgentRuntimeRepository _runtimeRepository;

  /// Polls one CALL-E `call.id`. Empty [runId] is a validation error.
  Future<Either<Failure, CallGetResult>> execute(String runId) async {
    final trimmed = runId.trim();
    if (trimmed.isEmpty) {
      return const Left(
        ValidationFailure(
          'Call run id is required.',
          code: 'call_run_id_required',
        ),
      );
    }
    return _runtimeRepository.getCallRun(trimmed);
  }
}
