import 'package:daftar/domain/entities/deep_link/deep_link_claimed_by.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_intent.dart';

/// Read-only preview of a deep-link token (Stage 8.5 `resolve-deep-link`).
sealed class DeepLinkResolveResult {
  const DeepLinkResolveResult();
}

/// Token is active and claimable.
final class DeepLinkResolveActive extends DeepLinkResolveResult {
  const DeepLinkResolveActive(this.intent);

  final DeepLinkIntent intent;
}

/// Token passed its TTL without being claimed.
final class DeepLinkResolveExpired extends DeepLinkResolveResult {
  const DeepLinkResolveExpired();
}

/// Token was revoked or superseded.
final class DeepLinkResolveRevoked extends DeepLinkResolveResult {
  const DeepLinkResolveRevoked();
}

/// Token does not exist (internal; may present as revoked).
final class DeepLinkResolveNotFound extends DeepLinkResolveResult {
  const DeepLinkResolveNotFound();
}

/// Token was already claimed.
final class DeepLinkResolveAlreadyClaimed extends DeepLinkResolveResult {
  const DeepLinkResolveAlreadyClaimed(this.claimedBy);

  final DeepLinkClaimedBy claimedBy;
}
