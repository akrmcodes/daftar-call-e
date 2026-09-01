import 'dart:async';
import 'dart:math' as math;

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/security_service.dart';
import 'package:daftar/presentation/providers/app_lock_provider.dart';
import 'package:daftar/presentation/screens/settings/widgets/custom_pin_numpad.dart';
import 'package:daftar/presentation/screens/settings/widgets/pin_entry_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_brand_mark.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Full-screen, non-dismissible gate shown when [shouldShowAppLockOverlay] is
/// true. Blocks all underlying routes until PIN or biometric unlock succeeds.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with WidgetsBindingObserver {
  String _pin = '';
  bool _isSubmitting = false;
  bool _isConfirmingForgotPin = false;
  bool _isWiping = false;
  String? _forgotPinConfirmationCode;
  bool _autoBiometricConsumed = false;
  int _shakeTrigger = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleAutoBiometricIfForeground();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _scheduleAutoBiometricIfForeground();
    }
  }

  bool get _isAppResumed =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void _scheduleAutoBiometricIfForeground() {
    if (_autoBiometricConsumed || !_isAppResumed || _isConfirmingForgotPin) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _autoBiometricConsumed ||
          !_isAppResumed ||
          _isConfirmingForgotPin) {
        return;
      }
      final lockState = ref.read(appLockManagerProvider);
      if (!lockState.isBiometricEnabled) {
        return;
      }
      if (!ref.read(appLockManagerProvider.notifier).isForeground) {
        return;
      }
      unawaited(_tryAutoBiometricOnce());
    });
  }

  Future<void> _tryAutoBiometricOnce() async {
    if (_autoBiometricConsumed || !_isAppResumed) {
      return;
    }
    _autoBiometricConsumed = true;
    await _unlockWithBiometrics(isAutomatic: true);
  }

  Future<void> _unlockWithBiometrics({bool isAutomatic = false}) async {
    if (_isSubmitting || !_isAppResumed || _isConfirmingForgotPin) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final ok = await ref
          .read(appLockManagerProvider.notifier)
          .unlockWithBiometrics();
      if (!ok && isAutomatic && mounted) {
        setState(() => _errorMessage = null);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitPin() async {
    if (_pin.length != AppConstants.pinLength ||
        _isSubmitting ||
        _isConfirmingForgotPin) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(appLockManagerProvider.notifier)
          .unlockWithPin(_pin);

      if (!mounted) {
        return;
      }

      final l10n = AppLocalizations.of(context)!;

      if (result != PinValidationResult.success) {
        unawaited(HapticService.validationError());
        setState(() {
          _pin = '';
          _shakeTrigger++;
          _errorMessage = switch (result) {
            PinValidationResult.lockedOut => l10n.securityPinLockedOut,
            PinValidationResult.invalidFormat => l10n.securityPinInvalid,
            _ => l10n.securityPinIncorrect,
          };
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _appendDigit(String digit) {
    if (_pin.length >= AppConstants.pinLength || _isSubmitting) {
      return;
    }
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });
    if (_pin.length == AppConstants.pinLength) {
      unawaited(_submitPin());
    }
  }

  void _backspace() {
    if (_pin.isEmpty || _isSubmitting) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  String _generateForgotPinConfirmationCode() {
    final random = math.Random.secure();
    return List.generate(
      AppConstants.pinLength,
      (_) => random.nextInt(10).toString(),
    ).join();
  }

  void _enterForgotPinConfirmation() {
    if (_isSubmitting || _isWiping) {
      return;
    }
    unawaited(HapticService.buttonPress());
    setState(() {
      _isConfirmingForgotPin = true;
      _forgotPinConfirmationCode = _generateForgotPinConfirmationCode();
      _pin = '';
      _errorMessage = null;
    });
  }

  void _cancelForgotPinConfirmation() {
    unawaited(HapticService.buttonPress());
    setState(() {
      _isConfirmingForgotPin = false;
      _forgotPinConfirmationCode = null;
    });
  }

  Future<void> _confirmForgotPinErase() async {
    if (_isSubmitting || _isWiping) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isWiping = true;
      _errorMessage = null;
    });

    unawaited(HapticService.deleteConfirmed());

    final ok = await ref
        .read(appLockManagerProvider.notifier)
        .executeForgotPinRecovery();

    if (!mounted) {
      return;
    }

    if (ok) {
      context.go(RouteNames.backupPath);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _isWiping = false;
      _errorMessage = AppLocalizations.of(context)!.securityPinSaveFailed;
    });
  }

  Widget _buildForgotPinConfirmationScreen({
    required AppLocalizations l10n,
    required bool isDark,
    required Color inkPrimary,
    required Color warningColor,
  }) {
    final background = isDark ? AppColors.surface0 : AppColors.surface0Light;
    final code = _forgotPinConfirmationCode!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _cancelForgotPinConfirmation();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: background,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppDimensions.pagePaddingH,
              AppDimensions.spacingXxl,
              AppDimensions.pagePaddingH,
              AppDimensions.spacing3xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: warningColor,
                ),
                const Gap(AppDimensions.spacingLg),
                Text(
                  l10n.lockScreenForgotPinTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.displaySmall.copyWith(
                    color: inkPrimary,
                  ),
                ),
                const Gap(AppDimensions.spacing3xl),
                _ForgotPinInlineConfirmation(
                  key: ValueKey('forgot_pin_confirm_$code'),
                  confirmationCode: code,
                  isSubmitting: _isSubmitting,
                  onCancel: _cancelForgotPinConfirmation,
                  onConfirmErase: () => unawaited(_confirmForgotPinErase()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isWiping) {
      return PopScope(
        canPop: false,
        child: Material(
          color: isDark ? AppColors.surface0 : AppColors.surface0Light,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(
                  AppDimensions.pagePaddingH,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const Gap(AppDimensions.spacingXl),
                    Text(
                      l10n.lockScreenForgotPinPreparing,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: isDark
                            ? AppColors.inkPrimary
                            : AppColors.inkPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final showBiometric = ref.watch(
      appLockManagerProvider.select((s) => s.isBiometricEnabled),
    );
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final muted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final warningColor = isDark ? AppColors.debt : AppColors.debtLight;
    final viewHeight = MediaQuery.sizeOf(context).height;
    final numpadMaxHeight = math.min(viewHeight * 0.34, 300).toDouble();
    final showNumpad = !_isSubmitting;

    if (_isConfirmingForgotPin && _forgotPinConfirmationCode != null) {
      return _buildForgotPinConfirmationScreen(
        l10n: l10n,
        isDark: isDark,
        inkPrimary: inkPrimary,
        warningColor: warningColor,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_isConfirmingForgotPin) {
          return;
        }
        _cancelForgotPinConfirmation();
      },
      child: Material(
        color: isDark ? AppColors.surface0 : AppColors.surface0Light,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppDimensions.pagePaddingH,
            ),
            child: Column(
              children: [
                const Gap(AppDimensions.spacing3xl),
                const DaftarBrandMark(
                  size: 80,
                  glow: true,
                ),
                const Gap(AppDimensions.spacingLg),
                Text(
                  l10n.lockScreenTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.displaySmall.copyWith(
                    color: inkPrimary,
                  ),
                ),
                const Gap(AppDimensions.spacingSm),
                Text(
                  l10n.lockScreenSubtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: muted),
                ),
                const Gap(AppDimensions.spacingXxl),
                PinDotIndicator(
                  length: _pin.length,
                  dotCount: AppConstants.pinLength,
                  shakeTrigger: _shakeTrigger,
                ),
                const Gap(AppDimensions.spacingMd),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  )
                else
                  Text(
                    l10n.securityPinHint,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(color: muted),
                  ),
                const Gap(AppDimensions.spacingXl),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: showNumpad
                        ? CustomPinNumpad(
                            key: const ValueKey('pin_numpad'),
                            onDigit: _appendDigit,
                            onBackspace: _backspace,
                            maxHeight: numpadMaxHeight,
                          )
                        : const Padding(
                            key: ValueKey('pin_loading'),
                            padding: EdgeInsets.all(
                              AppDimensions.spacing3xl,
                            ),
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                  ),
                ),
                const Gap(AppDimensions.spacingMd),
                TextButton(
                  onPressed: _isSubmitting ? null : _enterForgotPinConfirmation,
                  child: Text(
                    l10n.lockScreenForgotPin,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (showBiometric)
                  TextButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => unawaited(_unlockWithBiometrics()),
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: Text(l10n.lockScreenBiometricRetry),
                  ),
                const Gap(AppDimensions.spacingLg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline destructive confirmation — no modal route above the lock overlay.
class _ForgotPinInlineConfirmation extends StatefulWidget {
  const _ForgotPinInlineConfirmation({
    required this.confirmationCode,
    required this.isSubmitting,
    required this.onCancel,
    required this.onConfirmErase,
    super.key,
  });

  final String confirmationCode;
  final bool isSubmitting;
  final VoidCallback onCancel;
  final VoidCallback onConfirmErase;

  @override
  State<_ForgotPinInlineConfirmation> createState() =>
      _ForgotPinInlineConfirmationState();
}

class _ForgotPinInlineConfirmationState
    extends State<_ForgotPinInlineConfirmation> {
  /// Raw digits from the keyboard only — never copied from the displayed code.
  String _typedConfirmationCode = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceFill = isDark ? AppColors.surface2 : AppColors.surface1Light;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final warningColor = isDark ? AppColors.debt : AppColors.debtLight;
    final warningBackground = warningColor.withValues(
      alpha: isDark ? 0.16 : 0.12,
    );
    final isMatch =
        _typedConfirmationCode.length == AppConstants.pinLength &&
        _typedConfirmationCode == widget.confirmationCode;
    final canErase = isMatch && !widget.isSubmitting;

    return Column(
      key: const ValueKey('forgot_pin_confirm_body'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacingXl),
          decoration: BoxDecoration(
            color: surfaceFill,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
              color: isDark
                  ? AppColors.borderSubtle
                  : AppColors.borderSubtleLight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: warningBackground,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: warningColor,
                  size: AppDimensions.iconMedium,
                ),
              ),
              const Gap(AppDimensions.spacingMd),
              Expanded(
                child: Text(
                  l10n.lockScreenForgotPinBody,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: inkSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Gap(AppDimensions.spacingXxl),
        Text(
          l10n.lockScreenForgotPinTypeCode,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelLarge.copyWith(
            color: inkSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(AppDimensions.spacingLg),
        _ForgotPinConfirmationCodeDisplay(
          code: widget.confirmationCode,
          warningColor: warningColor,
          isDark: isDark,
        ),
        const Gap(AppDimensions.spacingXl),
        _ForgotPinOtpInput(
          typedCode: _typedConfirmationCode,
          isMatch: isMatch,
          enabled: !widget.isSubmitting,
          onChanged: (value) {
            setState(() => _typedConfirmationCode = value);
          },
          onCompleted: canErase ? widget.onConfirmErase : null,
        ),
        const Gap(AppDimensions.spacingXl),
        AnimatedOpacity(
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          opacity: canErase ? 1 : 0.42,
          child: DaftarButton(
            label: l10n.lockScreenForgotPinCta,
            variant: DaftarButtonVariant.destructive,
            isExpanded: true,
            isLoading: widget.isSubmitting,
            onPressed: canErase ? widget.onConfirmErase : null,
          ),
        ),
        const Gap(AppDimensions.spacingMd),
        DaftarButton(
          label: l10n.backupRestoreCancel,
          variant: DaftarButtonVariant.tertiary,
          isExpanded: true,
          onPressed: widget.isSubmitting ? null : widget.onCancel,
        ),
      ],
    );
  }
}

/// Digit pills — visually distinct from the entry field; excluded from autofill.
class _ForgotPinConfirmationCodeDisplay extends StatelessWidget {
  const _ForgotPinConfirmationCodeDisplay({
    required this.code,
    required this.warningColor,
    required this.isDark,
  });

  final String code;
  final Color warningColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final pillBackground = warningColor.withValues(alpha: isDark ? 0.12 : 0.08);

    return ExcludeSemantics(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < code.length; index++) ...[
              if (index > 0) const Gap(AppDimensions.spacingSm),
              Container(
                width: 48,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pillBackground,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                    color: warningColor.withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  code[index],
                  style: AppTextStyles.titleLarge.copyWith(
                    color: warningColor,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Four-box OTP entry with a hidden capture field (no visible single-line input).
class _ForgotPinOtpInput extends StatefulWidget {
  const _ForgotPinOtpInput({
    required this.typedCode,
    required this.isMatch,
    required this.enabled,
    required this.onChanged,
    this.onCompleted,
  });

  final String typedCode;
  final bool isMatch;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback? onCompleted;

  @override
  State<_ForgotPinOtpInput> createState() => _ForgotPinOtpInputState();
}

class _ForgotPinOtpInputState extends State<_ForgotPinOtpInput> {
  static const double _boxSize = 56;

  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    _controller.addListener(_syncFromController);
    if (widget.typedCode.isNotEmpty) {
      _controller.text = widget.typedCode;
    }
  }

  @override
  void didUpdateWidget(covariant _ForgotPinOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.typedCode != _controller.text) {
      _controller.text = widget.typedCode;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncFromController);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _requestFocus() {
    if (!widget.enabled) {
      return;
    }
    FocusScope.of(context).requestFocus(_focusNode);
  }

  String _sanitizeDigits(String raw) {
    final digitsOnly = raw.replaceAll(RegExp('[^0-9]'), '');
    if (digitsOnly.length <= AppConstants.pinLength) {
      return digitsOnly;
    }
    return digitsOnly.substring(0, AppConstants.pinLength);
  }

  void _syncFromController() {
    final next = _sanitizeDigits(_controller.text);
    if (_controller.text != next) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      return;
    }
    widget.onChanged(next);
    setState(() {});
  }

  void _handleChanged(String raw) {
    final next = _sanitizeDigits(raw);
    if (_controller.text != next) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      return;
    }
    widget.onChanged(next);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtColor = isDark ? AppColors.debt : AppColors.debtLight;
    final paymentColor = isDark ? AppColors.payment : AppColors.paymentLight;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inactiveFill = isDark ? AppColors.surface3 : AppColors.surface2Light;
    final typedCode = _controller.text;
    final activeSemantic = widget.isMatch ? paymentColor : debtColor;
    final activeFill = widget.isMatch
        ? (isDark
              ? AppColors.paymentContainer
              : AppColors.paymentContainerLight)
        : (isDark ? AppColors.debtContainer : AppColors.debtContainerLight);
    final isFocused = _focusNode.hasFocus;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _requestFocus,
          behavior: HitTestBehavior.opaque,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(AppConstants.pinLength, (index) {
                final hasDigit = index < typedCode.length;
                final digit = hasDigit ? typedCode[index] : '';
                final isActiveCell = isFocused && index == typedCode.length;

                return Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: index == 0 ? 0 : AppDimensions.spacingSm,
                  ),
                  child: AnimatedContainer(
                    duration: AppDimensions.animationFast,
                    curve: Curves.easeOutCubic,
                    width: _boxSize,
                    height: _boxSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hasDigit || widget.isMatch
                          ? activeFill.withValues(alpha: isDark ? 0.55 : 0.35)
                          : inactiveFill,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                      border: Border.all(
                        color: activeSemantic,
                        width: isActiveCell || widget.isMatch ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      digit,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: inkPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        Visibility(
          visible: false,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          maintainFocusability: true,
          maintainInteractivity: true,
          child: SizedBox(
            width: 1,
            height: 1,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              textDirection: TextDirection.ltr,
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(AppConstants.pinLength),
              ],
              onChanged: _handleChanged,
              onSubmitted: (_) => widget.onCompleted?.call(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders [LockScreen] above the app when the lock overlay flag is active.
class AppLockOverlay extends ConsumerWidget {
  const AppLockOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockState = ref.watch(appLockManagerProvider);
    final showLock = lockState.shouldShowLockOverlay;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (showLock)
          Positioned.fill(
            child: LockScreen(
              key: ValueKey<int>(lockState.lockSession),
            ),
          ),
      ],
    );
  }
}
