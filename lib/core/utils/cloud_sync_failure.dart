import 'dart:io';

import 'package:daftar/core/errors/failures.dart';

/// Whether a [Failure] should defer Drive backup to the offline queue.
bool isTransientCloudSyncFailure(Failure failure) {
  if (failure is NetworkFailure) {
    return true;
  }
  if (failure is AuthFailure) {
    final code = failure.code;
    return code != 'google_not_signed_in' &&
        code != 'canceled' &&
        code != 'drive_refresh_token_revoked';
  }
  return false;
}

/// Whether [error] represents a transient network fault (for catch blocks).
bool isTransientNetworkError(Object error) {
  if (error is SocketException || error is IOException) {
    return true;
  }
  if (error is Failure) {
    return isTransientCloudSyncFailure(error);
  }
  final text = error.toString().toLowerCase();
  return text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('timed out');
}
