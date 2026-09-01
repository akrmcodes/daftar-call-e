import 'dart:async' show unawaited;

import 'package:daftar/application/entitlement/entitlement_limit_helper.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/presentation/providers/entitlement_providers.dart';
import 'package:daftar/presentation/widgets/premium/premium_limit_upsell_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract final class LedgerArchivingGate {
  static Future<bool> ensureUnlocked(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final unlocked = await ref.read(
      canUseFeatureProvider(FeatureFlag.ledgerArchiving).future,
    );
    if (unlocked) {
      return true;
    }
    if (context.mounted) {
      unawaited(
        PremiumLimitUpsellSheet.show(
          context,
          failure: EntitlementLimitHelper.ledgerArchivingTierLocked(),
        ),
      );
    }
    return false;
  }
}
