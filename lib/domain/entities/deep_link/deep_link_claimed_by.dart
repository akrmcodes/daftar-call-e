/// Who claimed a deep-link token when status is `already_claimed`.
enum DeepLinkClaimedBy {
  /// The current device/account already claimed this token.
  byYou,

  /// A different device/account claimed this token.
  byOther;

  /// Parses a claimed_by string from the claim-deep-link API response.
  static DeepLinkClaimedBy? fromString(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return switch (value.toLowerCase()) {
      'by_you' => DeepLinkClaimedBy.byYou,
      'by_other' => DeepLinkClaimedBy.byOther,
      _ => null,
    };
  }

  /// Serializes to the wire / API representation.
  String toWire() => switch (this) {
        DeepLinkClaimedBy.byYou => 'by_you',
        DeepLinkClaimedBy.byOther => 'by_other',
      };
}
