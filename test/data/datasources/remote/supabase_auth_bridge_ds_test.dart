import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/services/sync_token_store.dart';
import 'package:daftar/data/datasources/remote/supabase_auth_bridge_ds.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockSyncTokenStore extends Mock implements SyncTokenStore {}

class _FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  late MockDio dio;
  late MockSyncTokenStore syncTokenStore;
  late SupabaseAuthBridgeDs bridgeDs;

  const successPayload = {
    'sync_token': 'sync-jwt',
    'expires_in': 3600,
    'workspace_id': 'ws-1',
    'role': 'owner',
  };

  setUpAll(() {
    registerFallbackValue(_FakeRequestOptions());
    registerFallbackValue(Options());
    registerFallbackValue(
      SyncTokenBundle(
        syncToken: 'fallback',
        workspaceId: 'ws-fallback',
        role: 'owner',
        obtainedAt: DateTime.utc(2026),
        expiresIn: 3600,
      ),
    );
  });

  setUp(() {
    dio = MockDio();
    syncTokenStore = MockSyncTokenStore();
    bridgeDs = SupabaseAuthBridgeDs(
      dio: dio,
      syncTokenStore: syncTokenStore,
      baseUrl: 'https://example.supabase.co/functions/v1',
      publishableKey: 'sb_publishable_test',
    );
  });

  group('SupabaseAuthBridgeDs', () {
    test('exchangeGoogleToken sends apikey header and persists bundle', () async {
      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        final options = invocation.namedArguments[#options] as Options?;
        expect(options?.headers?['apikey'], 'sb_publishable_test');
        expect(options?.headers?['Content-Type'], 'application/json');

        return Response<dynamic>(
          data: successPayload,
          requestOptions: RequestOptions(),
        );
      });

      when(() => syncTokenStore.write(any())).thenAnswer((_) async {});

      final bundle = await bridgeDs.exchangeGoogleToken('google-id-token');

      expect(bundle.syncToken, 'sync-jwt');
      expect(bundle.workspaceId, 'ws-1');
      expect(bundle.role, 'owner');
      verify(() => syncTokenStore.write(any())).called(1);
    });

    test('exchangeGoogleToken coerces expires_in when JSON number is double',
        () async {
      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          data: {
            ...successPayload,
            'expires_in': 3600.0,
          },
          requestOptions: RequestOptions(),
        ),
      );

      when(() => syncTokenStore.write(any())).thenAnswer((_) async {});

      final bundle = await bridgeDs.exchangeGoogleToken('google-id-token');

      expect(bundle.expiresIn, 3600);
    });

    test('exchangeGoogleToken parses JSON string response body', () async {
      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          data:
              '{"sync_token":"sync-jwt","expires_in":3600,"workspace_id":"ws-1","role":"owner"}',
          requestOptions: RequestOptions(),
        ),
      );

      when(() => syncTokenStore.write(any())).thenAnswer((_) async {});

      final bundle = await bridgeDs.exchangeGoogleToken('google-id-token');

      expect(bundle.syncToken, 'sync-jwt');
      expect(bundle.workspaceId, 'ws-1');
    });

    test('exchangeGoogleToken throws ServerException when sync_token has wrong type',
        () async {
      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          data: {
            'sync_token': 123,
            'expires_in': 3600,
            'workspace_id': 'ws-1',
            'role': 'owner',
          },
          requestOptions: RequestOptions(),
        ),
      );

      expect(
        () => bridgeDs.exchangeGoogleToken('google-id-token'),
        throwsA(isA<ServerException>()),
      );
    });

    test('exchangeGoogleToken maps 401 to SyncAuthException', () async {
      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          response: Response(
            statusCode: 401,
            requestOptions: RequestOptions(),
          ),
        ),
      );

      expect(
        () => bridgeDs.exchangeGoogleToken('bad-token'),
        throwsA(isA<SyncAuthException>()),
      );
    });

    test('concurrent exchanges for different Google tokens do not cross-contaminate',
        () async {
      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        final data =
            invocation.namedArguments[#data] as Map<String, String>;
        final idToken = data['id_token']!;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return Response<dynamic>(
          data: {
            'sync_token': 'jwt-$idToken',
            'expires_in': 3600,
            'workspace_id': 'ws-$idToken',
            'role': 'owner',
            'identity_hash': 'hash-$idToken',
          },
          requestOptions: RequestOptions(),
        );
      });
      when(() => syncTokenStore.write(any())).thenAnswer((_) async {});

      final results = await Future.wait([
        bridgeDs.exchangeGoogleToken('token-A'),
        bridgeDs.exchangeGoogleToken('token-B'),
      ]);

      expect(results[0].workspaceId, 'ws-token-A');
      expect(results[1].workspaceId, 'ws-token-B');
      expect(results[0].syncToken, 'jwt-token-A');
      expect(results[1].syncToken, 'jwt-token-B');
    });

    test('exchangeGoogleToken throws ServerException when sync_token missing',
        () async {
      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          data: {'workspace_id': 'ws-1', 'role': 'owner'},
          requestOptions: RequestOptions(),
        ),
      );

      expect(
        () => bridgeDs.exchangeGoogleToken('google-id-token'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
