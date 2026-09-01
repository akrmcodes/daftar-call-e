/// TTL lifecycle state of a deep_link_tokens row (§8.6.1).
enum DeepLinkTokenState {
  /// Token is valid and unclaimed.
  active,

  /// Token was successfully claimed by a device/account.
  claimed,

  /// Token passed its TTL without being claimed.
  expired,

  /// Token was revoked by the host merchant.
  revoked,

  /// Token was replaced by a re-issued link.
  superseded;

  /// Parses a state string from the API or database.
  static DeepLinkTokenState? fromString(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return switch (value.toLowerCase()) {
      'active' => DeepLinkTokenState.active,
      'claimed' => DeepLinkTokenState.claimed,
      'expired' => DeepLinkTokenState.expired,
      'revoked' => DeepLinkTokenState.revoked,
      'superseded' => DeepLinkTokenState.superseded,
      _ => null,
    };
  }

  /// Serializes to the wire / database representation.
  String toWire() => switch (this) {
        DeepLinkTokenState.active => 'active',
        DeepLinkTokenState.claimed => 'claimed',
        DeepLinkTokenState.expired => 'expired',
        DeepLinkTokenState.revoked => 'revoked',
        DeepLinkTokenState.superseded => 'superseded',
      };
}
