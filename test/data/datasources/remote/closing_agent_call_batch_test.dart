import 'dart:convert';
import 'dart:typed_data';

import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/data/datasources/remote/closing_agent_remote_ds.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/value_objects/call_plan_batch.dart';
import 'package:daftar/domain/value_objects/call_run_batch.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const contactId = '11111111-1111-4111-8111-111111111111';
  const batchId = '22222222-2222-4222-8222-222222222222';
  const correlationId = '33333333-3333-4333-8333-333333333333';

  CallPlanBatchRequest planRequest() {
    return const CallPlanBatchRequest(
      batchId: batchId,
      correlationId: correlationId,
      trigger: CallBatchTrigger.closeDay,
      dryRun: false,
      locale: 'en',
      recipients: [
        CallPlanRecipient(
          contactId: contactId,
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
  }

  ClosingAgentRemoteDs dsWith(HttpClientAdapter adapter) {
    return ClosingAgentRemoteDs(
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'https://agent.test',
      readIdToken: ({required allowInteractive}) async => 'test-id-token',
    );
  }

  test('plan-batch posts JSON and parses confirmHandle', () async {
    final adapter = _JsonAdapter(
      status: 200,
      body: jsonEncode({
        'batchId': batchId,
        'results': [
          {
            'contactId': contactId,
            'phoneMasked': '+…0100',
            'readyToRun': true,
            'status': 'planned',
            'confirmHandle': 'tok-1',
          },
        ],
      }),
    );
    final ds = dsWith(adapter);

    final response = await ds.planCallBatch(planRequest());

    expect(adapter.lastPath, '/v1/calls/plan-batch');
    expect(adapter.lastAuthorization, 'Bearer test-id-token');
    expect(response.results.single.confirmHandle, 'tok-1');
    expect(adapter.lastJsonBody?['dryRun'], isFalse);
  });

  test('run-batch 403 killSwitch maps to calle_kill_switch', () async {
    final adapter = _JsonAdapter(
      status: 403,
      body: jsonEncode({'detail': 'killSwitch', 'needsHuman': true}),
    );
    final ds = dsWith(adapter);

    expect(
      () => ds.runCallBatch(
        const CallRunBatchRequest(
          batchId: batchId,
          correlationId: correlationId,
          recipients: [
            CallRunRecipient(
              contactId: contactId,
              confirmHandle: 'tok-1',
            ),
          ],
        ),
      ),
      throwsA(
        isA<ServerException>().having(
          (error) => error.errorCode,
          'errorCode',
          'calle_kill_switch',
        ),
      ),
    );
  });

  test('GET call parses terminal promised int', () async {
    final adapter = _JsonAdapter(
      status: 200,
      body: jsonEncode({
        'runId': 'calle-1',
        'status': 'completed',
        'terminal': true,
        'phoneMasked': '+…0100',
        'needsHuman': false,
        'structuredResult': {
          'outcome': 'promised',
          'promised_amount_minor': 1500,
          'promised_currency': 'USD',
          'promised_date': '2026-09-10',
        },
      }),
    );
    final ds = dsWith(adapter);

    final result = await ds.getCallRun('calle-1');

    expect(adapter.lastPath, '/v1/calls/calle-1');
    expect(result.terminal, isTrue);
    expect(result.needsHuman, isFalse);
    expect(result.structuredResult?.promisedAmountMinor, 1500);
  });

  test('GET completed without schema is not needsHuman', () async {
    final adapter = _JsonAdapter(
      status: 200,
      body: jsonEncode({
        'runId': 'calle-2',
        'status': 'completed',
        'terminal': true,
        'taskCompleted': true,
        'phoneMasked': '+…0100',
        'needsHuman': true,
      }),
    );
    final ds = dsWith(adapter);

    final result = await ds.getCallRun('calle-2');

    expect(result.needsHuman, isFalse);
    expect(result.structuredResult, isNull);
    expect(result.deskStatus, CollectionsCallRowStatus.completed);
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter({required this.status, required this.body});

  final int status;
  final String body;
  String? lastPath;
  String? lastAuthorization;
  Map<String, Object?>? lastJsonBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.uri.path;
    lastAuthorization = options.headers['Authorization'] as String? ??
        options.headers['authorization'] as String?;
    if (requestStream != null) {
      final builder = BytesBuilder(copy: false);
      await requestStream.forEach(builder.add);
      final raw = utf8.decode(builder.takeBytes());
      if (raw.isNotEmpty) {
        lastJsonBody = Map<String, Object?>.from(jsonDecode(raw) as Map);
      }
    }
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
