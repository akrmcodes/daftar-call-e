import 'package:daftar/core/errors/failures.dart';
import 'package:fpdart/fpdart.dart';

/// Machine-readable code when Drive scopes were never granted or expired and
/// cannot be refreshed without interactive sign-in.
const String kDriveScopesNotAuthorizedCode = 'drive_scopes_not_authorized';

/// Verifies Google Drive session prerequisites without interactive sign-in.
///
/// Implemented in the data layer (`DriveSessionGatewayImpl`). Application
/// use cases depend on this contract so headless backup stays free of
/// `GoogleAuthDs` imports.
abstract class DriveSessionGateway {
  /// Steps 2–4 after silent sign-in succeeds:
  /// cached account → scope check (no UI) → headless HTTP client probe.
  Future<Either<Failure, Unit>> verifyHeadlessDrivePrerequisites();

  Future<Either<Failure, Unit>> verifyHeadlessDrivePrerequisitesPkceOnly();
}
