/// Intent classification for a deep-link token (Stages 11 & 14).
enum DeepLinkTokenKind {
  /// B2C shared-ledger invite.
  share,

  /// Referral / attribution link.
  referral,

  /// Pro+ worker workspace invite.
  workerInvite;

  /// Parses a kind string from the API or database.
  static DeepLinkTokenKind? fromString(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return switch (value.toLowerCase()) {
      'share' => DeepLinkTokenKind.share,
      'referral' => DeepLinkTokenKind.referral,
      'worker_invite' => DeepLinkTokenKind.workerInvite,
      _ => null,
    };
  }

  /// Serializes to the wire / database representation.
  String toWire() => switch (this) {
        DeepLinkTokenKind.share => 'share',
        DeepLinkTokenKind.referral => 'referral',
        DeepLinkTokenKind.workerInvite => 'worker_invite',
      };
}
