import 'dart:async';
import 'dart:io';

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/demo_store_seeder.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/whatsapp_util.dart';
import 'package:daftar/domain/constants/built_in_currencies.dart';
import 'package:daftar/domain/entities/currency.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/enums/workspace_permission.dart';
import 'package:daftar/presentation/providers/app_lock_provider.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/entitlement_providers.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/providers/locale_provider.dart' hide Locale;
import 'package:daftar/presentation/providers/merchant_profile_providers.dart';
import 'package:daftar/presentation/providers/permissions_providers.dart';
import 'package:daftar/presentation/providers/settings_preferences_provider.dart';
import 'package:daftar/presentation/providers/sync_providers.dart';
import 'package:daftar/presentation/providers/theme_provider.dart' hide Theme;
import 'package:daftar/presentation/providers/transaction_providers.dart';
import 'package:daftar/presentation/providers/workspace_limit_providers.dart';
import 'package:daftar/presentation/screens/settings/widgets/bento_atoms.dart';
import 'package:daftar/presentation/screens/settings/widgets/bento_block.dart';
import 'package:daftar/presentation/screens/settings/widgets/glow_pill_toggle.dart';
import 'package:daftar/presentation/screens/settings/widgets/hero_bento_card.dart';
import 'package:daftar/presentation/screens/settings/widgets/pin_entry_sheet.dart';
import 'package:daftar/presentation/screens/settings/widgets/pro_micro_badge.dart';
import 'package:daftar/presentation/screens/settings/widgets/settings_about_sheet.dart';
import 'package:daftar/presentation/screens/settings/widgets/settings_ambient_mesh.dart';
import 'package:daftar/presentation/screens/settings/widgets/settings_section.dart';
import 'package:daftar/presentation/screens/settings/widgets/settings_tile.dart';
import 'package:daftar/presentation/screens/settings/widgets/settings_vault_pulse_card.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/currency_symbol_mark.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_close_icon_button.dart';
import 'package:daftar/presentation/shared/widgets/demo_seed_report_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

const List<Currency> _builtInCurrencies = BuiltInCurrencies.all;

/// Khazna v3 settings dashboard — bento grid layout.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scheduleDriveListIfLinked(),
    );
  }

  void _scheduleDriveListIfLinked() {
    if (!mounted) {
      return;
    }
    final session = ref.read(authStateProvider).asData?.value;
    if (session == AuthSessionState.linked) {
      ref.read(driveBackupProvider.notifier).scheduleRemoteListLoad();
    }
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if ((offset - _scrollOffset).abs() > 2) {
      setState(() => _scrollOffset = offset);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final isLoading = settingsAsync.isLoading;
    final settings = settingsAsync.asData?.value;
    final authAsync = ref.watch(authStateProvider);
    final accountAsync = ref.watch(googleAccountProvider);
    final lockState = ref.watch(appLockManagerProvider);
    final backupState = ref.watch(backupProvider);
    final driveState = ref.watch(driveBackupProvider);
    final showTeamManagement =
        ref.watch(isMultiDeviceSyncUnlockedProvider).value == true &&
        ref
                .watch(canPerformProvider(WorkspacePermission.inviteWorkers))
                .value ==
            true &&
        ref.watch(canUseFeatureProvider(FeatureFlag.multiDeviceSync)).value ==
            true;
    final showSyncReport =
        ref.watch(isMultiDeviceSyncUnlockedProvider).value == true;
    // Contest quarantine: hide join-workspace when Stage 8 kill-switch is on
    // (avoids redirect loop). When kill-switch is off, invitees can still join
    // without Pro+ unlock.
    const showJoinWorkspace = !AppConstants.kContestDisableMultiDeviceSync;

    ref
      ..listen(authStateProvider, (prev, next) {
        final prevSession = prev?.asData?.value;
        final nextSession = next.asData?.value;
        if (nextSession == AuthSessionState.linked &&
            prevSession != AuthSessionState.linked) {
          ref.read(driveBackupProvider.notifier).scheduleRemoteListLoad();
          return;
        }
        if (prevSession == AuthSessionState.linked &&
            nextSession != AuthSessionState.linked) {
          ref.invalidate(driveBackupProvider);
        }
      })
      ..listen(googleAccountProvider, (prev, next) {
        final prevId = prev?.asData?.value?.id;
        final nextId = next.asData?.value?.id;
        if (nextId != null &&
            prevId != null &&
            nextId != prevId &&
            ref.read(authStateProvider).asData?.value ==
                AuthSessionState.linked) {
          unawaited(
            ref.read(driveBackupProvider.notifier).refreshRemoteList(),
          );
        }
      });

    final currencyCode =
        settings?.defaultCurrency ?? DbConstants.defaultCurrency;
    final multiCurrencyEnabled = settings?.isMultiCurrencyEnabled ?? false;
    final swipeToDeleteEnabled = settings?.isSwipeToDeleteEnabled ?? false;
    final ttsMuted = settings?.ttsMuted ?? false;
    final demoArchitectureHud = settings?.demoArchitectureHud ?? false;
    final calleAllowDial = ref.watch(calleDevicePolicyProvider).allowDial;

    final session = authAsync.asData?.value;
    final accountSubtitle = _resolveAccountSubtitle(
      l10n: l10n,
      session: session,
      profileEmail: accountAsync.asData?.value?.email,
      settingsEmail: settings?.googleAccountEmail,
    );

    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    final lastBackup = backupState.backups.isNotEmpty
        ? backupState.backups.first
        : null;
    final hasBackup = backupState.backups.isNotEmpty;
    final isSignedIn = session == AuthSessionState.linked;
    final driveFileId = lastBackup?.googleDriveFileId;
    final hasLocalDriveLink = driveFileId != null && driveFileId.isNotEmpty;
    final hasCloudBackup =
        hasLocalDriveLink ||
        (isSignedIn && driveState.remoteBackups.isNotEmpty);
    final isCloudSynced = hasBackup && hasCloudBackup;
    final bothSafe = hasBackup && isCloudSynced;
    final localProgress = hasBackup ? 1.0 : 0.0;
    final cloudProgress = isCloudSynced ? 1.0 : (isSignedIn ? 0.5 : 0.0);
    final localColor = hasBackup ? AppColors.payment : AppColors.warning;
    final cloudColor = isCloudSynced
        ? AppColors.payment
        : (isSignedIn ? AppColors.warning : inkMuted);
    final backupRingLabel = bothSafe ? '✓' : (hasBackup ? '◐' : '!');
    final backupRingColor = bothSafe ? AppColors.payment : AppColors.warning;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: SettingsAmbientMesh(scrollOffset: _scrollOffset),
          ),
          SafeArea(
            child: Skeletonizer(
              enabled: isLoading,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppDimensions.spacingLg,
                      AppDimensions.spacingMd,
                      AppDimensions.spacingLg,
                      AppDimensions.spacing3xl,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── Title ──
                        FadeSlideTransition(
                          beginOffset: const Offset(0, 0.04),
                          duration: AppDimensions.animationSlow,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: AppDimensions.spacingXs,
                              bottom: AppDimensions.spacingLg,
                            ),
                            child: Text(
                              l10n.settings,
                              style: AppTextStyles.displaySmall.copyWith(
                                color: inkPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ),

                        // ── Vault pulse ──
                        FadeSlideTransition(
                          delay: const Duration(milliseconds: 40),
                          duration: AppDimensions.animationSlow,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SettingsSectionLabel(
                                label: l10n.settingsGroupVault,
                              ),
                              const Gap(AppDimensions.spacingSm),
                              SettingsVaultPulseCard(
                                hasBackup: hasBackup,
                                bothSafe: bothSafe,
                                localProgress: localProgress,
                                cloudProgress: cloudProgress,
                                localColor: localColor,
                                cloudColor: cloudColor,
                                centerLabel: backupRingLabel,
                                centerColor: backupRingColor,
                                onTap: () =>
                                    context.pushNamed(RouteNames.backup),
                                onCreateBackup: () =>
                                    context.pushNamed(RouteNames.backup),
                              ),
                            ],
                          ),
                        ),
                        const Gap(AppDimensions.spacingLg),

                        // ── Zone 4: Preferences hero card ──
                        FadeSlideTransition(
                          delay: const Duration(milliseconds: 120),
                          duration: AppDimensions.animationSlow,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SettingsSectionLabel(
                                label: l10n.settingsGroupPreferences,
                              ),
                              const Gap(AppDimensions.spacingSm),
                              HeroBentoCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _ThemeSegmentRow(
                                      l10n: l10n,
                                      themeMode: themeMode,
                                      isDark: isDark,
                                      inkMuted: inkMuted,
                                      onThemeChanged: (mode) {
                                        unawaited(HapticService.light());
                                        ref
                                            .read(themeProvider.notifier)
                                            .setThemeMode(mode);
                                      },
                                    ),
                                    const Gap(AppDimensions.spacingLg),
                                    _SecurityToggleRow(
                                      l10n: l10n,
                                      lockState: lockState,
                                      inkSecondary: inkSecondary,
                                      onLockChanged: (enabled) =>
                                          _toggleAppLock(context, enabled),
                                      onBiometricChanged: (enabled) =>
                                          _toggleBiometric(context, enabled),
                                      onAdvancedTap: () => context.pushNamed(
                                        RouteNames.security,
                                      ),
                                    ),
                                    const Gap(AppDimensions.spacingLg),
                                    GlowPillToggle(
                                      icon: Icons.currency_exchange_rounded,
                                      label: l10n.settingsMultiCurrency,
                                      sublabel:
                                          l10n.settingsMultiCurrencySubtitle,
                                      value: multiCurrencyEnabled,
                                      onChanged: (enabled) =>
                                          _setMultiCurrency(context, enabled),
                                    ),
                                    const Gap(AppDimensions.spacingLg),
                                    GlowPillToggle(
                                      icon: Icons.swipe_rounded,
                                      label: l10n.settingsSwipeToDelete,
                                      sublabel:
                                          l10n.settingsSwipeToDeleteSubtitle,
                                      value: swipeToDeleteEnabled,
                                      onChanged: (enabled) =>
                                          _setSwipeToDelete(context, enabled),
                                    ),
                                    const Gap(AppDimensions.spacingLg),
                                    GlowPillToggle(
                                      icon: Icons.volume_off_rounded,
                                      label: l10n.settingsTtsMuted,
                                      sublabel: l10n.settingsTtsMutedSubtitle,
                                      value: ttsMuted,
                                      onChanged: (muted) =>
                                          _setTtsMuted(context, muted),
                                    ),
                                    const Gap(AppDimensions.spacingLg),
                                    GlowPillToggle(
                                      icon: Icons.account_tree_rounded,
                                      label: l10n.settingsDemoArchitectureHud,
                                      sublabel:
                                          l10n.settingsDemoArchitectureHudSubtitle,
                                      value: demoArchitectureHud,
                                      onChanged: (enabled) =>
                                          _setDemoArchitectureHud(
                                            context,
                                            enabled,
                                          ),
                                    ),
                                    const Gap(AppDimensions.spacingLg),
                                    GlowPillToggle(
                                      icon: Icons.phone_in_talk_outlined,
                                      label: l10n.settingsCalleAllowDial,
                                      sublabel: l10n.settingsCalleAllowDialSubtitle,
                                      value: calleAllowDial,
                                      enabled: false,
                                      onChanged: (_) {},
                                      onDisabledTap: () =>
                                          _showCalleAllowDialStubHint(context),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Gap(AppDimensions.spacingLg),

                        // ── Zone 5: Locale row ──
                        FadeSlideTransition(
                          delay: const Duration(milliseconds: 160),
                          duration: AppDimensions.animationSlow,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: BentoBlock(
                                  padding: const EdgeInsetsDirectional.all(
                                    AppDimensions.spacingMd,
                                  ),
                                  onTap: () => _showLanguagePicker(
                                    context,
                                    locale,
                                  ),
                                  child: SettingsCompactNavCell(
                                    icon: Icons.language_rounded,
                                    label: l10n.settingsSelectLanguage,
                                    value: locale.languageCode == 'ar'
                                        ? l10n.arabic
                                        : l10n.english,
                                  ),
                                ),
                              ),
                              const Gap(AppDimensions.spacingMd),
                              Expanded(
                                child: BentoBlock(
                                  padding: const EdgeInsetsDirectional.all(
                                    AppDimensions.spacingMd,
                                  ),
                                  onTap: () => _showCurrencyPicker(
                                    context,
                                    currencyCode,
                                  ),
                                  child: SettingsCompactNavCell(
                                    icon: Icons.payments_outlined,
                                    label: l10n.settingsDefaultCurrency,
                                    value: _currencyLabel(
                                      context,
                                      currencyCode,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Gap(AppDimensions.spacingLg),

                        // ── Zone 6: Workspace dock ──
                        FadeSlideTransition(
                          delay: const Duration(milliseconds: 200),
                          duration: AppDimensions.animationSlow,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SettingsSectionLabel(
                                label: l10n.settingsGroupWorkspace,
                              ),
                              const Gap(AppDimensions.spacingSm),
                              BentoBlock(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    UtilityDockItem(
                                      icon: Icons.upload_file_rounded,
                                      label: l10n.csvImportTitle,
                                      onTap: () async {
                                        final ledgerId = ref.read(
                                          selectedLedgerIdProvider,
                                        );
                                        final trimmed = ledgerId?.trim();
                                        await context.pushNamed(
                                          RouteNames.importCsv,
                                          queryParameters:
                                              trimmed != null &&
                                                  trimmed.isNotEmpty
                                              ? {
                                                  RouteNames.ledgerIdParam:
                                                      trimmed,
                                                }
                                              : const {},
                                        );
                                      },
                                    ),
                                    const SettingsBentoDivider(),
                                    UtilityDockItem(
                                      icon: Icons.storefront_outlined,
                                      label: l10n.settingsMerchantBranding,
                                      sublabel:
                                          l10n.settingsMerchantBrandingSubtitle,
                                      trailingWidget: const ProMicroBadge(),
                                      onTap: () => context.pushNamed(
                                        RouteNames.merchantBranding,
                                      ),
                                    ),
                                    const SettingsBentoDivider(),
                                    UtilityDockItem(
                                      icon: Icons.workspace_premium_outlined,
                                      label: l10n.settingsPremium,
                                      sublabel: l10n.settingsPremiumSubtitle,
                                      onTap: () => context.pushNamed(
                                        RouteNames.activation,
                                      ),
                                    ),
                                    if (showSyncReport) ...[
                                      const SettingsBentoDivider(),
                                      UtilityDockItem(
                                        icon: Icons.sync_outlined,
                                        label: l10n.settingsSyncReport,
                                        sublabel:
                                            l10n.settingsSyncReportSubtitle,
                                        trailingWidget: const ProMicroBadge(),
                                        onTap: () => context.pushNamed(
                                          RouteNames.syncReport,
                                        ),
                                      ),
                                    ],
                                    if (showTeamManagement) ...[
                                      const SettingsBentoDivider(),
                                      UtilityDockItem(
                                        icon: Icons.groups_outlined,
                                        label: l10n.settingsTeam,
                                        sublabel: l10n.settingsTeamSubtitle,
                                        trailingWidget: const ProMicroBadge(),
                                        onTap: () => context.pushNamed(
                                          RouteNames.memberManagement,
                                        ),
                                      ),
                                    ],
                                    if (showJoinWorkspace) ...[
                                      const SettingsBentoDivider(),
                                      UtilityDockItem(
                                        icon: Icons.vpn_key_outlined,
                                        label: l10n.settingsJoinWorkspace,
                                        sublabel:
                                            l10n.settingsJoinWorkspaceSubtitle,
                                        onTap: () => context.pushNamed(
                                          RouteNames.joinWorkspace,
                                        ),
                                      ),
                                    ],
                                    const SettingsBentoDivider(),
                                    UtilityDockItem(
                                      icon: Icons.account_circle_outlined,
                                      label: l10n.settingsGoogleAccount,
                                      sublabel: accountSubtitle,
                                      onTap: () => context.pushNamed(
                                        RouteNames.accountManagement,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Gap(AppDimensions.spacingLg),

                        // ── Zone 7: Support & privacy ──
                        FadeSlideTransition(
                          delay: const Duration(milliseconds: 240),
                          duration: AppDimensions.animationSlow,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SettingsSectionLabel(
                                label: l10n.settingsGroupSupport,
                              ),
                              const Gap(AppDimensions.spacingSm),
                              BentoBlock(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    UtilityDockItem(
                                      icon: Icons.star_outline_rounded,
                                      label: l10n.settingsRateApp,
                                      onTap: () => _rateApp(context),
                                    ),
                                    const SettingsBentoDivider(),
                                    UtilityDockItem(
                                      icon: Icons.support_agent_outlined,
                                      label: l10n.settingsContactSupport,
                                      onTap: () => _contactSupport(context),
                                    ),
                                    const SettingsBentoDivider(),
                                    UtilityDockItem(
                                      icon: Icons.info_outline_rounded,
                                      label: l10n.settingsAbout,
                                      trailingWidget: Text(
                                        l10n.settingsVersionLabel(
                                          AppConstants.appVersionLabel,
                                        ),
                                        style: AppTextStyles.amountMicro
                                            .copyWith(color: inkMuted),
                                      ),
                                      onTap: () => unawaited(
                                        showSettingsAboutSheet(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Gap(AppDimensions.spacingLg),

                        // ── Zone 8: Sample store (release-visible) ──
                        FadeSlideTransition(
                          delay: const Duration(milliseconds: 260),
                          duration: AppDimensions.animationSlow,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SettingsSectionLabel(
                                label: l10n.settingsSampleStoreSection,
                              ),
                              const Gap(AppDimensions.spacingSm),
                              const _SampleStoreSection(),
                            ],
                          ),
                        ),

                        if (kDebugMode) ...[
                          const Gap(AppDimensions.spacingXxl),
                          const _DevModeSection(),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Interaction Handlers ─────────────────────────────────────────────────

  /// Resolves the Google account tile subtitle from Auth V2 session + identity.
  static String _resolveAccountSubtitle({
    required AppLocalizations l10n,
    required AuthSessionState? session,
    required String? profileEmail,
    required String? settingsEmail,
  }) {
    if (session == AuthSessionState.linked) {
      if (profileEmail != null && profileEmail.isNotEmpty) {
        return profileEmail;
      }
      if (settingsEmail != null && settingsEmail.isNotEmpty) {
        return settingsEmail;
      }
      return l10n.accountManagementStatusConnectedSubtitle;
    }

    if (session == AuthSessionState.migrationRelinkRequired ||
        session == AuthSessionState.needsReauth) {
      if (settingsEmail != null && settingsEmail.isNotEmpty) {
        return settingsEmail;
      }
      if (session == AuthSessionState.needsReauth) {
        return l10n.accountManagementNeedsReauthTitle;
      }
      return l10n.accountManagementMigrationRelinkTitle;
    }

    return l10n.settingsGoogleAccountSignInPrompt;
  }

  String _currencyLabel(BuildContext context, String code) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    for (final currency in _builtInCurrencies) {
      if (currency.code == code) {
        return isArabic ? currency.nameAr : currency.nameEn;
      }
    }
    return code;
  }

  Future<void> _showLanguagePicker(
    BuildContext context,
    Locale current,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await AppBottomSheet.show<Locale>(
      context,
      title: l10n.settingsSelectLanguage,
      trailing: DaftarCloseIconButton(
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      scrollable: false,
      child: _OptionList<Locale>(
        options: const [Locale('ar'), Locale('en')],
        selected: current,
        labelBuilder: (locale) =>
            locale.languageCode == 'ar' ? l10n.arabic : l10n.english,
      ),
    );
    if (selected != null) {
      ref.read(localeProvider.notifier).setLocale(selected);
    }
  }

  Future<void> _showCurrencyPicker(
    BuildContext context,
    String currentCode,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final selectedCurrency = _builtInCurrencies.firstWhere(
      (c) => c.code == currentCode,
      orElse: () => _builtInCurrencies.first,
    );
    final selected = await AppBottomSheet.show<Currency>(
      context,
      title: l10n.settingsSelectCurrency,
      trailing: DaftarCloseIconButton(
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      scrollable: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final currency in _builtInCurrencies)
            SettingsTile(
              icon: currency.code == selectedCurrency.code
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              title: isArabic ? currency.nameAr : currency.nameEn,
              showChevron: false,
              trailing: CurrencySymbolMark(
                currencyCode: currency.code,
                symbol: currency.symbol,
                color: inkPrimary,
                height: 18,
              ),
              onTap: () => Navigator.of(context).pop(currency),
            ),
        ],
      ),
    );
    if (selected == null) return;
    final ok = await ref
        .read(settingsPreferencesProvider.notifier)
        .setDefaultCurrency(selected.code);
    if (!context.mounted) return;
    if (!ok) {
      unawaited(
        AppBottomSheet.showError(
          context,
          error: l10n.settingsSaveFailed,
        ),
      );
    }
  }

  Future<void> _toggleAppLock(BuildContext context, bool enabled) async {
    final l10n = AppLocalizations.of(context)!;
    final manager = ref.read(appLockManagerProvider.notifier);

    if (enabled) {
      await showPinEntrySheet(
        context,
        mode: PinSheetMode.create,
      );
      return;
    }

    final lockState = ref.read(appLockManagerProvider);
    if (!lockState.isAppLockEnabled) return;

    final hasPin = await ref.read(securityServiceProvider).hasPinConfigured();
    if (!context.mounted) return;

    if (!hasPin) {
      final ok = await manager.removePinAndDisableLock();
      if (!ok && context.mounted) {
        unawaited(
          AppBottomSheet.showError(
            context,
            error: l10n.settingsSaveFailed,
          ),
        );
      }
      return;
    }

    await showPinEntrySheet(
      context,
      mode: PinSheetMode.disableVerify,
    );
  }

  Future<void> _toggleBiometric(BuildContext context, bool enabled) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = enabled
        ? await ref
              .read(appLockManagerProvider.notifier)
              .enableBiometricWithSystemAuth()
        : await ref
              .read(appLockManagerProvider.notifier)
              .setBiometricEnabled(enabled: false);
    if (!context.mounted) return;
    if (!ok) {
      unawaited(
        AppBottomSheet.showError(
          context,
          error: l10n.settingsSaveFailed,
        ),
      );
    }
  }

  Future<void> _setMultiCurrency(BuildContext context, bool enabled) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await ref
        .read(settingsPreferencesProvider.notifier)
        .setMultiCurrencyEnabled(enabled: enabled);
    if (!context.mounted) return;
    if (!ok) {
      unawaited(
        AppBottomSheet.showError(
          context,
          error: l10n.settingsSaveFailed,
        ),
      );
    }
  }

  Future<void> _setSwipeToDelete(BuildContext context, bool enabled) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await ref
        .read(settingsPreferencesProvider.notifier)
        .setSwipeToDeleteEnabled(enabled: enabled);
    if (!context.mounted) return;
    if (!ok) {
      unawaited(
        AppBottomSheet.showError(
          context,
          error: l10n.settingsSaveFailed,
        ),
      );
    }
  }

  Future<void> _setTtsMuted(BuildContext context, bool muted) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await ref
        .read(settingsPreferencesProvider.notifier)
        .setTtsMuted(muted: muted);
    if (!context.mounted) return;
    if (!ok) {
      unawaited(
        AppBottomSheet.showError(
          context,
          error: l10n.settingsSaveFailed,
        ),
      );
    }
  }

  void _showCalleAllowDialStubHint(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.settingsCalleAllowDialStubHint),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.surface4 : AppColors.surface2Light,
      ),
    );
  }

  Future<void> _setDemoArchitectureHud(
    BuildContext context,
    bool enabled,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await ref
        .read(settingsPreferencesProvider.notifier)
        .setDemoArchitectureHud(enabled: enabled);
    if (!context.mounted) return;
    if (!ok) {
      unawaited(
        AppBottomSheet.showError(
          context,
          error: l10n.settingsSaveFailed,
        ),
      );
    }
  }

  Future<void> _rateApp(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final url = Platform.isIOS
        ? AppConstants.appStoreListingUrl
        : AppConstants.playStoreListingUrl;
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!launched) {
      unawaited(
        AppBottomSheet.showError(
          context,
          error: l10n.settingsStoreLaunchError,
        ),
      );
    }
  }

  Future<void> _contactSupport(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final launched = await WhatsAppUtil.tryLaunchNativeWhatsAppSendInOrder(
      AppConstants.supportWhatsAppPhone,
    );
    if (!context.mounted) return;
    if (!launched) {
      unawaited(
        AppBottomSheet.showError(
          context,
          error: l10n.whatsappLaunchError,
        ),
      );
    }
  }
}

// ── Preference sub-widgets ───────────────────────────────────────────────────

class _ThemeSegmentRow extends StatelessWidget {
  const _ThemeSegmentRow({
    required this.l10n,
    required this.themeMode,
    required this.isDark,
    required this.inkMuted,
    required this.onThemeChanged,
  });

  final AppLocalizations l10n;
  final ThemeMode themeMode;
  final bool isDark;
  final Color inkMuted;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.contrast_rounded,
              size: AppDimensions.iconSmall,
              color: inkMuted,
            ),
            const Gap(AppDimensions.spacingSm),
            Text(
              l10n.settingsSelectTheme,
              style: AppTextStyles.labelSmall.copyWith(
                color: inkMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const Gap(AppDimensions.spacingSm),
        Container(
          padding: const EdgeInsetsDirectional.all(3),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : AppColors.surface2Light,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppColors.borderSubtleLight,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              ThemeSegmentPill(
                label: l10n.lightMode,
                icon: Icons.light_mode_rounded,
                isActive: themeMode == ThemeMode.light,
                onTap: () => onThemeChanged(ThemeMode.light),
              ),
              ThemeSegmentPill(
                label: l10n.settingsSystemTheme,
                icon: Icons.phone_android_rounded,
                isActive: themeMode == ThemeMode.system,
                onTap: () => onThemeChanged(ThemeMode.system),
              ),
              ThemeSegmentPill(
                label: l10n.darkMode,
                icon: Icons.dark_mode_rounded,
                isActive: themeMode == ThemeMode.dark,
                onTap: () => onThemeChanged(ThemeMode.dark),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _showBiometricRequiresAppLock(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.securityBiometricRequiresAppLock),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? AppColors.surface4 : AppColors.surface2Light,
    ),
  );
}

class _SecurityToggleRow extends StatelessWidget {
  const _SecurityToggleRow({
    required this.l10n,
    required this.lockState,
    required this.inkSecondary,
    required this.onLockChanged,
    required this.onBiometricChanged,
    required this.onAdvancedTap,
  });

  final AppLocalizations l10n;
  final AppLockState lockState;
  final Color inkSecondary;
  final ValueChanged<bool> onLockChanged;
  final ValueChanged<bool> onBiometricChanged;
  final VoidCallback onAdvancedTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: GlowPillToggle(
                icon: Icons.lock_outline_rounded,
                label: l10n.securityTitle,
                value: lockState.isAppLockEnabled,
                iconOnly: true,
                onChanged: onLockChanged,
              ),
            ),
            const Gap(AppDimensions.spacingLg),
            Expanded(
              child: GlowPillToggle(
                icon: Icons.fingerprint_rounded,
                label: l10n.securityBiometricTitle,
                value:
                    lockState.isBiometricEnabled && lockState.isAppLockEnabled,
                iconOnly: true,
                enabled: lockState.isAppLockEnabled,
                onDisabledTap: () => _showBiometricRequiresAppLock(context),
                onChanged: onBiometricChanged,
              ),
            ),
          ],
        ),
        const Gap(AppDimensions.spacingSm),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: GestureDetector(
            onTap: () {
              unawaited(HapticService.light());
              onAdvancedTap();
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppDimensions.spacingXxs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.settingsSecurityAdvanced,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: inkSecondary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: inkSecondary.withValues(alpha: 0.45),
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 16,
                    color: inkSecondary.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionList<T> extends StatelessWidget {
  const _OptionList({
    required this.options,
    required this.selected,
    required this.labelBuilder,
  });

  final List<T> options;
  final T selected;
  final String Function(T option) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in options)
          SettingsTile(
            icon: option == selected
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            title: labelBuilder(option),
            showChevron: false,
            onTap: () => Navigator.of(context).pop(option),
          ),
      ],
    );
  }
}

class _SampleStoreSection extends ConsumerStatefulWidget {
  const _SampleStoreSection();

  @override
  ConsumerState<_SampleStoreSection> createState() =>
      _SampleStoreSectionState();
}

class _SampleStoreSectionState extends ConsumerState<_SampleStoreSection> {
  bool _isBusy = false;

  Future<void> _refreshAfterSeed() {
    ref
      ..invalidate(appSettingsProvider)
      ..invalidate(merchantProfileProvider)
      ..invalidate(ledgersProvider)
      ..invalidate(contactsProvider)
      ..invalidate(contactSummariesByLedgerProvider)
      ..invalidate(contactCountProvider)
      ..invalidate(totalActiveLedgerCountProvider)
      ..invalidate(totalActiveContactCountProvider)
      ..invalidate(totalActiveTransactionCountProvider)
      ..invalidate(paginatedTransactionsProvider)
      ..invalidate(transactionCountProvider)
      ..read(selectedLedgerIdProvider.notifier).clear();
    return Future<void>.value();
  }

  Future<void> _onResetSampleStore() async {
    if (_isBusy) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.settingsSampleStoreResetConfirmTitle),
          content: Text(l10n.settingsSampleStoreResetConfirmBody),
          actions: [
            DaftarButton(
              label: l10n.settingsSampleStoreResetCancel,
              variant: DaftarButtonVariant.tertiary,
              size: DaftarButtonSize.small,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            DaftarButton(
              label: l10n.settingsSampleStoreResetConfirm,
              size: DaftarButtonSize.small,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      final database = ref.read(appDatabaseProvider);
      final localeCode = ref.read(localeProvider).languageCode;
      final report = await DemoStoreSeeder.seedData(
        database,
        localeOverride: localeCode,
      );
      await _refreshAfterSeed();
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      unawaited(HapticService.success());
      await showDemoSeedReportDialog(context, report);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _isBusy = false);
        unawaited(AppBottomSheet.showError(context, error: error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return BentoBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.settingsSampleStoreBody,
            style: AppTextStyles.bodySmall.copyWith(color: inkMuted),
          ),
          const Gap(AppDimensions.spacingLg),
          DaftarButton(
            label: l10n.settingsSampleStoreReset,
            variant: DaftarButtonVariant.secondary,
            icon: Icons.auto_stories_outlined,
            isLoading: _isBusy,
            isExpanded: true,
            onPressed: _isBusy
                ? null
                : () => unawaited(_onResetSampleStore()),
          ),
          const Gap(AppDimensions.spacingXs),
          Text(
            l10n.settingsSampleStoreFootnote,
            style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
          ),
        ],
      ),
    );
  }
}

class _DevModeSection extends ConsumerStatefulWidget {
  const _DevModeSection();

  @override
  ConsumerState<_DevModeSection> createState() => _DevModeSectionState();
}

class _DevModeSectionState extends ConsumerState<_DevModeSection> {
  bool _isBusy = false;

  Future<void> _runDevAction(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
      _refreshDevProviders();
    } on Object catch (error) {
      if (mounted) {
        unawaited(AppBottomSheet.showError(context, error: error));
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _refreshDevProviders() {
    ref
      ..invalidate(entitlementProvider)
      ..invalidate(appSettingsProvider)
      ..invalidate(localeProvider)
      ..invalidate(merchantProfileProvider)
      ..invalidate(ledgersProvider)
      ..invalidate(contactsProvider)
      ..invalidate(contactSummariesByLedgerProvider)
      ..invalidate(contactCountProvider)
      ..invalidate(totalActiveLedgerCountProvider)
      ..invalidate(totalActiveContactCountProvider)
      ..invalidate(totalActiveTransactionCountProvider)
      ..invalidate(paginatedTransactionsProvider)
      ..invalidate(transactionCountProvider)
      ..read(selectedLedgerIdProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final database = ref.read(appDatabaseProvider);

    return BentoBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Developer Tools',
            style: AppTextStyles.labelMedium.copyWith(
              color: isDark
                  ? AppColors.inkSecondary
                  : AppColors.inkSecondaryLight,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const Gap(AppDimensions.spacingXs),
          Text(
            'Debug builds only. Seeds the contest closing-day workspace '
            '(Arabic, YER, overdue mix).',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
            ),
          ),
          const Gap(AppDimensions.spacingLg),
          DaftarButton(
            label: 'DEV: Seed Mock Data',
            isLoading: _isBusy,
            onPressed: _isBusy
                ? null
                : () => unawaited(
                    _runDevAction(() async {
                      final report = await DemoStoreSeeder.seedData(database);
                      if (context.mounted) {
                        await showDemoSeedReportDialog(context, report);
                      }
                    }),
                  ),
          ),
          const Gap(AppDimensions.spacingMd),
          DaftarButton(
            label: 'DEV: Seed 1000 Perf Transactions',
            isLoading: _isBusy,
            onPressed: _isBusy
                ? null
                : () => unawaited(
                    _runDevAction(() async {
                      final result =
                          await DemoStoreSeeder.seedPerformanceTransactions(
                            database,
                          );
                      if (!context.mounted) {
                        return;
                      }
                      if (result == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No active contact found. Seed mock data first.',
                            ),
                          ),
                        );
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Seeded ${result.count} transactions for '
                            '${result.contactName}',
                          ),
                        ),
                      );
                    }),
                  ),
          ),
          const Gap(AppDimensions.spacingMd),
          DaftarButton(
            label: 'DEV: Clear Database',
            variant: DaftarButtonVariant.destructiveOutlined,
            isLoading: _isBusy,
            onPressed: _isBusy
                ? null
                : () => unawaited(
                    _runDevAction(
                      () => DemoStoreSeeder.clearData(database),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
