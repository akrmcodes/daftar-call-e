import 'dart:convert';
import 'dart:typed_data';

import 'package:daftar/core/env/env.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Provides AES-256-GCM encryption and decryption helpers.
///
/// This utility is used exclusively for encrypting Daftar backup files
/// (`.daftar` extension). Each encryption call generates a fresh random
/// 16-byte IV that is embedded in the output payload.
///
/// Key management:
/// - The 32-byte (256-bit) key is an app-bound constant delivered via
///   `envied` build-time obfuscation. It is NOT stored in
///   `flutter_secure_storage` — the backup pipeline is entirely
///   stateless and survives app reinstall / device migration.
///
/// ## `.daftar` file layout (Version 1)
///
/// ```text
/// [Magic Header 'DFTR' (4 bytes)] [Version (1 byte)] [IV (16 bytes)] [AES-256-GCM ciphertext]
/// ```
///
/// The magic header identifies the file as a Daftar backup. The version
/// byte drives a `switch` in [decryptBackup] so future key rotations
/// (V2, V3, …) can coexist without breaking older backups.
///
/// The GCM authentication tag (16 bytes) is embedded inside the
/// ciphertext block produced by the `encrypt` package — it is NOT
/// stored separately.
abstract final class EncryptionUtil {
  // ── Constants ────────────────────────────────────────────────────────

  /// Length of the AES-256 key in bytes.
  static const int keyLength = 32;

  /// Length of the IV (Initialisation Vector) prepended to each payload.
  ///
  /// 16 bytes is the standard AES block size and the recommended IV
  /// length for AES-GCM with the `encrypt` package.
  static const int ivLength = 16;

  /// Magic header bytes identifying a `.daftar` backup file.
  ///
  /// ASCII `DFTR` — 4 bytes. Present at offset 0 of every valid backup.
  static final Uint8List magicHeader =
      Uint8List.fromList(utf8.encode('DFTR'));

  /// Length of the magic header in bytes.
  static const int magicHeaderLength = 4;

  /// Current encryption format version.
  ///
  /// - Version 1: AES-256-GCM with app-bound key from `Env.backupAesKey`.
  ///
  /// When a key rotation is needed, increment this and add a new branch
  /// in [decryptBackup]'s version switch.
  static const int currentVersion = 1;

  /// Combined length of the fixed header (magic + version byte).
  static const int headerLength = magicHeaderLength + 1; // 5 bytes

  /// Minimum valid payload length: header + IV + at least 1 byte of
  /// ciphertext.
  static const int minPayloadLength = headerLength + ivLength + 1; // 22

  // ── Public API — Low-level primitives ────────────────────────────────

  /// Encrypts [plaintext] using AES-256-GCM with the given [key].
  ///
  /// A cryptographically random 16-byte IV is generated for every call.
  ///
  /// Returns an opaque byte array in the format:
  /// ```text
  /// [IV (16 bytes)] [GCM ciphertext + auth tag]
  /// ```
  ///
  /// Throws [ArgumentError] if [key] is not exactly [keyLength] bytes.
  static Uint8List encrypt(Uint8List plaintext, Uint8List key) {
    _assertKeyLength(key);

    // 1. Generate a fresh random IV for this encryption call.
    final iv = enc.IV.fromSecureRandom(ivLength);

    // 2. Build the AES-GCM encrypter from the 32-byte key.
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
    );

    // 3. Encrypt the plaintext bytes.
    final encrypted = encrypter.encryptBytes(plaintext, iv: iv);

    // 4. Prepend the IV to the ciphertext so restore can recover it.
    final output = Uint8List(ivLength + encrypted.bytes.length)
      ..setRange(0, ivLength, iv.bytes)
      ..setRange(ivLength, ivLength + encrypted.bytes.length, encrypted.bytes);

    return output;
  }

  /// Decrypts a payload previously produced by [encrypt].
  ///
  /// Reads the first [ivLength] bytes as the IV, then decrypts the
  /// remainder using AES-256-GCM.
  ///
  /// Returns the original plaintext bytes.
  ///
  /// Throws [ArgumentError] if [key] is not exactly [keyLength] bytes or
  /// if the [payload] is shorter than [ivLength] bytes.
  /// Throws [StateError] if GCM authentication fails (tampered ciphertext).
  static Uint8List decrypt(Uint8List payload, Uint8List key) {
    _assertKeyLength(key);

    if (payload.length <= ivLength) {
      throw ArgumentError(
        'Payload too short: expected > $ivLength bytes, got ${payload.length}.',
      );
    }

    // 1. Extract the IV from the first 16 bytes.
    final iv = enc.IV(Uint8List.fromList(payload.sublist(0, ivLength)));

    // 2. The remainder is the GCM ciphertext (including embedded auth tag).
    final cipherBytes = Uint8List.fromList(payload.sublist(ivLength));

    // 3. Build the decrypter.
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
    );

    // 4. Decrypt — GCM will throw if the authentication tag is invalid.
    final plaintext = encrypter.decryptBytes(
      enc.Encrypted(cipherBytes),
      iv: iv,
    );

    return Uint8List.fromList(plaintext);
  }

  // ── Public API — Backup-level wrappers ──────────────────────────────

  /// Encrypts [plaintext] as a versioned `.daftar` backup payload.
  ///
  /// Uses the app-bound AES-256 key from [Env.backupAesKey].
  /// A fresh random IV is generated for every call.
  ///
  /// Returns a byte array in the format:
  /// ```text
  /// [DFTR (4 bytes)] [Version (1 byte)] [IV (16 bytes)] [GCM ciphertext]
  /// ```
  ///
  /// The version byte is set to [currentVersion] (currently 1).
  ///
  /// Throws [FormatException] if [Env.backupAesKey] is not valid Base64.
  /// Throws [ArgumentError] if the decoded key is not [keyLength] bytes.
  static Uint8List encryptBackup(Uint8List plaintext) {
    final key = _resolveKeyForVersion(currentVersion);

    // 1. Encrypt using the low-level primitive (produces IV + ciphertext).
    final ivAndCiphertext = encrypt(plaintext, key);

    // 2. Build the versioned payload:
    //    [DFTR (4)] + [version (1)] + [IV (16) + ciphertext (N)]
    final output = Uint8List(headerLength + ivAndCiphertext.length)
      ..setRange(0, magicHeaderLength, magicHeader)
      ..[magicHeaderLength] = currentVersion
      ..setRange(headerLength, headerLength + ivAndCiphertext.length,
          ivAndCiphertext);

    return output;
  }

  /// Decrypts a versioned `.daftar` backup payload.
  ///
  /// Reads the magic header and version byte to determine which key
  /// and decryption strategy to use. This guarantees forward
  /// compatibility: future V2/V3 key rotations add a new branch in
  /// the version switch without breaking existing V1 backups.
  ///
  /// Returns the original plaintext database bytes.
  ///
  /// Throws [FormatException] if:
  /// - The payload is too short to contain a valid header + IV.
  /// - The first 4 bytes are not `DFTR` (not a Daftar backup).
  /// - The version byte is unsupported.
  /// - The key is not valid Base64.
  /// Throws [StateError] if GCM authentication fails (tampered/wrong key).
  static Uint8List decryptBackup(Uint8List encryptedPayload) {
    // Step 1: Validate minimum payload size.
    if (encryptedPayload.length < minPayloadLength) {
      throw FormatException(
        'Payload too short: expected >= $minPayloadLength bytes, '
        'got ${encryptedPayload.length}.',
      );
    }

    // Step 2: Validate magic header — first 4 bytes must be 'DFTR'.
    final headerBytes = encryptedPayload.sublist(0, magicHeaderLength);
    if (!_bytesEqual(headerBytes, magicHeader)) {
      throw const FormatException('Invalid backup file format.');
    }

    // Step 3: Read version byte and resolve the appropriate key.
    final version = encryptedPayload[magicHeaderLength];
    final key = _resolveKeyForVersion(version);

    // Step 4: Extract the IV + ciphertext block (everything after the
    // 5-byte header) and delegate to the low-level decrypt primitive.
    final ivAndCiphertext = Uint8List.fromList(
      encryptedPayload.sublist(headerLength),
    );

    return decrypt(ivAndCiphertext, key);
  }

  // ── Private helpers ──────────────────────────────────────────────────

  /// Resolves the AES-256 key for a given backup format [version].
  ///
  /// Version 1: app-bound key from `Env.backupAesKey` (Base64-encoded).
  ///
  /// Future versions add new branches here — the switch guarantees
  /// older backups remain decryptable even after key rotation.
  ///
  /// Throws [FormatException] if the version is unsupported.
  /// Throws [FormatException] if the Base64 key is malformed.
  /// Throws [FormatException] if the decoded key is not [keyLength] bytes.
  static Uint8List _resolveKeyForVersion(int version) {
    switch (version) {
      case 1:
        final bytes = base64Decode(Env.backupAesKey);
        if (bytes.length != keyLength) {
          throw FormatException(
            'Decoded key length is ${bytes.length}, expected $keyLength.',
          );
        }
        return Uint8List.fromList(bytes);
      default:
        throw FormatException(
          'Unsupported backup version: $version. '
          'Update the app to decrypt this backup.',
        );
    }
  }

  static void _assertKeyLength(Uint8List key) {
    if (key.length != keyLength) {
      throw ArgumentError(
        'AES-256 key must be exactly $keyLength bytes, got ${key.length}.',
      );
    }
  }

  /// Constant-time byte array comparison to avoid timing side-channels.
  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
