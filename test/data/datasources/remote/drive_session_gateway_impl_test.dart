import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/remote/drive_session_gateway_impl.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/data/datasources/remote/google_auth_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockGoogleAuthDs extends Mock implements GoogleAuthDs {}

class _FakeAuthClient extends Fake implements http.Client {
  bool closed = false;

  @override
  void close() => closed = true;
}

void main() {
  late _MockGoogleAuthDs authDs;
  late DriveSessionGatewayImpl gateway;

  setUp(() {
    authDs = _MockGoogleAuthDs();
    gateway = DriveSessionGatewayImpl(authDs);
  });

  group('DriveSessionGatewayImpl.verifyHeadlessDrivePrerequisitesPkceOnly', () {
    test('succeeds from bundle credential without SDK account', () async {
      final client = _FakeAuthClient();
      when(() => authDs.tryClientFromBundleOrRefresh())
          .thenAnswer((_) async => client);

      final result = await gateway.verifyHeadlessDrivePrerequisitesPkceOnly();

      expect(result.isRight(), isTrue);
      expect(client.closed, isTrue);
      verifyNever(() => authDs.getAccount());
    });

    test('returns network_unavailable when credential is absent', () async {
      when(() => authDs.tryClientFromBundleOrRefresh())
          .thenAnswer((_) async => null);

      final result = await gateway.verifyHeadlessDrivePrerequisitesPkceOnly();

      result.fold(
        (failure) {
          expect(failure, isA<NetworkFailure>());
          expect(failure.code, 'network_unavailable');
        },
        (_) => fail('Expected network failure'),
      );
      verifyNever(() => authDs.getAccount());
    });

    test('maps revoked grant to drive_refresh_token_revoked', () async {
      when(() => authDs.tryClientFromBundleOrRefresh())
          .thenThrow(const GoogleDriveGrantRevokedException());

      final result = await gateway.verifyHeadlessDrivePrerequisitesPkceOnly();

      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 'drive_refresh_token_revoked');
        },
        (_) => fail('Expected revoked failure'),
      );
    });
  });

  group('DriveSessionGatewayImpl.verifyHeadlessDrivePrerequisites', () {
    test('succeeds from bundle credential (cached or refreshed) without a '
        'live SDK account', () async {
      final client = _FakeAuthClient();
      when(() => authDs.tryClientFromBundleOrRefresh())
          .thenAnswer((_) async => client);

      final result = await gateway.verifyHeadlessDrivePrerequisites();

      expect(result.isRight(), isTrue);
      expect(client.closed, isTrue);
      verifyNever(() => authDs.getAccount());
    });

    test('maps a revoked offline grant to drive_refresh_token_revoked',
        () async {
      when(() => authDs.tryClientFromBundleOrRefresh())
          .thenThrow(const GoogleDriveGrantRevokedException());

      final result = await gateway.verifyHeadlessDrivePrerequisites();

      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 'drive_refresh_token_revoked');
        },
        (_) => fail('Expected a Left failure for a revoked grant'),
      );
    });

    test('returns silent_sign_in_failed when no credential and SDK is cold',
        () async {
      when(() => authDs.tryClientFromBundleOrRefresh())
          .thenAnswer((_) async => null);
      when(() => authDs.getAccount()).thenReturn(null);

      final result = await gateway.verifyHeadlessDrivePrerequisites();

      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 'silent_sign_in_failed');
        },
        (_) => fail('Expected a Left failure when the session is unrecoverable'),
      );
    });
  });
}
