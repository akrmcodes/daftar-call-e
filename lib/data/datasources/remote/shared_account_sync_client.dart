import 'package:daftar/core/errors/failures.dart';
import 'package:fpdart/fpdart.dart';

/// B2C shared-account sync placeholder (Stage 8.9).
///
/// Push-triggered fetch and fetch-on-open hooks are no-ops until the
/// immutable B2C mirror is implemented in §8.9.
class SharedAccountSyncClient {
  /// Creates the stub client.
  const SharedAccountSyncClient();

  /// No-op fetch when the shared-account app opens.
  Future<Either<Failure, Unit>> fetchOnOpen() async => const Right(unit);

  /// No-op handler for push notification wake-ups.
  Future<Either<Failure, Unit>> onPushNotification() async =>
      const Right(unit);
}
