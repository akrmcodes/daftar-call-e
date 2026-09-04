import 'package:daftar/application/agent/plan_call_batch_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:daftar/domain/repositories/closing_agent_runtime_repository.dart';
import 'package:daftar/domain/value_objects/agent_audio_clip.dart';
import 'package:daftar/domain/value_objects/agent_turn_result.dart';
import 'package:daftar/domain/value_objects/call_get_result.dart';
import 'package:daftar/domain/value_objects/call_plan_batch.dart';
import 'package:daftar/domain/value_objects/call_run_batch.dart';
import 'package:daftar/domain/value_objects/device_agent_request.dart';
import 'package:daftar/domain/value_objects/email_send_batch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  test('plan use case rejects empty recipients', () async {
    final useCase = PlanCallBatchUseCase(
      runtimeRepository: _FakeRuntime(),
    );
    final result = await useCase.execute(
      const CallPlanBatchRequest(
        batchId: '11111111-1111-4111-8111-111111111111',
        correlationId: '22222222-2222-4222-8222-222222222222',
        trigger: CallBatchTrigger.closeDay,
        dryRun: false,
        locale: 'en',
        recipients: [],
      ),
    );
    expect(result.getLeft().toNullable()?.code, 'collections_call_cap');
  });

  test('plan use case forwards a valid request', () async {
    final runtime = _FakeRuntime();
    final useCase = PlanCallBatchUseCase(runtimeRepository: runtime);
    const request = CallPlanBatchRequest(
      batchId: '11111111-1111-4111-8111-111111111111',
      correlationId: '22222222-2222-4222-8222-222222222222',
      trigger: CallBatchTrigger.closeDay,
      dryRun: false,
      locale: 'en',
      recipients: [
        CallPlanRecipient(
          contactId: '11111111-1111-4111-8111-111111111111',
          phoneE164: '+15555550100',
          region: 'US',
          locale: 'en',
          task: 'Call Mohamed',
          customerName: 'Mohamed',
          storeName: 'Daftar',
          amountLine: '15.00 USD',
        ),
      ],
    );

    final result = await useCase.execute(request);

    expect(result.getRight().toNullable()?.batchId, request.batchId);
    expect(runtime.planned, same(request));
  });
}

class _FakeRuntime implements ClosingAgentRuntimeRepository {
  CallPlanBatchRequest? planned;

  @override
  Future<Either<Failure, CallPlanBatchResponse>> planCallBatch(
    CallPlanBatchRequest request,
  ) async {
    planned = request;
    return Right(
      CallPlanBatchResponse(batchId: request.batchId, results: const []),
    );
  }

  @override
  Future<Either<Failure, Unit>> createOrUpdateSession({
    required String userId,
    required String sessionId,
    required DeviceAgentRequest context,
  }) async => const Right(unit);

  @override
  Future<Either<Failure, CallGetResult>> getCallRun(String runId) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, List<String>>> listApps() async => const Right([]);

  @override
  Future<Either<Failure, CallRunBatchResponse>> runCallBatch(
    CallRunBatchRequest request,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, AgentTurnResult>> runTurn({
    required String userId,
    required String sessionId,
    required DeviceAgentRequest context,
    AgentAudioClip? audio,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, EmailSendBatchResponse>> sendEmailBatch(
    EmailSendBatchRequest request,
  ) async {
    throw UnimplementedError();
  }
}
