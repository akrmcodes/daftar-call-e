import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/cloud_sync_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isTransientCloudSyncFailure', () {
    test('treats NetworkFailure as transient', () {
      expect(
        isTransientCloudSyncFailure(
          const NetworkFailure('offline', code: 'offline'),
        ),
        isTrue,
      );
    });

    test('treats hard auth failures as non-transient', () {
      expect(
        isTransientCloudSyncFailure(
          const AuthFailure('not signed in', code: 'google_not_signed_in'),
        ),
        isFalse,
      );
      expect(
        isTransientCloudSyncFailure(
          const AuthFailure('canceled', code: 'canceled'),
        ),
        isFalse,
      );
    });

    test('treats other AuthFailure codes as transient', () {
      expect(
        isTransientCloudSyncFailure(
          const AuthFailure('silent failed', code: 'silent_sign_in_failed'),
        ),
        isTrue,
      );
    });
  });
}
