import 'package:daftar/data/datasources/remote/drive_refreshing_http_client.dart';
import 'package:daftar/data/datasources/remote/google_auth_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('DriveRefreshingHttpClient', () {
    test('attaches the bearer token and passes 200 through', () async {
      String? seenAuthorization;
      final sut = DriveRefreshingHttpClient(
        getAccessToken: () async => 'token-a',
        forceRefresh: () async => fail('must not refresh on success'),
        inner: MockClient((request) async {
          seenAuthorization = request.headers['Authorization'];
          return http.Response('ok', 200);
        }),
      );

      final response = await sut.get(Uri.parse('https://drive.test/files'));

      expect(response.statusCode, 200);
      expect(seenAuthorization, 'Bearer token-a');
    });

    test('refreshes once and replays the request on 401', () async {
      final attempts = <String?>[];
      final sut = DriveRefreshingHttpClient(
        getAccessToken: () async => 'stale-token',
        forceRefresh: () async => 'fresh-token',
        inner: MockClient((request) async {
          attempts.add(request.headers['Authorization']);
          if (request.headers['Authorization'] == 'Bearer stale-token') {
            return http.Response('unauthorized', 401);
          }
          return http.Response('ok', 200);
        }),
      );

      final response = await sut.post(
        Uri.parse('https://drive.test/upload'),
        body: 'payload-bytes',
      );

      expect(response.statusCode, 200);
      expect(attempts, ['Bearer stale-token', 'Bearer fresh-token']);
    });

    test('replays the identical body bytes after refresh', () async {
      final bodies = <String>[];
      final sut = DriveRefreshingHttpClient(
        getAccessToken: () async => 'stale-token',
        forceRefresh: () async => 'fresh-token',
        inner: MockClient((request) async {
          bodies.add(request.body);
          if (request.headers['Authorization'] == 'Bearer stale-token') {
            return http.Response('unauthorized', 401);
          }
          return http.Response('ok', 200);
        }),
      );

      await sut.post(
        Uri.parse('https://drive.test/upload'),
        body: 'encrypted-backup-bytes',
      );

      expect(bodies, ['encrypted-backup-bytes', 'encrypted-backup-bytes']);
    });

    test('throws not-signed-in when no token is available', () async {
      final sut = DriveRefreshingHttpClient(
        getAccessToken: () async => null,
        forceRefresh: () async => null,
        inner: MockClient((_) async => http.Response('ok', 200)),
      );

      expect(
        () => sut.get(Uri.parse('https://drive.test/files')),
        throwsA(isA<GoogleAuthNotSignedInException>()),
      );
    });

    test('throws not-signed-in when refresh cannot produce a new token',
        () async {
      final sut = DriveRefreshingHttpClient(
        getAccessToken: () async => 'stale-token',
        forceRefresh: () async => null,
        inner: MockClient((_) async => http.Response('unauthorized', 401)),
      );

      expect(
        () => sut.get(Uri.parse('https://drive.test/files')),
        throwsA(isA<GoogleAuthNotSignedInException>()),
      );
    });

    test('propagates grant revocation from the refresh callback', () async {
      final sut = DriveRefreshingHttpClient(
        getAccessToken: () async => 'stale-token',
        forceRefresh: () async =>
            throw const GoogleDriveGrantRevokedException(),
        inner: MockClient((_) async => http.Response('unauthorized', 401)),
      );

      expect(
        () => sut.get(Uri.parse('https://drive.test/files')),
        throwsA(isA<GoogleDriveGrantRevokedException>()),
      );
    });

    test('does not refresh on non-401 errors', () async {
      var refreshCalls = 0;
      final sut = DriveRefreshingHttpClient(
        getAccessToken: () async => 'token-a',
        forceRefresh: () async {
          refreshCalls++;
          return 'token-b';
        },
        inner: MockClient((_) async => http.Response('server error', 503)),
      );

      final response = await sut.get(Uri.parse('https://drive.test/files'));

      expect(response.statusCode, 503);
      expect(refreshCalls, 0);
    });
  });
}
