import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_claim_result.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_resolve_result.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_token_kind.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for deep-link mint / claim / renewal (Stage 8.5).
abstract class DeepLinkRepository {
  /// Claims [token] via `claim-deep-link` and maps to sealed claim results.
  Future<Either<Failure, DeepLinkClaimResult>> claimToken(
    String token, {
    String? googleEmail,
  });

  /// Read-only preview via `resolve-deep-link` (no mutation).
  Future<Either<Failure, DeepLinkResolveResult>> resolveToken(String token);

  /// Requests a merchant re-invite for a terminal token (stub ping).
  Future<Either<Failure, Unit>> requestNewInvite(String token);

  /// Mints a share or referral deep link (authenticated).
  Future<Either<Failure, CreatedDeepLink>> createDeepLink({
    required DeepLinkTokenKind kind,
    required Map<String, Object?> intentPayload,
  });
}

/// Successful mint response from `create-deep-link`.
class CreatedDeepLink {
  /// Creates a mint result.
  const CreatedDeepLink({
    required this.token,
    required this.url,
    required this.expiresAt,
  });

  /// Opaque token.
  final String token;

  /// Full HTTPS invite URL.
  final String url;

  /// UTC expiry.
  final DateTime expiresAt;
}
