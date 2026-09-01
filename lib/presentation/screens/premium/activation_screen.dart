import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/presentation/providers/entitlement_providers.dart';
import 'package:daftar/presentation/providers/premium_providers.dart';
import 'package:daftar/presentation/screens/premium/widgets/activation_panel.dart';
import 'package:daftar/presentation/screens/premium/widgets/activation_success_sheet.dart';
import 'package:daftar/presentation/screens/premium/widgets/plan_compare_section.dart';
import 'package:daftar/presentation/screens/premium/widgets/plan_status_card.dart';
import 'package:daftar/presentation/screens/premium/widgets/plan_tier_stack.dart';
import 'package:daftar/presentation/screens/premium/widgets/plan_trust_strip.dart';
import 'package:daftar/presentation/shared/widgets/daftar_scroll_screen_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Plans & activation — conversion-first layout with Khazna glow-as-currency.
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
  final _scrollController = ScrollController();
  final GlobalKey _plansSectionKey = GlobalKey();

  AppTier _selectedTier = AppTier.pro;
  bool _didSyncTier = false;
  bool _codeFieldFocused = false;
  int _expandToken = 0;

  @override
  void initState() {
    super.initState();
    _codeFocus.addListener(_onCodeFocusChanged);
  }

  @override
  void dispose() {
    _codeFocus.removeListener(_onCodeFocusChanged);
    _codeController.dispose();
    _codeFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onCodeFocusChanged() {
    final focused = _codeFocus.hasFocus;
    if (focused != _codeFieldFocused && mounted) {
      setState(() => _codeFieldFocused = focused);
    }
  }

  Future<void> _onActivate() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    unawaited(HapticService.medium());

    final ok = await ref.read(activateCodeControllerProvider.notifier).activate(
      code,
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      final tier = ref.read(entitlementProvider).value?.tier ?? _selectedTier;
      _codeController.clear();
      await ActivationSuccessSheet.show(context, tier: tier);
    }
  }

  void _focusActivation() {
    setState(() => _expandToken++);
    // Already at top — soft scroll only if keyboard would obscure.
    unawaited(
      Future<void>.delayed(AppDimensions.animationFast, () {
        if (!mounted) {
          return;
        }
        _codeFocus.requestFocus();
      }),
    );
  }

  void _onTierCta(AppTier tier) {
    if (tier == AppTier.free) {
      unawaited(Navigator.of(context).maybePop());
      return;
    }
    setState(() => _selectedTier = tier);
    _focusActivation();
  }

  void _scrollToPlans() {
    final target = _plansSectionKey.currentContext;
    if (target != null) {
      unawaited(
        Scrollable.ensureVisible(
          target,
          duration: AppDimensions.animationMedium,
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? AppColors.surface0 : AppColors.surface0Light;

    final entitlementAsync = ref.watch(entitlementProvider);
    final statusAsync = ref.watch(activationStatusProvider);
    final activateState = ref.watch(activateCodeControllerProvider);

    final currentTier = entitlementAsync.value?.tier ?? AppTier.free;

    ref.listen(entitlementProvider, (previous, next) {
      next.whenData((entitlement) {
        if (!_didSyncTier && mounted) {
          _didSyncTier = true;
          setState(() {
            _selectedTier = entitlement.tier == AppTier.free
                ? AppTier.pro
                : entitlement.tier;
          });
        }
      });
    });

    final failureMessage = activateState.error != null
        ? ErrorTranslator.activationFailureMessage(
            l10n,
            activateState.error!,
          )
        : null;

    final bottomScrollClearance = MediaQuery.paddingOf(context).bottom +
        AppDimensions.shellDockScrollInset;

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          DaftarScrollScreenTitleSliver(
            title: Text(
              l10n.premiumTitle,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: Icon(
                isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
              ),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppDimensions.pagePaddingH,
              0,
              AppDimensions.pagePaddingH,
              bottomScrollClearance,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                entitlementAsync.when(
                  data: (entitlement) => PlanStatusCard(
                    tier: entitlement.tier,
                    status: statusAsync.value,
                  ),
                  loading: () => const _PlanStatusShimmer(),
                  error: (_, _) => PlanStatusCard(
                    tier: AppTier.free,
                    status: statusAsync.value,
                  ),
                ),
                const Gap(AppDimensions.spacingLg),
                // Conversion-first: activation sits above plan browsing.
                ActivationPanel(
                  controller: _codeController,
                  focusNode: _codeFocus,
                  isLoading: activateState.isLoading,
                  errorMessage: failureMessage,
                  startCollapsed: currentTier != AppTier.free,
                  expandToken: _expandToken,
                  onActivate: _onActivate,
                )
                    .animate()
                    .fadeIn(duration: 320.ms)
                    .slideY(
                      begin: 0.03,
                      end: 0,
                      duration: 320.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const Gap(AppDimensions.spacingXl),
                KeyedSubtree(
                  key: _plansSectionKey,
                  child: _BrowsePlansHeader(
                    title: l10n.activationBrowsePlans,
                    subtitle: AppConstants.kContestDisableMultiDeviceSync
                        ? l10n.premiumHeroTaglineContest
                        : l10n.premiumHeroTagline,
                    onTap: _scrollToPlans,
                  ),
                ),
                const Gap(AppDimensions.spacingLg),
                PlanTierStack(
                  selectedTier: _selectedTier,
                  currentTier: currentTier,
                  codeFieldFocused: _codeFieldFocused,
                  onTierSelected: (t) => setState(() => _selectedTier = t),
                  onTierCta: _onTierCta,
                ),
                const Gap(AppDimensions.spacingLg),
                const PlanTrustStrip(),
                const Gap(AppDimensions.spacingXxl),
                entitlementAsync.when(
                  data: (e) => PlanCompareSection(
                    currentTier: e.tier,
                    focusTier: _selectedTier,
                    onFocusTierChanged: (t) =>
                        setState(() => _selectedTier = t),
                  ),
                  loading: () => const _CompareShimmer(),
                  error: (_, _) => PlanCompareSection(
                    currentTier: AppTier.free,
                    focusTier: _selectedTier,
                    onFocusTierChanged: (t) =>
                        setState(() => _selectedTier = t),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowsePlansHeader extends StatelessWidget {
  const _BrowsePlansHeader({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 0.5,
                color: isDark
                    ? AppColors.borderSubtle
                    : AppColors.borderSubtleLight,
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppDimensions.spacingMd,
              ),
              child: GestureDetector(
                onTap: onTap,
                child: Text(
                  title,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 0.5,
                color: isDark
                    ? AppColors.borderSubtle
                    : AppColors.borderSubtleLight,
              ),
            ),
          ],
        ),
        const Gap(AppDimensions.spacingMd),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _PlanStatusShimmer extends StatelessWidget {
  const _PlanStatusShimmer();

  @override
  Widget build(BuildContext context) {
    return const Skeletonizer(
      child: PlanStatusCard(tier: AppTier.pro),
    );
  }
}

class _CompareShimmer extends StatelessWidget {
  const _CompareShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bar = Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface3 : AppColors.surface2Light,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
    );

    return Skeletonizer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 22,
            width: 160,
            color: isDark ? AppColors.surface4 : AppColors.surface3Light,
          ),
          const Gap(AppDimensions.spacingSm),
          Container(
            height: 14,
            width: 220,
            color: isDark ? AppColors.surface3 : AppColors.surface2Light,
          ),
          const Gap(AppDimensions.spacingMd),
          bar,
          bar,
          bar,
        ],
      ),
    );
  }
}
