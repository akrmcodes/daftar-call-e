import 'dart:async';
import 'dart:math' as math;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// A motion-guided "Create Ledger" button for the home AppBar.
///
/// On first mount the button expands from a compact icon into a rounded pill
/// showing the localized "Add Ledger" label, holds for 2.5 seconds, then
/// collapses back to icon-only. This self-documenting affordance teaches the
/// user what the action does without requiring a tooltip hover.
///
/// ### Motion Physics
/// - **Expand:** 550ms, [AppMotion.curveEmphasized] (easeOutExpo) — explosive
///   initial acceleration, ultra-smooth dramatic deceleration.
/// - **Collapse:** 400ms, [AppMotion.curveStandard] (easeInOutCubic) — organic
///   bidirectional settle.
/// - **Hold duration:** 2500ms between expand-complete and collapse-start.
/// - **Text opacity** is driven by the same controller via an [Interval]:
///   fades in during the last 35% of expansion, fades out during the first
///   35% of collapse. This prevents text from appearing/clipping while the
///   pill is still too narrow to contain the label.
///
/// ### Alignment Architecture (sliding-door mask)
/// Only the outer pill width animates (36dp → locale-measured width) with
/// [Clip.hardEdge]. The interior is a frozen, content-sized [Row] (icon + gap
/// + label) inside an [OverflowBox] aligned to
/// [AlignmentDirectional.centerStart], so collapse is pure optical clipping —
/// no [Expanded], [Flexible], or flex shrink math.
///
/// After the onboarding cycle completes, the button remains as a compact
/// icon with standard tap behaviour.
class AnimatedCreateLedgerAction extends StatefulWidget {
  const AnimatedCreateLedgerAction({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  State<AnimatedCreateLedgerAction> createState() =>
      _AnimatedCreateLedgerActionState();
}

class _AnimatedCreateLedgerActionState extends State<AnimatedCreateLedgerAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandProgress;
  late final Animation<double> _textOpacity;
  Timer? _holdTimer;
  Timer? _startTimer;
  bool _isExpanded = false;

  static const double _iconAnchorSize = 36;
  static const double _collapsedWidth = _iconAnchorSize;
  static const double _labelGap = 6;
  static const double _labelEndInset = AppDimensions.spacingSm;
  static const double _height = AppDimensions.minTapTarget;

  double _expandedContentWidth = _collapsedWidth;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      reverseDuration: const Duration(milliseconds: 400),
    );

    _expandProgress = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.curveEmphasized,
      reverseCurve: AppMotion.curveStandard,
    );

    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 1, curve: Curves.easeOut),
        reverseCurve: const Interval(0.65, 1, curve: Curves.easeIn),
      ),
    );

    _startTimer = Timer(const Duration(milliseconds: 600), _expand);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    final measured = _measureExpandedContentWidth(l10n.addLedger);
    if (measured != _expandedContentWidth) {
      setState(() => _expandedContentWidth = measured);
    }
  }

  double _measureExpandedContentWidth(String label) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textPainter = TextPainter(
      text: TextSpan(text: label, style: AppTextStyles.labelMedium),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      maxLines: 1,
    )..layout();

    return _iconAnchorSize +
        _labelGap +
        textPainter.width.ceilToDouble() +
        _labelEndInset;
  }

  void _expand() {
    if (!mounted) return;
    setState(() => _isExpanded = true);
    unawaited(_controller.forward());
    _holdTimer = Timer(const Duration(milliseconds: 2500), _collapse);
  }

  void _collapse() {
    if (!mounted) return;
    setState(() => _isExpanded = false);
    unawaited(_controller.reverse());
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final iconColor =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final pillColor = isDark ? AppColors.surface3 : AppColors.surface2Light;
    final borderColor =
        isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;
    final labelColor =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return AnimatedBuilder(
      animation: Listenable.merge([_expandProgress, _textOpacity]),
      builder: (context, child) {
        final currentWidth = _collapsedWidth +
            (_expandedContentWidth - _collapsedWidth) * _expandProgress.value;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_isExpanded) {
              _holdTimer?.cancel();
              _collapse();
            }
            widget.onTap();
          },
          child: SizedBox(
            width: math.max(currentWidth, AppDimensions.minTapTarget),
            height: _height,
            child: Center(
              child: Container(
                width: currentWidth,
                height: _iconAnchorSize,
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusCircular,
                  ),
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                clipBehavior: Clip.hardEdge,
                child: OverflowBox(
                  alignment: AlignmentDirectional.centerStart,
                  minWidth: _expandedContentWidth,
                  maxWidth: _expandedContentWidth,
                  minHeight: _iconAnchorSize,
                  maxHeight: _iconAnchorSize,
                  child: SizedBox(
                    width: _expandedContentWidth,
                    height: _iconAnchorSize,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: _iconAnchorSize,
                          height: _iconAnchorSize,
                          child: Center(
                            child: Icon(
                              Icons.create_new_folder_rounded,
                              size: AppDimensions.iconMedium - 2,
                              color: iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: _labelGap),
                        Opacity(
                          opacity: _textOpacity.value,
                          child: Text(
                            l10n.addLedger,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: labelColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                        const SizedBox(width: _labelEndInset),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
