import 'dart:async';
import 'dart:ui';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A premium frosted-glass progress overlay for PDF export.
///
/// Built on top of [TweenAnimationBuilder] so each progress jump animates
/// smoothly from the previous value to the new target (eased with the
/// iOS-feel `easeOutCubic` curve), with no hand-rolled smoothing math and
/// no animation listener wiring.
///
/// The entire overlay sits inside a [RepaintBoundary] so progress repaints
/// never invalidate the underlying screen — the host stays at 60/120 fps.
///
/// Usage:
/// ```dart
/// final controller = ExportProgressOverlay.show(context, title: '...');
/// controller.update(0.4, '...');
/// controller.complete('Done');
/// controller.dismiss();
/// ```
abstract final class ExportProgressOverlay {
  /// Shows the overlay as a modal route and returns a controller to drive
  /// progress updates from outside the widget tree.
  static ExportProgressController show(
    BuildContext context, {
    required String title,
    VoidCallback? onDismiss,
  }) {
    final controller = ExportProgressController();

    unawaited(
      showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 350),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curvedAnimation,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.92,
                end: 1,
              ).animate(curvedAnimation),
              child: child,
            ),
          );
        },
        pageBuilder: (context, animation, secondaryAnimation) {
          return _OverlayContent(
            title: title,
            controller: controller,
            onDismiss: onDismiss,
          );
        },
      ),
    );

    return controller;
  }
}

/// External controller that drives progress updates into the overlay.
class ExportProgressController extends ChangeNotifier {
  double _progress = 0;
  String _message = '';
  bool _isComplete = false;
  bool _isDismissed = false;

  double get progress => _progress;
  String get message => _message;
  bool get isComplete => _isComplete;
  bool get isDismissed => _isDismissed;

  void update(double progress, String message) {
    if (_isDismissed) return;
    _progress = progress.clamp(0, 1);
    _message = message;
    notifyListeners();
  }

  void complete(String message) {
    if (_isDismissed) return;
    _progress = 1;
    _message = message;
    _isComplete = true;
    notifyListeners();
  }

  void dismiss() {
    if (_isDismissed) return;
    _isDismissed = true;
    notifyListeners();
  }
}

// ============================================================================
// Internal overlay content widget
// ============================================================================

class _OverlayContent extends StatefulWidget {
  const _OverlayContent({
    required this.title,
    required this.controller,
    this.onDismiss,
  });

  final String title;
  final ExportProgressController controller;
  final VoidCallback? onDismiss;

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent> {
  // Cached previous progress so TweenAnimationBuilder can smoothly interpolate
  // from the last shown value to the new target on each controller tick.
  double _previousProgress = 0;
  double _targetProgress = 0;
  bool _hasTriggeredCompletionHaptic = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    if (widget.controller.isDismissed) {
      _scheduleDismiss();
      return;
    }

    final newTarget = widget.controller.progress;
    if (newTarget != _targetProgress) {
      _previousProgress = _targetProgress;
      _targetProgress = newTarget;
    }

    if (widget.controller.isComplete && !_hasTriggeredCompletionHaptic) {
      _hasTriggeredCompletionHaptic = true;
      unawaited(HapticFeedback.mediumImpact());
    }

    setState(() {});
  }

  /// Defers `Navigator.pop` to the next frame so we never pop during a build
  /// phase (which would throw `setState() called during build`).
  void _scheduleDismiss() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    final phaseIcon = _phaseIcon(_targetProgress, widget.controller.isComplete);

    // The whole overlay is wrapped in a RepaintBoundary so each repaint
    // (driven by TweenAnimationBuilder ticks) is isolated from the host
    // ContactDetailScreen behind the frosted backdrop.
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Frosted glass backdrop
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: ColoredBox(
                color: (isDark ? Colors.black : Colors.white).withValues(
                  alpha: isDark ? 0.6 : 0.5,
                ),
              ),
            ),
            // Centered card
            Center(
              child: Container(
                width: 300,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingXxl,
                  vertical: AppDimensions.spacing3xl,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: isDark ? 0.88 : 0.96),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  border: Border.all(
                    color: colors.onSurface.withValues(
                      alpha: isDark ? 0.10 : 0.06,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Phase icon with animated transition
                    AnimatedSwitcher(
                      duration: AppDimensions.animationMedium,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Container(
                        key: ValueKey<IconData>(phaseIcon),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: widget.controller.isComplete
                              ? null
                              : (isDark
                                    ? AppColors.surface2
                                    : AppColors.surface1Light),
                          gradient: widget.controller.isComplete
                              ? const LinearGradient(
                                  begin: AlignmentDirectional.topStart,
                                  end: AlignmentDirectional.bottomEnd,
                                  colors: [
                                    AppColors.payment,
                                    AppColors.success,
                                  ],
                                )
                              : null,
                          shape: BoxShape.circle,
                          border: widget.controller.isComplete
                              ? null
                              : Border.all(
                                  color: lapis,
                                  width: AppDimensions.dividerThickness,
                                ),
                          boxShadow: widget.controller.isComplete
                              ? null
                              : AppGlows.ctaRest,
                        ),
                        child: Icon(
                          phaseIcon,
                          color: widget.controller.isComplete
                              ? Colors.white
                              : inkPrimary,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),

                    // Title
                    Text(
                      widget.title,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Smoothly animated progress — single TweenAnimationBuilder
                    // tweens between (previous → target) over 450ms with
                    // easeOutCubic. The percentage label ticks in lockstep
                    // because it reads the same interpolated value.
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: _previousProgress,
                        end: _targetProgress,
                      ),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return Column(
                          children: [
                            _PremiumProgressBar(
                              progress: value,
                              isComplete: widget.controller.isComplete,
                            ),
                            const SizedBox(height: AppDimensions.spacingMd),
                            Text(
                              '${(value * 100).round()}%',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: widget.controller.isComplete
                                    ? AppColors.payment
                                    : AppColors.lapis400,
                                fontWeight: FontWeight.w700,
                                fontFamily: AppTextStyles.latinFontFamily,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),

                    // Phase message
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        widget.controller.message,
                        key: ValueKey<String>(widget.controller.message),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _phaseIcon(double progress, bool isComplete) {
    if (isComplete) return Icons.check_circle_rounded;
    if (progress >= 0.80) return Icons.picture_as_pdf_rounded;
    if (progress >= 0.50) return Icons.construction_rounded;
    if (progress >= 0.20) return Icons.sort_rounded;
    return Icons.hourglass_top_rounded;
  }
}

// ============================================================================
// Premium progress bar with gradient fill
// ============================================================================

class _PremiumProgressBar extends StatelessWidget {
  const _PremiumProgressBar({
    required this.progress,
    required this.isComplete,
  });

  final double progress;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    final trackColor = isDark
        ? AppColors.surface5
        : AppColors.surface3Light;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Container(color: trackColor),
            FractionallySizedBox(
              widthFactor: progress.clamp(0, 1),
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isComplete
                        ? [AppColors.payment, AppColors.success]
                        : [AppColors.lapis400, AppColors.lapis400],
                  ),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusCircular,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
