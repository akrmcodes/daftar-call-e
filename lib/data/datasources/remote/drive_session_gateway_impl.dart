import 'dart:async';

import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/data/datasources/remote/google_auth_exceptions.dart';
import 'package:daftar/data/datasources/remote/google_auth_failure_mapper.dart';
import 'package:daftar/domain/services/drive_session_gateway.dart';
import 'package:fpdart/fpdart.dart';

class DriveSessionGatewayImpl implements DriveSessionGateway {
  const DriveSessionGatewayImpl(this._googleAuthDs);

  final GoogleAuthDs _googleAuthDs;

  static const Duration _pkceHeadlessTimeout = Duration(seconds: 30);

  @override
  Future<Either<Failure, Unit>> verifyHeadlessDrivePrerequisitesPkceOnly() async {
    try {
      final bundleClient = await _googleAuthDs
          .tryClientFromBundleOrRefresh()
          .timeout(_pkceHeadlessTimeout);
      if (bundleClient != null) {
        bundleClient.close();
        return const Right(unit);
      }
      return const Left(
        NetworkFailure(
          'Drive credentials unavailable in headless context.',
          code: 'network_unavailable',
        ),
      );
    } on TimeoutException {
      return const Left(
        NetworkFailure(
          'Drive credential refresh timed out.',
          code: 'network_unavailable',
        ),
      );
    } on GoogleDriveGrantRevokedException catch (e) {
      return Left(GoogleAuthFailureMapper.fromGrantRevokedException(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> verifyHeadlessDrivePrerequisites() async {
    try {
      final bundleClient = await _googleAuthDs.tryClientFromBundleOrRefresh();
      if (bundleClient != null) {
        bundleClient.close();
        return const Right(unit);
      }
    } on GoogleDriveGrantRevokedException catch (e) {
      return Left(GoogleAuthFailureMapper.fromGrantRevokedException(e));
    }

    final account = _googleAuthDs.getAccount();
    if (account == null) {
      return const Left(
        AuthFailure(
          'Silent Google sign-in did not restore a session.',
          code: 'silent_sign_in_failed',
        ),
      );
    }

    if (!await _googleAuthDs.hasDriveScopesAuthorized(account)) {
      return const Left(
        AuthFailure(
          'Google Drive is not authorized for this account. Sign in again to '
          'use Drive backup.',
          code: kDriveScopesNotAuthorizedCode,
        ),
      );
    }

    try {
      final client = await _googleAuthDs.getAuthenticatedHttpClient();
      client.close();
    } on GoogleAuthNotSignedInException catch (e) {
      return Left(
        AuthFailure(
          e.message,
          code: 'google_not_signed_in',
        ),
      );
    } on Object catch (e) {
      return Left(
        AuthFailure(
          'Could not obtain an authorized Drive client: $e',
          code: 'drive_auth_client_failed',
        ),
      );
    }

    return const Right(unit);
  }
}
