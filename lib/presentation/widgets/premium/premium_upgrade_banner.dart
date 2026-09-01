import 'dart:async' show unawaited;
import 'dart:ui' as ui;

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/providers/premium_upgrade_banner_provider.dart';
import 'package:daftar/presentation/providers/workspace_limit_providers.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Inline, non-blocking Pro upsell when a workspace limit is ≥ 80% utilized.
///
/// Respects permanent user dismissal and follows Khazna v3 glass + glow styling.
class PremiumUpgradeBanner extends ConsumerStatefulWidget {
  const PremiumUpgradeBanner({
    required this.resource,
    super.key,
    this.onUpgradeTap,
  });

  final WorkspaceLimitResource resource;
  final VoidCallback? onUpgradeTap;

  @override
  ConsumerState<PremiumUpgradeBanner> createState() =>
      _PremiumUpgradeBannerState();
}

class _PremiumUpgradeBannerState extends ConsumerState<PremiumUpgradeBanner> {
  bool _exitRequested = false;

  Future<void> _handleDismiss() async {
    if (_exitRequested) {
      return;
    }
    unawaited(HapticService.buttonPress());
    setState(() => _exitRequested = true);
    await ref.read(premiumUpgradeBannerDismissedProvider.notifier).dismiss();
    if (!mounted) {
      return;
    }
    _showDismissedToast();
  }

  void _showDismissedToast() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.premiumUpgradeBannerHiddenToast,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.inkPrimary,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          margin: const EdgeInsetsDirectional.all(AppDimensions.spacingLg),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final dismissedAsync = ref.watch(premiumUpgradeBannerDismissedProvider);
    final snapshotAsync = ref.watch(
      workspaceLimitSnapshotProvider(widget.resource),
    );

    if (dismissedAsync.asData?.value == true || _exitRequested) {
      return const SizedBox.shrink();
    }

    return snapshotAsync.when(
      data: (snapshot) {
        if (!snapshot.shouldShowBanner) {
          return const SizedBox.shrink();
        }
        return _PremiumUpgradeBannerBody(
          snapshot: snapshot,
          onUpgradeTap: widget.onUpgradeTap ??
              () => context.pushNamed(RouteNames.activation),
          onDismiss: () => unawaited(_handleDismiss()),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _PremiumUpgradeBannerBody extends StatelessWidget {
  const _PremiumUpgradeBannerBody({
    required this.snapshot,
    required this.onUpgradeTap,
    required this.onDismiss,
  });

  final WorkspaceLimitSnapshot snapshot;
  final VoidCallback onUpgradeTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final glassFill = isDark ? AppColors.glassFill : AppColors.glassFillLight;
    final borderColor =
        isDark ? AppColors.glassBorder : AppColors.glassBorderLight;
    final trackColor = isDark ? AppColors.surface5 : AppColors.surface3Light;

    final benefit = _benefitForResource(l10n, snapshot.resource);
    final resourceLabel = _resourceLabelForResource(l10n, snapshot.resource);
    final usageLabel = l10n.premiumUpgradeBannerUsage(
      snapshot.currentCount,
      snapshot.maxCount,
      resourceLabel,
    );

    final rawProgress =
        snapshot.maxCount <= 0 ? 0.0 : snapshot.currentCount / snapshot.maxCount;
    final progress = rawProgress > 1.0 ? 1.0 : rawProgress;
    final atLimit = snapshot.currentCount >= snapshot.maxCount;
    final accentColor = atLimit ? AppColors.error : AppColors.warning;

    return FadeSlideTransition(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          bottom: AppDimensions.spacingMd,
        ),
        child: ClipSmoothRect(
          radius: SmoothBorderRadius(
            cornerRadius: AppDimensions.radiusLg,
            cornerSmoothing: 0.6,
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: glassFill,
                border: Border.all(color: borderColor, width: 0.5),
                boxShadow: AppGlows.premiumPro,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppDimensions.spacingLg,
                  AppDimensions.spacingLg,
                  AppDimensions.spacingSm,
                  AppDimensions.spacingLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PremiumSeal(isDark: isDark),
                        const Gap(AppDimensions.spacingMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.premiumUpgradeBannerTitle,
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: inkPrimary,
                                ),
                              ),
                              const Gap(AppDimensions.spacingXxs),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  usageLabel,
                                  style: AppTextStyles.amountSmall.copyWith(
                                    color: accentColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: l10n.premiumUpgradeBannerHide,
                          child: IconButton(
                            onPressed: onDismiss,
                            icon: const Icon(Icons.close_rounded),
                            iconSize: AppDimensions.iconSmall,
                            color: inkSecondary,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: AppDimensions.minTapTarget,
                              minHeight: AppDimensions.minTapTarget,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(AppDimensions.spacingSm),
                    Text(
                      benefit,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: inkSecondary,
                      ),
                    ),
                    const Gap(AppDimensions.spacingMd),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusCircular,
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: trackColor,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                    const Gap(AppDimensions.spacingLg),
                    DaftarButton(
                      label: l10n.premiumUpgradeCta,
                      onPressed: onUpgradeTap,
                      isExpanded: true,
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _benefitForResource(
    AppLocalizations l10n,
    WorkspaceLimitResource resource,
  ) {
    return switch (resource) {
      WorkspaceLimitResource.ledgers => l10n.premiumUpgradeLedgers,
      WorkspaceLimitResource.contacts => l10n.premiumUpgradeContacts,
      WorkspaceLimitResource.transactions => l10n.premiumUpgradeTransactions,
    };
  }

  String _resourceLabelForResource(
    AppLocalizations l10n,
    WorkspaceLimitResource resource,
  ) {
    return switch (resource) {
      WorkspaceLimitResource.ledgers => l10n.premiumUpgradeResourceLedgers,
      WorkspaceLimitResource.contacts => l10n.premiumUpgradeResourceContacts,
      WorkspaceLimitResource.transactions =>
        l10n.premiumUpgradeResourceTransactions,
    };
  }
}

class _PremiumSeal extends StatelessWidget {
  const _PremiumSeal({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimensions.iconLarge,
      height: AppDimensions.iconLarge,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? AppColors.surface4 : AppColors.surface2Light,
        border: Border.all(
          color: AppColors.lapis400.withValues(alpha: 0.45),
          width: 0.5,
        ),
        boxShadow: AppGlows.haloSm,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.workspace_premium_rounded,
        color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
        size: AppDimensions.iconMedium,
      ),
    );
  }
}
