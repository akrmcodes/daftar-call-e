import 'package:daftar/data/datasources/remote/auth_silent_sign_in_gateway_impl.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

class MockGoogleAuthDs extends Mock implements GoogleAuthDs {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  late MockGoogleAuthDs googleAuthDs;
  late AuthSilentSignInGatewayImpl gateway;
  late MockGoogleSignInAccount account;

  AuthSessionBundle sampleBundle() => AuthSessionBundle.create(
        googleUserId: 'google-sub-123',
        email: 'merchant@example.com',
        serverClientId: 'web-client-id.apps.googleusercontent.com',
        scopesGranted: AuthScopes.defaultDriveBackupScopes,
        linkedAt: DateTime.utc(2026, 6, 8, 12),
      );

  setUp(() {
    googleAuthDs = MockGoogleAuthDs();
    gateway = AuthSilentSignInGatewayImpl(googleAuthDs);
    account = MockGoogleSignInAccount();
    when(() => account.id).thenReturn('google-sub-123');
  });

  test('returns true when bundle has valid cached access token', () async {
    final bundle = sampleBundle().withCachedAccessToken('oauth-access-token');

    final recovered = await gateway.attemptSilentRecovery(bundle);

    expect(recovered, isTrue);
    verifyNever(() => googleAuthDs.getAccount());
    verifyNever(() => googleAuthDs.signInSilently());
  });

  test('returns true when warm account matches bundle without silent call',
      () async {
    when(() => googleAuthDs.getAccount()).thenReturn(account);

    final recovered = await gateway.attemptSilentRecovery(sampleBundle());

    expect(recovered, isTrue);
    verifyNever(() => googleAuthDs.signInSilently());
  });

  test('delegates to signInSilently when no warm account', () async {
    when(() => googleAuthDs.getAccount()).thenReturn(null);
    when(() => googleAuthDs.signInSilently()).thenAnswer((_) async => account);

    final recovered = await gateway.attemptSilentRecovery(sampleBundle());

    expect(recovered, isTrue);
    verify(() => googleAuthDs.signInSilently()).called(1);
  });

  test('uses PKCE refresh only when offline grant exists', () async {
    when(() => googleAuthDs.ensureDriveCredential())
        .thenAnswer((_) async => DriveCredentialStatus.ready);

    final bundle = sampleBundle().withDriveOfflineGrant(
      refreshToken: 'refresh-token',
      clientId: 'android-client.apps.googleusercontent.com',
    );

    final recovered = await gateway.attemptSilentRecovery(bundle);

    expect(recovered, isTrue);
    verify(() => googleAuthDs.ensureDriveCredential()).called(1);
    verifyNever(() => googleAuthDs.signInSilently());
    verifyNever(() => googleAuthDs.getAccount());
  });

  test('returns false when silent account id mismatches bundle', () async {
    when(() => googleAuthDs.getAccount()).thenReturn(null);
    when(() => account.id).thenReturn('other-id');
    when(() => googleAuthDs.signInSilently()).thenAnswer((_) async => account);

    final recovered = await gateway.attemptSilentRecovery(sampleBundle());

    expect(recovered, isFalse);
  });
}
