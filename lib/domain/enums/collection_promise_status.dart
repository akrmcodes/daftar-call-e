/// Display-only promise card status. Does not move ledger money.
enum CollectionPromiseStatus {
  pending,
  kept,
  broken,
  cancelled,
}

/// Merchant-resolved terminal statuses (not [pending]).
extension CollectionPromiseStatusX on CollectionPromiseStatus {
  /// True when the merchant marked the promise kept, broken, or cancelled.
  bool get isMerchantResolution {
    return switch (this) {
      CollectionPromiseStatus.kept ||
      CollectionPromiseStatus.broken ||
      CollectionPromiseStatus.cancelled =>
        true,
      CollectionPromiseStatus.pending => false,
    };
  }
}
