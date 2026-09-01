import 'package:daftar/domain/entities/deep_link/deep_link_claimed_by.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_intent.dart';

/// Outcome of the claim-deep-link Edge Function (§8.6.1).
///
/// Terminal non-`ok` variants drive the "Request New Invitation" ceremony.
/// Network/auth errors remain Failure types at the repository boundary.
sealed class DeepLinkClaimResult {
  const DeepLinkClaimResult();
}

/// Claim succeeded; [intent] drives in-app routing.
final class DeepLinkClaimOk extends DeepLinkClaimResult {
  const DeepLinkClaimOk(this.intent);

  final DeepLinkIntent intent;
}

/// Token passed its TTL without being claimed.
final class DeepLinkClaimExpired extends DeepLinkClaimResult {
  const DeepLinkClaimExpired();
}

/// Token was revoked by the host merchant.
final class DeepLinkClaimRevoked extends DeepLinkClaimResult {
  const DeepLinkClaimRevoked();
}

/// Token does not exist (internal discriminant; may present as revoked).
final class DeepLinkClaimNotFound extends DeepLinkClaimResult {
  const DeepLinkClaimNotFound();
}

/// Token was already claimed — distinguish self vs other device/account.
final class DeepLinkClaimAlreadyClaimed extends DeepLinkClaimResult {
  const DeepLinkClaimAlreadyClaimed(this.claimedBy);

  final DeepLinkClaimedBy claimedBy;
}
