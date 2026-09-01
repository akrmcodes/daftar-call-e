/// Workspace and monetization limits owned by the domain layer.
abstract final class EntitlementLimits {
  /// Sentinel for uncapped Pro / Pro+ workspace limits.
  static const int unlimited = -1;

  static const int freeMaxLedgers = 1;
  static const int freeMaxContacts = 50;
  static const int freeMaxTransactions = 500;
}
