import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/providers/app_lock_provider.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/screens/settings/security/lock_timeout_option.dart';
import 'package:daftar/presentation/screens/settings/security/widgets/security_ambient_backdrop.dart';
import 'package:daftar/presentation/screens/settings/security/widgets/security_timeout_selector.dart';
import 'package:daftar/presentation/screens/settings/security/widgets/security_vault_hero.dart';
import 'package:daftar/presentation/screens/settings/widgets/pin_entry_sheet.dart';
import 'package:daftar/presentation/screens/settings/widgets/settings_group.dart';
import 'package:daftar/presentation/screens/settings/widgets/settings_tile.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_scroll_screen_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:skeletonizer/skeletonizer.dart';

export 'package:daftar/presentation/screens/settings/security/lock_timeout_option.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _hasPin = false;
  bool _loadingPinState = true;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPinState());
  }

  Future<void> _refreshPinState() async {
    final hasPin = await ref.read(securityServiceProvider).hasPinConfigured();
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _loadingPinState = false;
    });
  }

  Future<void> _onAppLockToggled(bool enabled) async {
    await HapticService.toggleFlipped();
    final manager = ref.read(appLockManagerProvider.notifier);

    if (enabled) {
      if (!mounted) return;
      final created = await showPinEntrySheet(
        context,
        mode: PinSheetMode.create,
      );
      if (created) {
        await _refreshPinState();
      }
      return;
    }

    if (!_hasPin) {
      final ok = await manager.removePinAndDisableLock();
      if (!ok && mounted) {
        _showError();
      }
      await _refreshPinState();
      return;
    }

    if (!mounted) return;
    final verified = await showPinEntrySheet(
      context,
      mode: PinSheetMode.disableVerify,
    );
    if (verified) {
      await _refreshPinState();
    }
  }

  Future<void> _onBiometricToggled(bool enabled) async {
    await HapticService.toggleFlipped();
    final manager = ref.read(appLockManagerProvider.notifier);

    if (enabled) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final ok = await manager.enableBiometricWithSystemAuth(
        localizedReason: l10n.securityBiometricEnrollReason,
      );
      if (!ok && mounted) {
        _showError();
      }
      return;
    }

    final ok = await manager.setBiometricEnabled(enabled: false);
    if (!ok && mounted) {
      _showError();
    }
  }

  Future<void> _onTimeoutChanged(int seconds) async {
    await HapticService.selection();
    final ok = await ref
        .read(appLockManagerProvider.notifier)
        .setLockTimeoutSeconds(seconds);
    if (!ok && mounted) {
      _showError();
    }
  }

  void _showError() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.securitySettingsError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _timeoutLabel(AppLocalizations l10n, int seconds) {
    return switch (seconds) {
      LockTimeoutOption.immediately => l10n.securityTimeoutImmediate,
      LockTimeoutOption.oneMinute => l10n.securityTimeoutOneMinute,
      LockTimeoutOption.fiveMinutes => l10n.securityTimeoutFiveMinutes,
      LockTimeoutOption.fifteenMinutes => l10n.securityTimeoutFifteenMinutes,
      _ => l10n.securityTimeoutOneMinute,
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSettingsProvider, (_, _) {
      unawaited(_refreshPinState());
    });

    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final surfaceColor =
        isDark ? AppColors.surface0 : AppColors.surface0Light;

    final lockState = ref.watch(appLockManagerProvider);
    final biometricAsync = ref.watch(biometricHardwareAvailableProvider);
    final appLockOn = lockState.isAppLockEnabled;
    final biometricsAvailable = biometricAsync.asData?.value ?? false;
    final showBiometric =
        appLockOn && _hasPin && biometricsAvailable && !_loadingPinState;
    final showChangePin = appLockOn && _hasPin && !_loadingPinState;
    final selectedTimeout = LockTimeoutOption.values.contains(
      lockState.lockTimeoutSeconds,
    )
        ? lockState.lockTimeoutSeconds
        : LockTimeoutOption.oneMinute;

    final timeoutSummary = appLockOn
        ? '${l10n.securityTimeoutTitle}: ${_timeoutLabel(l10n, selectedTimeout)}'
        : '';

    final bottomClearance = MediaQuery.paddingOf(context).bottom + 48;

    return Scaffold(
      backgroundColor: surfaceColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SecurityAmbientBackdrop(
            isDark: isDark,
            surfaceColor: surfaceColor,
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              DaftarScrollScreenTitleSliver(
                title: Text(
                  l10n.securityTitle,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: inkPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.securitySubtitle,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: isDark
                              ? AppColors.inkSecondary
                              : AppColors.inkSecondaryLight,
                        ),
                      ),
                      const Gap(AppDimensions.spacing3xl),
                      Skeletonizer(
                        enabled: _loadingPinState,
                        child: SecurityVaultHero(
                          isAppLockEnabled: appLockOn,
                          hasPin: _hasPin,
                          isBiometricEnabled: lockState.isBiometricEnabled,
                          biometricsAvailable: biometricsAvailable,
                          selectedTimeoutLabel: timeoutSummary,
                        ),
                      ),
                      const Gap(AppDimensions.spacingXxl),
                      FadeSlideTransition(
                        delay: const Duration(milliseconds: 80),
                        child: IgnorePointer(
                          ignoring: _loadingPinState,
                          child: Opacity(
                            opacity: _loadingPinState ? 0.55 : 1,
                            child: SettingsGroup(
                              title: l10n.securityGroupAccess,
                              children: [
                                SettingsToggleTile(
                                  icon: Icons.lock_outline_rounded,
                                  title: l10n.securityAppLockTitle,
                                  subtitle: l10n.securityAppLockSubtitle,
                                  value: appLockOn,
                                  onChanged: _onAppLockToggled,
                                ),
                                if (showChangePin)
                                  SettingsTile(
                                    icon: Icons.pin_outlined,
                                    title: l10n.securityChangePinTitle,
                                    subtitle: l10n.securityChangePinSubtitle,
                                    onTap: () async {
                                      await HapticService.light();
                                      if (!context.mounted) return;
                                      final ok = await showPinEntrySheet(
                                        context,
                                        mode: PinSheetMode.change,
                                      );
                                      if (ok) {
                                        await _refreshPinState();
                                      }
                                    },
                                  ),
                                if (showBiometric)
                                  SettingsToggleTile(
                                    icon: Icons.fingerprint_rounded,
                                    title: l10n.securityBiometricTitle,
                                    subtitle: l10n.securityBiometricSubtitle,
                                    value: lockState.isBiometricEnabled,
                                    onChanged: _onBiometricToggled,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (appLockOn) ...[
                        const Gap(AppDimensions.spacingXxl),
                        FadeSlideTransition(
                          delay: const Duration(milliseconds: 140),
                          child: DaftarCard(
                            padding: const EdgeInsetsDirectional.all(
                              AppDimensions.spacingXl,
                            ),
                            child: SecurityTimeoutSelector(
                              selectedSeconds: selectedTimeout,
                              onSelected: (seconds) {
                                unawaited(_onTimeoutChanged(seconds));
                              },
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: bottomClearance),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
