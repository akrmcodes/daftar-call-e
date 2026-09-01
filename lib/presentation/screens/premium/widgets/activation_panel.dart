import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/screens/premium/widgets/activation_code_formatter.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

/// Activation code panel — top-of-page conversion surface.
///
/// One continuous card shell; body expands/collapses via [SizeTransition] +
/// [FadeTransition] for a buttery open/close. Header tap toggles.
class ActivationPanel extends StatefulWidget {
  const ActivationPanel({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onActivate,
    required this.startCollapsed,
    this.expandToken = 0,
    this.errorMessage,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onActivate;
  final bool startCollapsed;

  /// Parent increments to request expand + focus (e.g. tier CTA).
  final int expandToken;
  final String? errorMessage;

  @override
  State<ActivationPanel> createState() => _ActivationPanelState();
}

class _ActivationPanelState extends State<ActivationPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expandController;
  late final Animation<double> _expand;
  late final Animation<double> _fade;
  String _lastFormatted = '';

  bool get _isExpanded =>
      _expandController.status == AnimationStatus.completed ||
      _expandController.status == AnimationStatus.forward;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: AppDimensions.animationSlow,
      reverseDuration: AppDimensions.animationSnappyExit,
    );
    _expand = CurvedAnimation(
      parent: _expandController,
      curve: AppMotion.curveEnter,
      reverseCurve: AppMotion.curveExit,
    );
    _fade = CurvedAnimation(
      parent: _expandController,
      curve: const Interval(0.15, 1, curve: Curves.easeOut),
      reverseCurve: const Interval(0, 0.7, curve: Curves.easeIn),
    );

    if (!widget.startCollapsed) {
      _expandController.value = 1;
    }

    _lastFormatted = widget.controller.text;
    widget.controller.addListener(_onCodeChanged);
    widget.focusNode.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant ActivationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startCollapsed && !widget.startCollapsed) {
      unawaited(_expandController.forward());
    }
    if (widget.expandToken != oldWidget.expandToken) {
      unawaited(_open(requestFocus: true));
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCodeChanged);
    widget.focusNode.removeListener(_rebuild);
    _expandController.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _onCodeChanged() {
    final next = widget.controller.text;
    if (next.length > _lastFormatted.length && next.endsWith('-')) {
      unawaited(HapticService.selection());
    }
    _lastFormatted = next;
    setState(() {});
  }

  bool get _hasCode {
    final raw = widget.controller.text.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    return raw.isNotEmpty;
  }

  Future<void> _open({required bool requestFocus}) async {
    if (_expandController.value < 1) {
      unawaited(HapticService.light());
      await _expandController.forward();
    }
    if (requestFocus && mounted) {
      widget.focusNode.requestFocus();
    }
  }

  Future<void> _close() async {
    if (_expandController.value == 0) {
      return;
    }
    FocusScope.of(context).unfocus();
    unawaited(HapticService.selection());
    await _expandController.reverse();
  }

  Future<void> _toggleHeader() async {
    if (widget.isLoading) {
      return;
    }
    if (_isExpanded) {
      await _close();
    } else {
      await _open(requestFocus: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final focused = widget.focusNode.hasFocus;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    return AnimatedBuilder(
      animation: _expandController,
      builder: (context, child) {
        final expanded = _expandController.value > 0.01;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            color: isDark ? AppColors.surface2 : AppColors.surface1Light,
            border: Border.all(
              color: focused && expanded
                  ? AppColors.lapis400
                  : (isDark
                      ? AppColors.borderSubtle
                      : AppColors.borderSubtleLight),
              width: focused && expanded ? 1.5 : 0.5,
            ),
            boxShadow: isDark ? AppGlows.khazaFloat : AppGlows.shadowFloat,
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header — always present; tap opens or closes.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleHeader,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppDimensions.cardPadding,
                AppDimensions.spacingLg,
                AppDimensions.spacingSm,
                AppDimensions.spacingLg,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isDark ? AppColors.surface4 : AppColors.surface3Light,
                      border: Border.all(
                        color: AppColors.lapis400.withValues(alpha: 0.35),
                        width: 0.5,
                      ),
                    ),
                    child: Icon(
                      Icons.vpn_key_outlined,
                      size: 18,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Gap(AppDimensions.spacingMd),
                  Expanded(
                    child: Text(
                      l10n.activationAddCode,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _expand,
                    builder: (context, _) {
                      return Transform.rotate(
                        angle: _expand.value * 3.1415926535,
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                  const Gap(AppDimensions.spacingSm),
                ],
              ),
            ),
          ),
          // Body — size + fade for smooth open/close.
          ClipRect(
            child: SizeTransition(
              sizeFactor: _expand,
              alignment: Alignment.topCenter,
              child: FadeTransition(
                opacity: _fade,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppDimensions.cardPadding,
                    0,
                    AppDimensions.cardPadding,
                    AppDimensions.cardPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.premiumVaultSealSubtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const Gap(AppDimensions.spacingLg),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: AnimatedContainer(
                          duration: AppDimensions.animationFast,
                          curve: AppMotion.curveStandard,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surface5
                                : AppColors.surface3Light,
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusSm),
                            border: Border.all(
                              color: widget.errorMessage != null
                                  ? AppColors.error
                                  : focused
                                      ? AppColors.lapis400
                                      : Colors.transparent,
                              width: (widget.errorMessage != null || focused)
                                  ? 1.5
                                  : 0,
                            ),
                          ),
                          child: TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            enabled: !widget.isLoading,
                            textCapitalization: TextCapitalization.characters,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: AppTextStyles.numeralInput.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: scheme.onSurface,
                            ),
                            cursorColor: AppColors.lapis400,
                            cursorWidth: 1.5,
                            inputFormatters: [
                              ActivationCodeFormatter(),
                              FilteringTextInputFormatter.allow(
                                RegExp('[A-Za-z0-9-]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsetsDirectional.fromSTEB(
                                AppDimensions.spacingLg,
                                AppDimensions.spacingLg,
                                AppDimensions.spacingSm,
                                AppDimensions.spacingLg,
                              ),
                              hintText: l10n.activationCodeHint,
                              hintStyle: AppTextStyles.numeralInput.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                                color: inkMuted,
                              ),
                              suffixIcon: _hasCode
                                  ? IconButton(
                                      tooltip: MaterialLocalizations.of(context)
                                          .deleteButtonTooltip,
                                      onPressed: widget.isLoading
                                          ? null
                                          : () {
                                              widget.controller.clear();
                                              widget.focusNode.requestFocus();
                                            },
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: inkMuted,
                                      ),
                                    )
                                  : null,
                            ),
                            onSubmitted: (_) {
                              if (_hasCode) {
                                widget.onActivate();
                              }
                            },
                          ),
                        ),
                      ),
                      if (widget.errorMessage != null) ...[
                        const Gap(AppDimensions.spacingSm),
                        Text(
                          widget.errorMessage!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                      const Gap(AppDimensions.spacingLg),
                      AnimatedOpacity(
                        opacity: _hasCode || widget.isLoading ? 1 : 0.72,
                        duration: AppDimensions.animationFast,
                        curve: AppMotion.curveStandard,
                        child: DaftarButton(
                          label: l10n.activateButton,
                          onPressed: widget.isLoading || !_hasCode
                              ? null
                              : widget.onActivate,
                          isLoading: widget.isLoading,
                          size: DaftarButtonSize.xlarge,
                          isExpanded: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
