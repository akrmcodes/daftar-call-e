import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:typed_data';

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/services/onboarding_analytics.dart';
import 'package:daftar/core/utils/demo_store_seeder.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/entitlement_providers.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/providers/locale_provider.dart' hide Locale;
import 'package:daftar/presentation/providers/merchant_profile_providers.dart';
import 'package:daftar/presentation/providers/onboarding_provider.dart';
import 'package:daftar/presentation/providers/premium_providers.dart';
import 'package:daftar/presentation/providers/settings_preferences_provider.dart';
import 'package:daftar/presentation/providers/theme_provider.dart' hide Theme;
import 'package:daftar/presentation/screens/onboarding/onboarding_beat.dart';
import 'package:daftar/presentation/screens/onboarding/widgets/onboarding_google_beat.dart';
import 'package:daftar/presentation/screens/onboarding/widgets/onboarding_hero_beat.dart';
import 'package:daftar/presentation/screens/onboarding/widgets/onboarding_language_beat.dart';
import 'package:daftar/presentation/screens/onboarding/widgets/onboarding_ledger_beat.dart';
import 'package:daftar/presentation/screens/onboarding/widgets/onboarding_look_beat.dart';
import 'package:daftar/presentation/screens/onboarding/widgets/onboarding_pro_beat.dart';
import 'package:daftar/presentation/screens/onboarding/widgets/onboarding_step_indicator.dart';
import 'package:daftar/presentation/screens/onboarding/widgets/onboarding_store_beat.dart';
import 'package:daftar/presentation/screens/settings/widgets/logo_source_tile.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_brand_mark.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/demo_seed_report_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Contest onboarding — seven-beat Khazna setup spine (not a marketing carousel).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const _ledgerColor = 0xFF64748B;

  late final AnimationController _breathController;
  late final TextEditingController _storeNameController;
  late final TextEditingController _activationCodeController;
  late final ImagePicker _imagePicker;

  int _beatIndex = 0;
  bool _isBusy = false;
  bool _isCompleting = false;
  bool _didSeedLanguage = false;
  bool _didLogStart = false;
  bool _proExpanded = false;
  bool _proContinueDespiteError = false;
  String? _googleError;
  String? _googleGrantError;
  bool _googleSignedInNeedsGrant = false;
  String? _proError;
  String? _pendingLogoPath;
  String? _pendingLogoName;

  @override
  void initState() {
    super.initState();
    _storeNameController = TextEditingController();
    _activationCodeController = TextEditingController();
    _imagePicker = ImagePicker();
    _breathController = AnimationController(
      vsync: this,
      duration: AppDimensions.animationBreath,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _logOnboardingStart();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBreathWithReduceMotion();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _activationCodeController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  void _syncBreathWithReduceMotion() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _breathController
        ..stop()
        ..value = 1;
      return;
    }
    if (!_breathController.isAnimating) {
      unawaited(_breathController.repeat(reverse: true));
    }
  }

  void _logOnboardingStart() {
    if (_didLogStart) {
      return;
    }
    _didLogStart = true;
    final enabled =
        ref.read(appSettingsProvider).asData?.value.analyticsEnabled ?? false;
    unawaited(OnboardingAnalytics.logStart(analyticsEnabled: enabled));
  }

  List<OnboardingBeat> _beats({required bool includeLedger}) {
    return [
      OnboardingBeat.hero,
      OnboardingBeat.language,
      OnboardingBeat.look,
      OnboardingBeat.store,
      OnboardingBeat.google,
      OnboardingBeat.pro,
      if (includeLedger) OnboardingBeat.ledger,
    ];
  }

  void _seedLanguageFromDevice() {
    if (_didSeedLanguage) {
      return;
    }
    _didSeedLanguage = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final device = View.of(context).platformDispatcher.locale;
      final code = device.languageCode.toLowerCase() == 'ar' ? 'ar' : 'en';
      ref.read(localeProvider.notifier).setLocale(Locale(code));
    });
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) {
      return;
    }
    _isCompleting = true;
    setState(() => _isBusy = true);
    unawaited(HapticService.buttonPress());
    var succeeded = false;
    try {
      final ok = await ref
          .read(onboardingControllerProvider.notifier)
          .complete();
      if (!mounted) {
        return;
      }
      if (ok) {
        succeeded = true;
        final enabled = ref
                .read(appSettingsProvider)
                .asData
                ?.value
                .analyticsEnabled ??
            false;
        unawaited(OnboardingAnalytics.logComplete(analyticsEnabled: enabled));
        context.go(RouteNames.homePath);
        return;
      }
    } finally {
      if (mounted && !succeeded) {
        _isCompleting = false;
        setState(() => _isBusy = false);
      }
    }
  }

  void _goToIndex(int index) {
    unawaited(HapticService.buttonPress());
    setState(() {
      _beatIndex = index;
      _googleError = null;
      _googleGrantError = null;
      _googleSignedInNeedsGrant = false;
    });
  }

  Future<void> _advance({required bool includeLedger}) async {
    final beats = _beats(includeLedger: includeLedger);
    if (_beatIndex >= beats.length - 1) {
      await _completeOnboarding();
      return;
    }
    _goToIndex(_beatIndex + 1);
  }

  Future<void> _onPrimary({required bool includeLedger}) async {
    if (_isBusy) {
      return;
    }
    final beats = _beats(includeLedger: includeLedger);
    final beat = beats[_beatIndex.clamp(0, beats.length - 1)];
    switch (beat) {
      case OnboardingBeat.hero:
      case OnboardingBeat.language:
      case OnboardingBeat.look:
        await _advance(includeLedger: includeLedger);
      case OnboardingBeat.store:
        await _persistStoreThenAdvance(includeLedger: includeLedger);
      case OnboardingBeat.google:
        if (_googleSignedInNeedsGrant) {
          await _completeDriveGrant(includeLedger: includeLedger);
        } else {
          await _signInWithGoogle(includeLedger: includeLedger);
        }
      case OnboardingBeat.pro:
        await _onProContinue(includeLedger: includeLedger);
      case OnboardingBeat.ledger:
        break;
    }
  }

  Future<bool> _persistStoreDraft() async {
    final name = _storeNameController.text.trim();
    if (name.isEmpty) {
      return true;
    }
    final saved = await ref
        .read(merchantProfileControllerProvider.notifier)
        .updateProfile(storeName: name);
    if (!mounted) {
      return false;
    }
    if (saved == null) {
      return false;
    }
    if (_pendingLogoPath != null) {
      await ref
          .read(merchantProfileControllerProvider.notifier)
          .setLogo(sourcePath: _pendingLogoPath!);
    }
    return mounted;
  }

  Future<void> _onTryDemoStore({required bool completeOnboarding}) async {
    if (_isBusy) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isBusy = true);
    final persisted = await _persistStoreDraft();
    if (!mounted) {
      return;
    }
    if (!persisted) {
      setState(() => _isBusy = false);
      return;
    }

    try {
      final database = ref.read(appDatabaseProvider);
      final localeCode = ref.read(localeProvider).languageCode;
      final report = await DemoStoreSeeder.seedData(
        database,
        localeOverride: localeCode,
        draftStoreName: _storeNameController.text.trim(),
      );
      ref
        ..invalidate(ledgersProvider)
        ..invalidate(merchantProfileProvider)
        ..invalidate(appSettingsProvider);
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      unawaited(HapticService.success());
      await showDemoSeedReportDialog(context, report);
      if (!mounted) {
        return;
      }
      if (completeOnboarding) {
        await _completeOnboarding();
      } else {
        final ledgersAsync = ref.read(ledgersProvider);
        final includeLedger = ledgersAsync.maybeWhen(
          data: (ledgers) => ledgers.isEmpty,
          orElse: () => true,
        );
        await _advance(includeLedger: includeLedger);
      }
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      unawaited(HapticService.validationError());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.demoSeedReportError)),
      );
    }
  }

  Future<void> _persistStoreThenAdvance({required bool includeLedger}) async {
    final name = _storeNameController.text.trim();
    if (name.isNotEmpty) {
      setState(() => _isBusy = true);
      final saved = await ref
          .read(merchantProfileControllerProvider.notifier)
          .updateProfile(storeName: name);
      if (!mounted) {
        return;
      }
      if (saved == null) {
        setState(() => _isBusy = false);
        return;
      }
      if (_pendingLogoPath != null) {
        await ref
            .read(merchantProfileControllerProvider.notifier)
            .setLogo(sourcePath: _pendingLogoPath!);
      }
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
    }
    await _advance(includeLedger: includeLedger);
  }

  Future<void> _signInWithGoogle({required bool includeLedger}) async {
    setState(() {
      _isBusy = true;
      _googleError = null;
      _googleGrantError = null;
    });
    final result = await ref
        .read(signInControllerProvider.notifier)
        .signInWithGoogle();
    if (!mounted) {
      return;
    }
    setState(() => _isBusy = false);
    final failed = result.fold((_) => true, (_) => false);
    if (failed) {
      unawaited(HapticService.validationError());
      setState(() {
        _googleError = AppLocalizations.of(context)!.onboardingSetupGoogleFailed;
        _googleSignedInNeedsGrant = false;
      });
      return;
    }
    final grantReady = await ref.read(driveOfflineGrantReadyProvider.future);
    if (!mounted) {
      return;
    }
    if (!grantReady) {
      setState(() => _googleSignedInNeedsGrant = true);
      return;
    }
    await _advance(includeLedger: includeLedger);
  }

  Future<void> _completeDriveGrant({required bool includeLedger}) async {
    setState(() {
      _isBusy = true;
      _googleGrantError = null;
    });
    final result = await ref
        .read(driveOfflineGrantControllerProvider.notifier)
        .completeDriveAuthorization();
    if (!mounted) {
      return;
    }
    setState(() => _isBusy = false);
    final failed = result.fold((_) => true, (_) => false);
    if (failed) {
      unawaited(HapticService.validationError());
      setState(() {
        _googleGrantError =
            AppLocalizations.of(context)!.onboardingSetupGoogleGrantError;
      });
      return;
    }
    setState(() => _googleSignedInNeedsGrant = false);
    await _advance(includeLedger: includeLedger);
  }

  Future<void> _onProContinue({required bool includeLedger}) async {
    final code = _activationCodeController.text.trim();
    if (code.isEmpty || _proContinueDespiteError) {
      await _advance(includeLedger: includeLedger);
      return;
    }

    setState(() {
      _isBusy = true;
      _proError = null;
    });
    final ok = await ref
        .read(activateCodeControllerProvider.notifier)
        .activate(code);
    if (!mounted) {
      return;
    }
    setState(() => _isBusy = false);
    if (ok) {
      await _advance(includeLedger: includeLedger);
      return;
    }
    unawaited(HapticService.validationError());
    setState(() {
      _proError = AppLocalizations.of(context)!.activationErrorInvalid;
      _proContinueDespiteError = true;
      _proExpanded = true;
    });
  }

  Future<void> _onLedgerChosen(
    LedgerType type, {
    String? customName,
  }) async {
    if (_isBusy) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final name = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : switch (type) {
            LedgerType.customers => l10n.closingAgentLedgerTypeCustomers,
            LedgerType.suppliers => l10n.closingAgentLedgerTypeSuppliers,
            LedgerType.personal => l10n.closingAgentLedgerTypePersonal,
            LedgerType.custom => l10n.closingAgentLedgerTypeCustom,
          };
    final icon = switch (type) {
      LedgerType.customers => 'people_alt_rounded',
      LedgerType.suppliers => 'local_shipping_rounded',
      LedgerType.personal => 'person_rounded',
      LedgerType.custom => 'folder_special_rounded',
    };

    setState(() => _isBusy = true);
    final result = await ref.read(ledgerControllerProvider.notifier).createLedger(
          name: name,
          type: type,
          icon: icon,
          color: _ledgerColor,
        );
    if (!mounted) {
      return;
    }
    final created = result.fold((_) => false, (_) => true);
    if (!created) {
      setState(() => _isBusy = false);
      return;
    }
    await _completeOnboarding();
  }

  Future<Uint8List?> _loadLogoBytes(String path) async {
    try {
      return await File(path).readAsBytes();
    } on Object {
      return null;
    }
  }

  String _resolvedStoreName(MerchantProfile? profile) {
    final draft = _storeNameController.text.trim();
    if (draft.isNotEmpty) {
      return draft;
    }
    final persisted = profile?.storeName.trim();
    if (persisted != null && persisted.isNotEmpty) {
      return persisted;
    }
    return '';
  }

  String? _resolvedLogoPath(MerchantProfile? profile) {
    if (_pendingLogoPath != null) {
      return _pendingLogoPath;
    }
    return profile?.logoPath;
  }

  bool _resolvedHasLogo(MerchantProfile? profile) {
    if (_pendingLogoPath != null) {
      return true;
    }
    return profile?.logoPath != null && profile!.logoPath!.isNotEmpty;
  }

  Future<void> _onSkipOptional({required bool includeLedger}) async {
    if (_isBusy) {
      return;
    }
    final beats = _beats(includeLedger: includeLedger);
    final beat = beats[_beatIndex.clamp(0, beats.length - 1)];
    if (beat != OnboardingBeat.store &&
        beat != OnboardingBeat.google &&
        beat != OnboardingBeat.pro) {
      return;
    }
    await _advance(includeLedger: includeLedger);
  }

  Future<void> _onPickLogo() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await AppBottomSheet.show<ImageSource>(
      context,
      title: l10n.merchantBrandingPickSourceTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LogoSourceTile(
            icon: Icons.photo_camera_outlined,
            label: l10n.merchantBrandingPickCamera,
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          const Gap(AppDimensions.spacingSm),
          LogoSourceTile(
            icon: Icons.photo_library_outlined,
            label: l10n.merchantBrandingPickGallery,
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null || !mounted) {
      return;
    }
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 100,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _pendingLogoPath = picked.path;
      _pendingLogoName = picked.name;
    });
  }

  Widget _buildBeat({
    required OnboardingBeat beat,
    required bool isPro,
    required bool includeLedger,
  }) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);
    final currencyCode = ref.watch(appSettingsProvider).asData?.value.defaultCurrency ??
        'YER';
    final merchantProfile = ref.watch(merchantProfileProvider).asData?.value;

    switch (beat) {
      case OnboardingBeat.hero:
        return const OnboardingHeroBeat();
      case OnboardingBeat.language:
        _seedLanguageFromDevice();
        return OnboardingLanguageBeat(
          selectedLanguageCode: locale.languageCode,
          onSelected: (next) {
            unawaited(HapticService.selection());
            ref.read(localeProvider.notifier).setLocale(next);
          },
        );
      case OnboardingBeat.look:
        return OnboardingLookBeat(
          themeMode: themeMode,
          onThemeModeChanged: (mode) {
            unawaited(HapticService.selection());
            ref.read(themeProvider.notifier).setThemeMode(mode);
          },
          currencyCode: currencyCode,
          onCurrencyChanged: (currency) {
            unawaited(HapticService.selection());
            unawaited(
              ref
                  .read(settingsPreferencesProvider.notifier)
                  .setDefaultCurrency(currency.code),
            );
          },
        );
      case OnboardingBeat.store:
        return OnboardingStoreBeat(
          nameController: _storeNameController,
          isPro: isPro,
          pendingLogoName: _pendingLogoName,
          onPickLogo: () => unawaited(_onPickLogo()),
        );
      case OnboardingBeat.google:
        return OnboardingGoogleBeat(
          errorMessage: _googleError,
          signedInNeedsGrant: _googleSignedInNeedsGrant,
          grantErrorMessage: _googleGrantError,
        );
      case OnboardingBeat.pro:
        return OnboardingProBeat(
          expanded: _proExpanded,
          onToggleExpanded: () {
            setState(() => _proExpanded = !_proExpanded);
          },
          codeController: _activationCodeController,
          errorMessage: _proError,
          storeName: _resolvedStoreName(merchantProfile),
          hasLogo: _resolvedHasLogo(merchantProfile),
          logoPath: _resolvedLogoPath(merchantProfile),
          profile: merchantProfile,
          loadLogoBytes: _loadLogoBytes,
        );
      case OnboardingBeat.ledger:
        return OnboardingLedgerBeat(
          isBusy: _isBusy,
          onSelected: (type, {customName}) =>
              unawaited(_onLedgerChosen(type, customName: customName)),
          onTryDemoStore: () => unawaited(
            _onTryDemoStore(completeOnboarding: true),
          ),
        );
    }
  }

  String _primaryLabel({
    required AppLocalizations l10n,
    required OnboardingBeat beat,
    required bool googleSignedInNeedsGrant,
  }) {
    if (beat == OnboardingBeat.google && googleSignedInNeedsGrant) {
      return l10n.onboardingSetupGoogleCompleteDrive;
    }
    return switch (beat) {
      OnboardingBeat.google => l10n.onboardingSetupGooglePrimary,
      OnboardingBeat.hero => l10n.onboardingNext,
      OnboardingBeat.language => l10n.onboardingNext,
      OnboardingBeat.look => l10n.onboardingNext,
      OnboardingBeat.store => l10n.onboardingNext,
      OnboardingBeat.pro => l10n.onboardingNext,
      OnboardingBeat.ledger => l10n.onboardingNext,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final ledgersAsync = ref.watch(ledgersProvider);
    final includeLedger = ledgersAsync.maybeWhen(
      data: (ledgers) => ledgers.isEmpty,
      orElse: () => true,
    );
    final beats = _beats(includeLedger: includeLedger);
    if (!includeLedger && _beatIndex >= beats.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_completeOnboarding());
        }
      });
    }
    final beatIndex = _beatIndex.clamp(0, beats.length - 1);
    final beat = beats[beatIndex];
    final isPro = ref.watch(entitlementProvider).maybeWhen(
          data: (entitlement) => entitlement.tier != AppTier.free,
          orElse: () => false,
        );
    final showSkip = beat == OnboardingBeat.store ||
        beat == OnboardingBeat.google ||
        beat == OnboardingBeat.pro;
    final showFooter = beat != OnboardingBeat.ledger;
    final skipLabel = beat == OnboardingBeat.google
        ? l10n.onboardingSetupGoogleLater
        : l10n.onboardingSkip;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surface0 : AppColors.surface0Light,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                top: AppDimensions.spacingMd,
                start: AppDimensions.spacingSm,
                end: AppDimensions.spacingLg,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: AppDimensions.minTapTarget,
                    height: AppDimensions.minTapTarget,
                    child: beat == OnboardingBeat.hero
                        ? const Center(child: DaftarBrandMark(size: 32))
                        : IconButton(
                            key: const ValueKey<String>('onboarding-back'),
                            tooltip: MaterialLocalizations.of(context)
                                .backButtonTooltip,
                            onPressed: _isBusy
                                ? null
                                : () => _goToIndex(beatIndex - 1),
                            icon: Icon(
                              Icons.arrow_back,
                              color: inkPrimary,
                            ),
                          ),
                  ),
                  const Spacer(),
                  if (showSkip)
                    TextButton(
                      key: const ValueKey<String>('onboarding-skip'),
                      onPressed: _isBusy
                          ? null
                          : () => unawaited(
                                _onSkipOptional(includeLedger: includeLedger),
                              ),
                      child: Text(
                        skipLabel,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: inkPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : AppDimensions.animationMedium,
                switchInCurve: AppMotion.curveEnter,
                switchOutCurve: AppMotion.curveExit,
                child: KeyedSubtree(
                  key: ValueKey<OnboardingBeat>(beat),
                  child: SizedBox.expand(
                    child: _buildBeat(
                      beat: beat,
                      isPro: isPro,
                      includeLedger: includeLedger,
                    ),
                  ),
                ),
              ),
            ),
            OnboardingStepIndicator(
              pageCount: beats.length,
              currentIndex: beatIndex,
            ),
            const Gap(AppDimensions.spacingXxl),
            if (showFooter)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppDimensions.spacingXl,
                  0,
                  AppDimensions.spacingXl,
                  AppDimensions.spacingXxl,
                ),
                child: AnimatedBuilder(
                  animation: _breathController,
                  builder: (context, child) {
                    if (!isDark || reduceMotion) {
                      return child!;
                    }
                    final breathGlows = AppGlows.ctaRest
                        .map(
                          (glow) => glow.copyWith(
                            color: glow.color.withValues(
                              alpha: 0.28 + (_breathController.value * 0.08),
                            ),
                          ),
                        )
                        .toList();
                    return DecoratedBox(
                      decoration: BoxDecoration(boxShadow: breathGlows),
                      child: child,
                    );
                  },
                  child: DaftarButton(
                    key: const ValueKey<String>('onboarding-next'),
                    label: _primaryLabel(
                      l10n: l10n,
                      beat: beat,
                      googleSignedInNeedsGrant: _googleSignedInNeedsGrant,
                    ),
                    isExpanded: true,
                    isLoading: _isBusy,
                    onPressed: _isBusy
                        ? null
                        : () => unawaited(
                              _onPrimary(includeLedger: includeLedger),
                            ),
                  ),
                ),
              )
            else
              const Gap(AppDimensions.spacingXxl),
          ],
        ),
      ),
    );
  }
}
