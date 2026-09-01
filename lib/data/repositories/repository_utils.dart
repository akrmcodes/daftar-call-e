import 'dart:convert';

import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/device_identity_store.dart';

/// Stable device identifier used for audit log entries on this installation.
String get repositoryDeviceId => DeviceIdentity.current;

/// Maps a data-layer exception or error to a database failure.
DatabaseFailure databaseFailure(
  Object error, {
  String messagePrefix = 'Database operation failed',
}) {
  if (error is DatabaseException) {
    return DatabaseFailure(error.message, code: 'database_exception');
  }

  return DatabaseFailure(
    '$messagePrefix: $error',
    code: 'database_error',
  );
}

/// Creates a validation failure with an optional machine-readable code.
ValidationFailure validationFailure(String message, {String? code}) {
  return ValidationFailure(message, code: code);
}

/// Creates a not-found database failure for the given entity and identifier.
DatabaseFailure notFoundFailure(String entity, String id) {
  return DatabaseFailure(
    '$entity not found: $id',
    code: '${entity.toLowerCase()}_not_found',
  );
}

/// Encodes an audit payload map as JSON.
String encodePayload(Map<String, Object?> payload) => jsonEncode(payload);
