import 'package:daftar/core/services/premium_upgrade_banner_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'premium_upgrade_banner_provider.g.dart';

/// Whether the user permanently dismissed the inline Pro upsell banner.
@Riverpod(keepAlive: true)
class PremiumUpgradeBannerDismissed extends _$PremiumUpgradeBannerDismissed {
  @override
  Future<bool> build() => PremiumUpgradeBannerStore.isDismissed;

  Future<void> dismiss() async {
    await PremiumUpgradeBannerStore.dismiss();
    state = const AsyncData(true);
  }
}
