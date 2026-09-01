import 'dart:async';
import 'dart:math' as math;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/security_service.dart';
import 'package:daftar/presentation/providers/app_lock_provider.dart';
import 'package:daftar/presentation/screens/settings/widgets/custom_pin_numpad.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

/// Flow mode for the PIN bottom sheet.
enum PinSheetMode {
  create,
  change,
  disableVerify,
}

/// Shows the premium PIN entry sheet and returns `true` on success.
Future<bool> showPinEntrySheet(
  BuildContext context, {
  required PinSheetMode mode,
}) {
  final l10n = AppLocalizations.of(context)!;
  return AppBottomSheet.show<bool>(
    context,
    title: switch (mode) {
      PinSheetMode.create => l10n.securityPinCreateTitle,
      PinSheetMode.change => l10n.securityPinChangeTitle,
      PinSheetMode.disableVerify => l10n.securityPinDisableTitle,
    },
    maxHeightFactor: 0.88,
    child: PinEntrySheetBody(mode: mode),
  ).then((value) => value ?? false);
}

enum _PinStep {
  createEnter,
  createConfirm,
  changeCurrent,
  changeNew,
  changeConfirm,
  disableVerify,
}

class PinEntrySheetBody extends ConsumerStatefulWidget {
  const PinEntrySheetBody({required this.mode, super.key});

  final PinSheetMode mode;

  @override
  ConsumerState<PinEntrySheetBody> createState() => _PinEntrySheetBodyState();
}

class _PinEntrySheetBodyState extends ConsumerState<PinEntrySheetBody> {
  late _PinStep _step;
  String _pin = '';
  String? _firstPin;
  bool _isSubmitting = false;
  int _shakeTrigger = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _step = switch (widget.mode) {
      PinSheetMode.create => _PinStep.createEnter,
      PinSheetMode.change => _PinStep.changeCurrent,
      PinSheetMode.disableVerify => _PinStep.disableVerify,
    };
  }

  bool get _canSubmit => _pin.length == AppConstants.pinLength;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  String get _subtitle {
    return switch (_step) {
      _PinStep.createEnter || _PinStep.changeNew => _l10n.securityPinSubtitle,
      _PinStep.createConfirm || _PinStep.changeConfirm =>
        _l10n.securityPinConfirmSubtitle,
      _PinStep.changeCurrent => _l10n.securityPinCurrentSubtitle,
      _PinStep.disableVerify => _l10n.securityPinDisableSubtitle,
    };
  }

  Future<void> _onComplete() async {
    if (!_canSubmit || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final manager = ref.read(appLockManagerProvider.notifier);

    try {
      switch (_step) {
        case _PinStep.createEnter:
          _advanceStep(_PinStep.createConfirm, storePin: _pin);
        case _PinStep.createConfirm:
          if (_pin != _firstPin) {
            _reject(_l10n.securityPinMismatch);
            return;
          }
          final created = await manager.configurePin(_pin);
          if (!created) {
            _reject(_l10n.securityPinSaveFailed);
            return;
          }
          if (!mounted) return;
          Navigator.of(context).pop(true);

        case _PinStep.changeCurrent:
          final currentResult =
              await ref.read(securityServiceProvider).validatePin(_pin);
          if (currentResult != PinValidationResult.success) {
            _reject(_messageForValidation(currentResult));
            return;
          }
          _advanceStep(_PinStep.changeNew);

        case _PinStep.changeNew:
          _advanceStep(_PinStep.changeConfirm, storePin: _pin);

        case _PinStep.changeConfirm:
          if (_pin != _firstPin) {
            _reject(_l10n.securityPinMismatch);
            return;
          }
          final changed = await manager.changePin(_pin);
          if (!changed) {
            _reject(_l10n.securityPinSaveFailed);
            return;
          }
          if (!mounted) return;
          Navigator.of(context).pop(true);

        case _PinStep.disableVerify:
          final verify =
              await ref.read(securityServiceProvider).validatePin(_pin);
          if (verify != PinValidationResult.success) {
            _reject(_messageForValidation(verify));
            return;
          }
          final disabled = await manager.removePinAndDisableLock();
          if (!disabled) {
            _reject(_l10n.securityPinSaveFailed);
            return;
          }
          if (!mounted) return;
          Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _advanceStep(_PinStep next, {String? storePin}) {
    setState(() {
      _firstPin = storePin ?? _firstPin;
      _step = next;
      _pin = '';
      _errorMessage = null;
    });
  }

  void _reject(String message) {
    unawaited(HapticService.validationError());
    setState(() {
      _pin = '';
      _errorMessage = message;
      _shakeTrigger++;
      _isSubmitting = false;
    });
  }

  String _messageForValidation(PinValidationResult result) {
    return switch (result) {
      PinValidationResult.incorrect => _l10n.securityPinIncorrect,
      PinValidationResult.lockedOut => _l10n.securityPinLockedOut,
      PinValidationResult.invalidFormat => _l10n.securityPinInvalid,
      _ => _l10n.securityPinIncorrect,
    };
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
      unawaited(_onComplete());
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark
        ? AppColors.inkMuted
        : AppColors.inkMutedLight;
    final errorColor = theme.colorScheme.error;

    final viewHeight = MediaQuery.sizeOf(context).height;
    final numpadMaxHeight =
        math.min(viewHeight * 0.36, 280).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _subtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: muted),
        ),
        const Gap(AppDimensions.spacingMd),
        PinDotIndicator(
          length: _pin.length,
          dotCount: AppConstants.pinLength,
          shakeTrigger: _shakeTrigger,
        ),
        const Gap(AppDimensions.spacingSm),
        if (_errorMessage != null)
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: errorColor),
          )
        else
          Text(
            _l10n.securityPinHint,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: muted),
          ),
        const Gap(AppDimensions.spacingLg),
        if (_isSubmitting)
          const Padding(
            padding: EdgeInsets.all(AppDimensions.spacingLg),
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          CustomPinNumpad(
            onDigit: _appendDigit,
            onBackspace: _backspace,
            maxHeight: numpadMaxHeight,
          ),
        const Gap(AppDimensions.spacingMd),
      ],
    );
  }
}

/// Filled dot indicators for PIN length with shake-on-error.
class PinDotIndicator extends StatelessWidget {
  const PinDotIndicator({
    required this.length,
    required this.dotCount,
    required this.shakeTrigger,
    super.key,
  });

  final int length;
  final int dotCount;
  final int shakeTrigger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = theme.colorScheme.primary;
    final inactive = theme.colorScheme.onSurface.withValues(alpha: 0.2);

    final dots = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(dotCount, (index) {
        final filled = index < length;
        return Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppDimensions.spacingXs,
            end: AppDimensions.spacingXs,
          ),
          child: AnimatedContainer(
            duration: AppDimensions.animationFast,
            curve: Curves.easeOutCubic,
            width: filled ? 14 : 12,
            height: filled ? 14 : 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? active : Colors.transparent,
              border: Border.all(
                color: filled ? active : inactive,
                width: 1.5,
              ),
            ),
          ),
        );
      }),
    );

    return dots
        .animate(
          key: ValueKey(shakeTrigger),
        )
        .shake(
          duration: AppDimensions.animationMedium,
          hz: 4,
          curve: Curves.easeInOut,
        );
  }
}
