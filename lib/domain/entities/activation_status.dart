import 'package:daftar/domain/enums/app_tier.dart';

/// Summary of the current activation for plan-status UI.
class ActivationStatus {
  const ActivationStatus({
    required this.tier,
    this.expiresAt,
    this.daysRemaining,
  });

  final AppTier tier;
  final DateTime? expiresAt;
  final int? daysRemaining;
}
