import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/data/datasources/remote/sync_remote_ds.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class _FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  late MockDio dio;
  late SyncRemoteDs remoteDs;

  const baseUrl = 'http://192.168.8.81:54321/functions/v1';
  const syncJwt = 'sync-jwt-test';

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

  group('SyncRemoteDs.pullOps', () {
    test('parses successful pull response into SyncOperation list', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {
            'ops': [
              {
                'id': 'audit-1',
                'entity_type': 'transaction',
                'entity_id': 'txn-1',
                'action': 'CREATE',
                'device_id': 'device-owner',
                'logged_at': '2026-01-01T12:00:00.000Z',
                'server_updated_at': '2026-01-01T12:00:00.000Z',
                'op_seq': 42,
                'workspace_role': 'owner',
                'payload': {'amount': 1500},
              },
            ],
          },
          requestOptions: RequestOptions(),
        ),
      );

      final page = await remoteDs.pullOps(
        syncJwt: syncJwt,
        sinceOpSeq: 10,
      );

      expect(page.ops, hasLength(1));
      final op = page.ops.single;
      expect(op.id, 'audit-1');
      expect(op.entityType, 'transaction');
      expect(op.entityId, 'txn-1');
      expect(op.action, 'CREATE');
      expect(op.deviceId, 'device-owner');
      expect(op.role, 'owner');
      expect(op.opSeq, 42);
      expect(
        op.serverUpdatedAt,
        DateTime.utc(2026, 1, 1, 12),
      );
      expect(op.fieldDeltas, '{"amount":1500}');
    });

    test('sends query params and auth headers', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        final path = invocation.positionalArguments[0] as String;
        expect(path, '$baseUrl/pull-sync-ops');

        final query =
            invocation.namedArguments[#queryParameters] as Map<String, dynamic>;
        expect(query['since_op_seq'], 25);
        expect(query['limit'], 100);

        final options = invocation.namedArguments[#options] as Options?;
        expect(options?.headers?['Authorization'], 'Bearer $syncJwt');
        expect(options?.headers?['apikey'], 'sb_publishable_test');
        expect(options?.headers?['Content-Type'], 'application/json');

        return Response<Map<String, dynamic>>(
          data: {'ops': <Map<String, dynamic>>[]},
          requestOptions: RequestOptions(),
        );
      });

      await remoteDs.pullOps(
        syncJwt: syncJwt,
        sinceOpSeq: 25,
        limit: 100,
      );
    });

    test('returns empty list when ops array is empty', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {'ops': <Map<String, dynamic>>[]},
          requestOptions: RequestOptions(),
        ),
      );

      final page = await remoteDs.pullOps(
        syncJwt: syncJwt,
        sinceOpSeq: 0,
      );

      expect(page.ops, isEmpty);
    });

    test('fails closed to viewer role when workspace_role is missing', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {
            'ops': [
              {
                'id': 'audit-legacy',
                'entity_type': 'contact',
                'entity_id': 'contact-1',
                'action': 'UPDATE',
                'device_id': 'device-1',
                'logged_at': '2026-01-01T12:00:00.000Z',
                'server_updated_at': '2026-01-01T12:00:00.000Z',
                'op_seq': 1,
                'payload': null,
              },
            ],
          },
          requestOptions: RequestOptions(),
        ),
      );

      final page = await remoteDs.pullOps(
        syncJwt: syncJwt,
        sinceOpSeq: 0,
      );

      expect(
        page.ops.single.role,
        'viewer',
        reason: 'Unknown roles must never gain merge authority',
      );
    });

    test('throws ServerException when a pulled op is missing its id', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {
            'ops': [
              {
                'entity_type': 'transaction',
                'entity_id': 'txn-1',
                'action': 'CREATE',
                'device_id': 'device-1',
                'logged_at': '2026-01-01T12:00:00.000Z',
                'server_updated_at': '2026-01-01T12:00:00.000Z',
                'op_seq': 1,
              },
            ],
          },
          requestOptions: RequestOptions(),
        ),
      );

      expect(
        () => remoteDs.pullOps(syncJwt: syncJwt, sinceOpSeq: 0),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws ServerException on an unparseable timestamp', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {
            'ops': [
              {
                'id': 'audit-1',
                'entity_type': 'transaction',
                'entity_id': 'txn-1',
                'action': 'CREATE',
                'device_id': 'device-1',
                'logged_at': 'not-a-date',
                'server_updated_at': '2026-01-01T12:00:00.000Z',
                'op_seq': 1,
              },
            ],
          },
          requestOptions: RequestOptions(),
        ),
      );

      expect(
        () => remoteDs.pullOps(syncJwt: syncJwt, sinceOpSeq: 0),
        throwsA(isA<ServerException>()),
      );
    });

    test('preserves integer money in payload without coercion', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {
            'ops': [
              {
                'id': 'audit-2',
                'entity_type': 'transaction',
                'entity_id': 'txn-2',
                'action': 'UPDATE',
                'device_id': 'device-1',
                'logged_at': '2026-01-01T12:00:00.000Z',
                'server_updated_at': '2026-01-01T12:00:00.000Z',
                'op_seq': 2,
                'workspace_role': 'editor',
                'payload': {'amount': 1500, 'note': 'test'},
              },
            ],
          },
          requestOptions: RequestOptions(),
        ),
      );

      final page = await remoteDs.pullOps(
        syncJwt: syncJwt,
        sinceOpSeq: 0,
      );

      final decoded = page.ops.single.fieldDeltas;
      expect(decoded, isNotNull);
      expect(decoded!.contains('"amount":1500'), isTrue);
      expect(decoded.contains('"amount":1500.0'), isFalse);
    });

    test('throws ServerException when ops array is missing', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {},
          requestOptions: RequestOptions(),
        ),
      );

      expect(
        () => remoteDs.pullOps(syncJwt: syncJwt, sinceOpSeq: 0),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws ServerException on 5xx response', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
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
        () => remoteDs.pullOps(syncJwt: syncJwt, sinceOpSeq: 0),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws ServerException on connection timeout', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
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
        () => remoteDs.pullOps(syncJwt: syncJwt, sinceOpSeq: 0),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
