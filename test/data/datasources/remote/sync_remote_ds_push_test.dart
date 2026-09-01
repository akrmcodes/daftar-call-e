import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/data/datasources/remote/sync_remote_ds.dart';
import 'package:daftar/domain/entities/sync_operation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class _FakeRequestOptions extends Fake implements RequestOptions {}

SyncOperation _sampleOp({String? fieldDeltas}) {
  return SyncOperation(
    id: 'audit-1',
    entityType: 'transaction',
    entityId: 'txn-1',
    action: 'CREATE',
    deviceId: 'device-1',
    role: 'owner',
    localTimestamp: DateTime.utc(2026, 1, 1, 12),
    serverUpdatedAt: DateTime.utc(2026, 1, 1, 12),
    opSeq: 0,
    fieldDeltas: fieldDeltas,
  );
}

void main() {
  late MockDio dio;
  late SyncRemoteDs remoteDs;

  const baseUrl = 'http://192.168.8.81:54321/functions/v1';
  const syncJwt = 'sync-jwt-test';
  const deviceId = 'device-uuid';

  setUpAll(() {
    registerFallbackValue(_FakeRequestOptions());
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = MockDio();
    remoteDs = SyncRemoteDs(
      dio: dio,
      functionsBaseUrl: baseUrl,
      publishableKey: 'sb_publishable_test',
    );
  });

  group('SyncRemoteDs.pushOps', () {
    test('returns empty list without HTTP call when ops is empty', () async {
      final result = await remoteDs.pushOps(
        syncJwt: syncJwt,
        deviceId: deviceId,
        ops: const [],
      );

      expect(result.acks, isEmpty);
      expect(result.rejections, isEmpty);
      verifyNever(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      );
    });

    test('parses successful push response into PushOpAck list', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {
            'results': [
              {
                'id': 'audit-1',
                'op_seq': 42,
                'server_updated_at': '2026-01-01T12:00:00.000Z',
                'status': 'applied',
              },
            ],
          },
          requestOptions: RequestOptions(),
        ),
      );

      final result = await remoteDs.pushOps(
        syncJwt: syncJwt,
        deviceId: deviceId,
        ops: [_sampleOp()],
      );

      expect(result.acks, hasLength(1));
      expect(result.acks.single.auditLogId, 'audit-1');
      expect(result.acks.single.opSeq, 42);
      expect(
        result.acks.single.serverUpdatedAt,
        DateTime.utc(2026, 1, 1, 12),
      );
    });

    test('sends Edge-contract request body and auth headers', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        final path = invocation.positionalArguments[0] as String;
        expect(path, '$baseUrl/push-sync-ops');

        final data = invocation.namedArguments[#data] as Map<String, dynamic>;
        expect(data['device_id'], deviceId);

        final ops = data['ops'] as List<dynamic>;
        expect(ops, hasLength(1));

        final op = ops.single as Map<String, dynamic>;
        expect(op['id'], 'audit-1');
        expect(op['entity_type'], 'transaction');
        expect(op['entity_id'], 'txn-1');
        expect(op['action'], 'CREATE');
        expect(op['local_timestamp'], '2026-01-01T12:00:00.000Z');
        expect(op['field_deltas'], {'amount': 1500});

        final options = invocation.namedArguments[#options] as Options?;
        expect(options?.headers?['Authorization'], 'Bearer $syncJwt');
        expect(options?.headers?['apikey'], 'sb_publishable_test');
        expect(options?.headers?['Content-Type'], 'application/json');

        return Response<Map<String, dynamic>>(
          data: {
            'results': [
              {
                'id': 'audit-1',
                'op_seq': 1,
                'server_updated_at': '2026-01-01T12:00:00.000Z',
                'status': 'applied',
              },
            ],
          },
          requestOptions: RequestOptions(),
        );
      });

      await remoteDs.pushOps(
        syncJwt: syncJwt,
        deviceId: deviceId,
        ops: [_sampleOp(fieldDeltas: '{"amount": 1500}')],
      );
    });

    test('preserves integer money in field_deltas without coercion', () async {
      Map<String, dynamic>? capturedOp;

      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        final data = invocation.namedArguments[#data] as Map<String, dynamic>;
        final ops = data['ops'] as List<dynamic>;
        capturedOp = ops.single as Map<String, dynamic>;

        return Response<Map<String, dynamic>>(
          data: {
            'results': [
              {
                'id': 'audit-1',
                'op_seq': 1,
                'server_updated_at': '2026-01-01T12:00:00.000Z',
                'status': 'applied',
              },
            ],
          },
          requestOptions: RequestOptions(),
        );
      });

      await remoteDs.pushOps(
        syncJwt: syncJwt,
        deviceId: deviceId,
        ops: [_sampleOp(fieldDeltas: '{"amount": 1500, "note": "test"}')],
      );

      final deltas = capturedOp!['field_deltas'] as Map<String, dynamic>;
      expect(deltas['amount'], 1500);
      expect(deltas['amount'], isA<int>());
    });

    test('throws SyncCapExceededException on device_cap_exceeded', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          response: Response(
            statusCode: 409,
            data: {'code': 'device_cap_exceeded'},
            requestOptions: RequestOptions(),
          ),
        ),
      );

      expect(
        () => remoteDs.pushOps(
          syncJwt: syncJwt,
          deviceId: deviceId,
          ops: [_sampleOp()],
        ),
        throwsA(
          isA<SyncCapExceededException>().having(
            (e) => e.code,
            'code',
            'device_cap_exceeded',
          ),
        ),
      );
    });

    test('throws SyncCapExceededException on sync_event_cap_exceeded', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          response: Response(
            statusCode: 409,
            data: {'code': 'sync_event_cap_exceeded'},
            requestOptions: RequestOptions(),
          ),
        ),
      );

      expect(
        () => remoteDs.pushOps(
          syncJwt: syncJwt,
          deviceId: deviceId,
          ops: [_sampleOp()],
        ),
        throwsA(
          isA<SyncCapExceededException>().having(
            (e) => e.code,
            'code',
            'sync_event_cap_exceeded',
          ),
        ),
      );
    });

    test('throws ServerException on 5xx response', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          message: 'Internal Server Error',
          response: Response(
            statusCode: 503,
            requestOptions: RequestOptions(),
          ),
        ),
      );

      expect(
        () => remoteDs.pushOps(
          syncJwt: syncJwt,
          deviceId: deviceId,
          ops: [_sampleOp()],
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws ServerException on connection timeout', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionTimeout,
          message: 'connection timeout',
        ),
      );

      expect(
        () => remoteDs.pushOps(
          syncJwt: syncJwt,
          deviceId: deviceId,
          ops: [_sampleOp()],
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws ServerException when results array is missing', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {},
          requestOptions: RequestOptions(),
        ),
      );

      expect(
        () => remoteDs.pushOps(
          syncJwt: syncJwt,
          deviceId: deviceId,
          ops: [_sampleOp()],
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
