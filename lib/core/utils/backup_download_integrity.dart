import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/encryption_util.dart';
import 'package:fpdart/fpdart.dart';

const String _damagedBackupUserMessage =
    'Backup file is damaged. Please try another backup.';

/// Verifies a downloaded encrypted `.daftar` before decrypt or restore.
///
/// Runs file reads and SHA-256 on a background isolate to avoid blocking the
/// UI thread on large backups.
Future<Either<Failure, Unit>> verifyDownloadedEncryptedBackupFile({
  required String absolutePath,
  required String expectedChecksumHex,
}) {
  return Isolate.run(
    () => _verifyDownloadedEncryptedBackupFileSync(
      absolutePath,
      expectedChecksumHex,
    ),
  );
}

Either<Failure, Unit> _verifyDownloadedEncryptedBackupFileSync(
  String absolutePath,
  String expectedChecksumHex,
) {
  final file = File(absolutePath);
  if (!file.existsSync()) {
    return const Left(
      StorageFailure(
        'Downloaded backup file was not found on disk.',
        code: 'drive_download_missing',
      ),
    );
  }
  final length = file.lengthSync();
  if (length == 0) {
    return const Left(
      ValidationFailure(
        _damagedBackupUserMessage,
        code: 'drive_download_empty',
      ),
    );
  }
  if (length < EncryptionUtil.magicHeaderLength) {
    return const Left(
      ValidationFailure(
        _damagedBackupUserMessage,
        code: 'drive_download_truncated',
      ),
    );
  }

  final raf = file.openSync();
  try {
    final head = raf.readSync(EncryptionUtil.magicHeaderLength);
    if (!_bytesEqual(head, EncryptionUtil.magicHeader)) {
      return const Left(
        ValidationFailure(
          _damagedBackupUserMessage,
          code: 'drive_download_bad_magic',
        ),
      );
    }
  } finally {
    raf.closeSync();
  }

  final normalized = expectedChecksumHex.trim().toLowerCase();
  if (normalized.isEmpty) {
    return const Right(unit);
  }

  final bytes = file.readAsBytesSync();
  final digest = sha256.convert(bytes).toString().toLowerCase();
  if (digest != normalized) {
    return const Left(
      ValidationFailure(
        _damagedBackupUserMessage,
        code: 'drive_download_checksum_mismatch',
      ),
    );
  }
  return const Right(unit);
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
