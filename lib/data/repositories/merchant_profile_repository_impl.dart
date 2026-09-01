import 'dart:io';

import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/local/merchant_profile_local_ds.dart';
import 'package:daftar/data/mappers/merchant_profile_mapper.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/domain/repositories/merchant_profile_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path/path.dart' as p;

/// Drift-backed implementation of [MerchantProfileRepository].
///
/// The repository keeps the logical merchant profile singleton in sync with a
/// deterministic logo file stored inside the app documents directory.
class MerchantProfileRepositoryImpl implements MerchantProfileRepository {
  /// Creates a merchant profile repository implementation.
  MerchantProfileRepositoryImpl({
    required MerchantProfileLocalDs merchantProfileLocalDs,
    required Future<Directory> Function() documentsDirectoryResolver,
  }) : _localDs = merchantProfileLocalDs,
       _documentsDirectoryResolver = documentsDirectoryResolver;

  final MerchantProfileLocalDs _localDs;
  final Future<Directory> Function() _documentsDirectoryResolver;

  static const String _logoDirectoryName = 'merchant_profile';
  static const String _logoFileName = 'logo';

  @override
  Stream<MerchantProfile?> watch() {
    return _localDs.watchProfile().map((row) => row?.toDomain());
  }

  @override
  Future<Either<Failure, MerchantProfile?>> get() async {
    try {
      final row = await _localDs.getProfile();
      return Right(row?.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> update(MerchantProfile profile) async {
    try {
      final currentProfile = await _localDs.getProfile();
      final storedProfile = profile.copyWith(
        id: currentProfile?.id ?? profile.id,
        createdAt: currentProfile?.createdAt ?? profile.createdAt,
        storeName: profile.storeName.trim(),
        storePhone: _normalizeNullable(profile.storePhone),
        logoPath: _normalizeNullable(profile.logoPath),
      );

      await _localDs.upsertProfile(storedProfile.toCompanion());
      return const Right(unit);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> setLogo(String logoPath) async {
    String? previousLogoPath;
    String? copiedLogoPath;
    try {
      final currentProfile = await _localDs.getProfile();
      if (currentProfile == null) {
        return Left(notFoundFailure('Merchant profile', 'singleton'));
      }

      final sourcePath = logoPath.trim();
      if (sourcePath.isEmpty) {
        return const Left(
          StorageFailure(
            'Logo file path is empty.',
            code: 'merchant_logo_invalid_path',
          ),
        );
      }

      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) {
        return const Left(
          StorageFailure(
            'Logo file not found.',
            code: 'merchant_logo_not_found',
          ),
        );
      }

      final documentsDirectory = await _documentsDirectoryResolver();
      final targetPath = _managedLogoPath(documentsDirectory);
      final targetFile = File(targetPath);
      await targetFile.parent.create(recursive: true);

      final sourceMatchesTarget = _samePath(sourceFile.path, targetPath);
      if (!sourceMatchesTarget) {
        await sourceFile.copy(targetPath);
        copiedLogoPath = targetPath;
      }

      previousLogoPath = currentProfile.logoPath;
      await _localDs.updateLogoPath(targetPath);

      if (_shouldRemovePreviousLogo(previousLogoPath, targetPath)) {
        await _deleteFileBestEffort(previousLogoPath!);
      }

      return const Right(unit);
    } on FileSystemException catch (error) {
      if (copiedLogoPath != null &&
          !_samePath(previousLogoPath, copiedLogoPath)) {
        await _deleteFileBestEffort(copiedLogoPath);
      }
      return Left(
        StorageFailure(
          'Failed to store merchant logo: ${error.message}',
          code: 'merchant_logo_io_error',
        ),
      );
    } on Object catch (error) {
      if (copiedLogoPath != null &&
          !_samePath(previousLogoPath, copiedLogoPath)) {
        await _deleteFileIfExists(copiedLogoPath);
      }
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> clearLogo() async {
    try {
      final currentProfile = await _localDs.getProfile();
      final documentsDirectory = await _documentsDirectoryResolver();
      final fallbackLogoPath = _managedLogoPath(documentsDirectory);
      final pathToDelete = currentProfile?.logoPath?.trim().isNotEmpty == true
          ? currentProfile!.logoPath!.trim()
          : fallbackLogoPath;

      await _deleteFileIfExists(pathToDelete);
      await _localDs.updateLogoPath(null);

      if (!_samePath(pathToDelete, fallbackLogoPath)) {
        await _deleteFileBestEffort(fallbackLogoPath);
      }

      return const Right(unit);
    } on FileSystemException catch (error) {
      return Left(
        StorageFailure(
          'Failed to delete merchant logo: ${error.message}',
          code: 'merchant_logo_delete_error',
        ),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  String _managedLogoPath(Directory documentsDirectory) {
    return p.join(
      documentsDirectory.path,
      _logoDirectoryName,
      _logoFileName,
    );
  }

  bool _samePath(String? firstPath, String? secondPath) {
    if (firstPath == null || secondPath == null) {
      return false;
    }

    return p.normalize(firstPath) == p.normalize(secondPath);
  }

  bool _shouldRemovePreviousLogo(String? previousLogoPath, String targetPath) {
    if (previousLogoPath == null || previousLogoPath.trim().isEmpty) {
      return false;
    }

    return !_samePath(previousLogoPath.trim(), targetPath);
  }

  Future<void> _deleteFileIfExists(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<void> _deleteFileBestEffort(String path) async {
    try {
      await _deleteFileIfExists(path);
    } on FileSystemException {
      // Best-effort cleanup: the primary repository operation already
      // completed, so stale-file deletion failures are swallowed.
    }
  }

  String? _normalizeNullable(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
