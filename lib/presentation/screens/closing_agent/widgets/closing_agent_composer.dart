import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_vault_seal.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_voice_chamber.dart';
import 'package:daftar/presentation/shared/widgets/daftar_tap_target.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Floating glass composer dock: multiline field, send, and hold-to-talk mic.
class ClosingAgentComposer extends StatefulWidget {
  /// Creates the composer dock.
  const ClosingAgentComposer({
    required this.controller,
    required this.isRunning,
    required this.sendIsPrimary,
    required this.onSubmit,
    required this.onMicTap,
    required this.onMicHoldStart,
    required this.onMicHoldEnd,
    required this.onMicHoldCancel,
    this.isRecording = false,
    this.amplitudeStream,
    super.key,
  });

  /// Text controller for the goal field.
  final TextEditingController controller;

  /// When true, send shows a spinner.
  final bool isRunning;

  /// Hold-to-talk in progress.
  final bool isRecording;

  /// Live amplitude while recording; optional.
  final Stream<double>? amplitudeStream;

  /// When false, send is secondary so Confirm owns the one glow.
  final bool sendIsPrimary;

  /// Submits the trimmed goal text.
  final ValueChanged<String> onSubmit;

  /// Short tap — hold-to-talk hint (not coming-soon).
  final VoidCallback onMicTap;

  /// Long-press start — permission + record.
  final VoidCallback onMicHoldStart;

  /// Long-press release or 20s cap — stop and submit.
  final VoidCallback onMicHoldEnd;

  /// Long-press cancel — discard clip.
  final VoidCallback onMicHoldCancel;

  /// Scroll inset for content above the floating dock (excluding safe area).
  static const double scrollInset = 120;

  /// Ink field height inside the dock (voice chamber stays 40).
  static const double inkFieldHeight = 48;

  /// Vertical drag threshold to arm slide-up cancel.
  static const double cancelDragThreshold = 64;

  @override
  State<ClosingAgentComposer> createState() => _ClosingAgentComposerState();
}

class _ClosingAgentComposerState extends State<ClosingAgentComposer> {
  bool _cancelArmed = false;
  bool _micPressed = false;

  @override
  void didUpdateWidget(ClosingAgentComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isRecording && oldWidget.isRecording) {
      _cancelArmed = false;
    }
  }

  void _onMicLongPressStart(LongPressStartDetails details) {
    setState(() {
      _micPressed = true;
      _cancelArmed = false;
    });
    unawaited(HapticService.longPress());
    widget.onMicHoldStart();
  }

  void _onMicLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final shouldArm = details.localOffsetFromOrigin.dy <=
        -ClosingAgentComposer.cancelDragThreshold;
    if (shouldArm == _cancelArmed) {
      return;
    }
    setState(() => _cancelArmed = shouldArm);
    if (shouldArm) {
      unawaited(HapticService.selection());
    }
  }

  void _onMicLongPressEnd(LongPressEndDetails details) {
    setState(() => _micPressed = false);
    unawaited(HapticService.light());
    if (_cancelArmed) {
      _cancelArmed = false;
      widget.onMicHoldCancel();
      return;
    }
    widget.onMicHoldEnd();
  }

  void _onMicLongPressCancel() {
    setState(() {
      _micPressed = false;
      _cancelArmed = false;
    });
    widget.onMicHoldCancel();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassFill = isDark ? AppColors.glassFill : AppColors.glassFillLight;
    final glassBorder = isDark
        ? AppColors.glassBorder
        : AppColors.glassBorderLight;
    final specularRazor =
        isDark ? AppColors.specularRazorDark : AppColors.specularRazorLight;
    final fresnelSheen = isDark
        ? const Color(0x05FFFFFF)
        : const Color(0x04FFFFFF);
    final micEnabled = !widget.isRunning || widget.isRecording;
    final sendGlows = !widget.isRecording && widget.sendIsPrimary;
    final lapisRing = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final dockBorderColor = widget.isRunning
        ? lapisRing.withValues(alpha: isDark ? 0.72 : 0.55)
        : glassBorder;
    final dockBorderWidth = widget.isRunning
        ? 0.5
        : AppDimensions.dividerThickness;
    final fieldHint = widget.isRunning
        ? l10n.closingAgentSpeakWorking
        : l10n.closingAgentComposerHint;

    final squircleRadius = SmoothBorderRadius(
      cornerRadius: AppDimensions.radiusLg,
      cornerSmoothing: 0.6,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.pagePaddingH,
        0,
        AppDimensions.pagePaddingH,
        AppDimensions.spacingMd,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: SmoothRectangleBorder(borderRadius: squircleRadius),
          shadows: isDark ? AppGlows.khazaFloat : AppGlows.shadowFloat,
        ),
        child: ClipSmoothRect(
          radius: squircleRadius,
          child: RepaintBoundary(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: glassFill)),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                          colors: [fresnelSheen, Colors.transparent],
                          stops: const [0, 0.4],
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 0,
                    start: 0,
                    end: 0,
                    height: AppDimensions.dividerThickness,
                    child: ColoredBox(color: specularRazor),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: SmoothRectangleBorder(
                            borderRadius: squircleRadius,
                            side: BorderSide(
                              color: dockBorderColor,
                              width: dockBorderWidth,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppDimensions.spacingMd,
                      AppDimensions.spacingSm,
                      AppDimensions.spacingMd,
                      AppDimensions.spacingSm,
                    ),
                    child: Row(
                      children: [
                        _ComposerMicButton(
                          isRecording: widget.isRecording,
                          isPressed: _micPressed,
                          semanticsLabel: widget.isRecording
                              ? l10n.closingAgentMicRecording
                              : l10n.closingAgentMicSemantics,
                          enabled: micEnabled,
                          onTap: widget.onMicTap,
                          onLongPressStart: micEnabled
                              ? _onMicLongPressStart
                              : null,
                          onLongPressMoveUpdate: micEnabled
                              ? _onMicLongPressMoveUpdate
                              : null,
                          onLongPressEnd: micEnabled
                              ? _onMicLongPressEnd
                              : null,
                          onLongPressCancel: micEnabled
                              ? _onMicLongPressCancel
                              : null,
                        ),
                        const Gap(AppDimensions.spacingSm),
                        Container(
                          width: AppDimensions.dividerThickness,
                          height: ClosingAgentComposer.inkFieldHeight * 0.6,
                          color: isDark
                              ? AppColors.borderSubtle
                              : AppColors.borderSubtleLight,
                        ),
                        const Gap(AppDimensions.spacingSm),
                        Expanded(
                          child: ClipRect(
                            child: AnimatedSwitcher(
                              duration: AppDimensions.animationMedium,
                              switchInCurve: AppMotion.curveEnter,
                              switchOutCurve: AppMotion.curveExit,
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: AlignmentDirectional.centerStart,
                                  children: <Widget>[
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                );
                              },
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              child: widget.isRecording
                                  ? ClosingAgentVoiceChamber(
                                      key: const ValueKey<String>(
                                        'closing-agent-voice-chamber',
                                      ),
                                      cancelArmed: _cancelArmed,
                                      amplitudeStream: widget.amplitudeStream,
                                    )
                                  : _ComposerInkField(
                                      key: const ValueKey<String>(
                                        'closing-agent-ink-field',
                                      ),
                                      controller: widget.controller,
                                      hint: fieldHint,
                                      enabled: !widget.isRunning,
                                      onSubmitted: widget.onSubmit,
                                    ),
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: AppDimensions.animationMedium,
                          curve: AppMotion.curveEnter,
                          alignment: AlignmentDirectional.centerEnd,
                          child: widget.isRecording
                              ? const SizedBox.shrink()
                              : Row(
                                  key: const ValueKey<String>(
                                    'closing-agent-send-slot',
                                  ),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Gap(AppDimensions.spacingSm),
                                    _ComposerSquareButton(
                                      icon: Icons.arrow_upward_rounded,
                                      semanticsLabel:
                                          l10n.closingAgentSendSemantics,
                                      isPrimary: sendGlows,
                                      chromeless: true,
                                      isLoading: widget.isRunning,
                                      onPressed: widget.isRunning
                                          ? null
                                          : () => widget.onSubmit(
                                                widget.controller.text,
                                              ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
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
}

class _ComposerInkField extends StatefulWidget {
  const _ComposerInkField({
    required this.controller,
    required this.hint,
    required this.enabled,
    required this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  @override
  State<_ComposerInkField> createState() => _ComposerInkFieldState();
}

class _ComposerInkFieldState extends State<_ComposerInkField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_ComposerInkField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;

    return SizedBox(
      height: ClosingAgentComposer.inkFieldHeight,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: lapis,
              selectionColor: lapis.withValues(alpha: AppColors.alphaSoft),
              selectionHandleColor: lapis,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            textAlignVertical: TextAlignVertical.center,
            autocorrect: false,
            enableSuggestions: false,
            spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
            onSubmitted: widget.onSubmitted,
            cursorColor: lapis,
            cursorWidth: 1.5,
            style: AppTextStyles.bodyLarge.copyWith(
              color: inkPrimary,
              height: 1.25,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              isDense: true,
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: widget.hint,
              hintStyle: AppTextStyles.bodyLarge.copyWith(
                color: isDark
                    ? AppColors.inkSecondary
                    : AppColors.inkSecondaryLight,
                height: 1.25,
                fontWeight: FontWeight.w400,
              ),
              contentPadding: const EdgeInsetsDirectional.symmetric(
                vertical: AppDimensions.spacingSm,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerMicButton extends StatelessWidget {
  const _ComposerMicButton({
    required this.isRecording,
    required this.isPressed,
    required this.semanticsLabel,
    required this.enabled,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
    this.onLongPressCancel,
  });

  /// Visual core — tap target expands via [DaftarTapTarget].
  static const double coreDiameter = 36;

  final bool isRecording;
  final bool isPressed;
  final String semanticsLabel;
  final bool enabled;
  final VoidCallback onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;
  final VoidCallback? onLongPressCancel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final idleRing = isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;
    final lapisRing = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final glow = isRecording
        ? (isPressed ? AppGlows.ctaPressed : AppGlows.ctaRest)
        : null;
    final ringColor = isRecording
        ? lapisRing
        : (isPressed && enabled ? inkSecondary : idleRing);
    final ringWidth = isRecording ? 1.5 : 1.0;
    final iconColor = !enabled
        ? inkMuted
        : isRecording
        ? inkPrimary
        : (isPressed ? inkSecondary : inkMuted);
    final icon = isRecording ? Icons.mic_rounded : Icons.mic_outlined;
    const iconSizeIdle = 22.0;

    return Semantics(
      button: true,
      label: semanticsLabel,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                unawaited(HapticService.buttonPress());
                onTap();
              }
            : null,
        onLongPressStart: enabled ? onLongPressStart : null,
        onLongPressMoveUpdate: enabled ? onLongPressMoveUpdate : null,
        onLongPressEnd: enabled ? onLongPressEnd : null,
        onLongPressCancel: enabled ? onLongPressCancel : null,
        child: DaftarTapTarget(
          child: AnimatedScale(
            scale: isPressed && enabled ? 0.94 : 1,
            duration: AppDimensions.animationFast,
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: AppDimensions.animationFast,
              curve: Curves.easeOutCubic,
              width: coreDiameter,
              height: coreDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: ringWidth),
                boxShadow: glow,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: iconColor,
                size: isRecording ? AppDimensions.iconMedium : iconSizeIdle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerSquareButton extends StatefulWidget {
  const _ComposerSquareButton({
    required this.icon,
    required this.semanticsLabel,
    required this.isPrimary,
    required this.onPressed,
    this.isLoading = false,
    this.chromeless = false,
  });

  final IconData icon;
  final String semanticsLabel;
  final bool isPrimary;
  final bool isLoading;
  final bool chromeless;
  final VoidCallback? onPressed;

  @override
  State<_ComposerSquareButton> createState() => _ComposerSquareButtonState();
}

class _ComposerSquareButtonState extends State<_ComposerSquareButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final mutedForeground = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final background = widget.isPrimary
        ? (isDark ? AppColors.surface2 : AppColors.surface1Light)
        : (isDark ? AppColors.surface3 : AppColors.surface2Light);
    final borderColor = widget.isPrimary
        ? (isDark ? AppColors.lapis400 : AppColors.lapis500)
        : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight);
    final glow = widget.isPrimary
        ? (_pressed ? AppGlows.ctaPressed : AppGlows.ctaRest)
        : null;
    final iconColor = widget.chromeless
        ? (widget.isPrimary ? foreground : mutedForeground)
        : foreground;

    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      enabled: _enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled
            ? () {
                unawaited(HapticService.buttonPress());
                widget.onPressed?.call();
              }
            : null,
        child: DaftarTapTarget(
          child: AnimatedScale(
            scale: _pressed && _enabled ? 0.97 : 1,
            duration: AppDimensions.animationFast,
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: AppDimensions.animationFast,
              curve: Curves.easeOutCubic,
              width: widget.chromeless
                  ? AppDimensions.iconLarge
                  : AppDimensions.minTapTarget,
              height: widget.chromeless
                  ? AppDimensions.iconLarge
                  : AppDimensions.minTapTarget,
              decoration: widget.chromeless
                  ? BoxDecoration(boxShadow: glow)
                  : BoxDecoration(
                      color: background,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                      border: Border.all(
                        color: borderColor,
                        width: AppDimensions.dividerThickness,
                      ),
                      boxShadow: glow,
                    ),
              alignment: Alignment.center,
              child: widget.isLoading
                  ? ClosingAgentVaultLoadingArc(color: iconColor)
                  : Icon(
                      widget.icon,
                      color: iconColor,
                      size: AppDimensions.iconMedium,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
