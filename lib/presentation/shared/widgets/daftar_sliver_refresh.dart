import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show AnimatedOpacity, Brightness, Icons, Theme;

/// Runs [refresh] and holds the spinner for at least [AppDimensions.refreshPerceivedDuration].
///
/// Pair with [DaftarSliverRefreshControl], which adds a fake-done checkmark hold
/// after this completes so the capsule stays expanded.
Future<void> daftarRefreshWithPerceivedDelay(
  Future<void> Function() refresh,
) async {
  await Future.wait<void>([
    refresh(),
    Future<void>.delayed(AppDimensions.refreshPerceivedDuration),
  ]);
}

/// Lapis Lux–styled pull-to-refresh sliver for [CustomScrollView].
///
/// Intercepts [onRefresh] to show a checkmark while the Future stays open,
/// preventing the capsule from retracting before success is visible.
class DaftarSliverRefreshControl extends StatefulWidget {
  const DaftarSliverRefreshControl({
    required this.onRefresh,
    super.key,
    this.refreshTriggerPullDistance = 96,
    this.refreshIndicatorExtent = 72,
  });

  final RefreshCallback onRefresh;
  final double refreshTriggerPullDistance;
  final double refreshIndicatorExtent;

  @override
  State<DaftarSliverRefreshControl> createState() =>
      _DaftarSliverRefreshControlState();
}

class _DaftarSliverRefreshControlState extends State<DaftarSliverRefreshControl> {
  bool _refreshHapticTriggered = false;
  bool _forceSuccessUI = false;

  static const double _innerExtent = AppDimensions.iconMedium;

  /// Arrow / spinner cross-fade — fast snap.
  static const Duration _opacitySnapDuration = Duration(milliseconds: 50);

  /// Checkmark appears instantly.
  static const Duration _checkSnapDuration = Duration.zero;

  /// Capsule stays expanded (Future still open) while checkmark is shown.
  static const Duration _fakeDoneHoldDuration = Duration(milliseconds: 400);

  Future<void> _handleRefresh() async {
    if (mounted) {
      setState(() => _forceSuccessUI = false);
    }

    await widget.onRefresh();

    if (!mounted) {
      return;
    }

    setState(() => _forceSuccessUI = true);
    await Future<void>.delayed(_fakeDoneHoldDuration);

    if (mounted) {
      setState(() => _forceSuccessUI = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      refreshTriggerPullDistance: widget.refreshTriggerPullDistance,
      refreshIndicatorExtent: widget.refreshIndicatorExtent,
      onRefresh: _handleRefresh,
      builder: (
        context,
        refreshState,
        pulledExtent,
        refreshTriggerPullDistance,
        refreshIndicatorExtent,
      ) {
        final isRefreshing =
            refreshState == RefreshIndicatorMode.refresh;
        final isDone = refreshState == RefreshIndicatorMode.done;

        final capsuleVisible = pulledExtent > 0 ||
            isRefreshing ||
            isDone ||
            _forceSuccessUI;

        if (!capsuleVisible) {
          _refreshHapticTriggered = false;
          return const SizedBox.shrink();
        }

        if (!_refreshHapticTriggered &&
            refreshState == RefreshIndicatorMode.armed) {
          _refreshHapticTriggered = true;
          unawaited(HapticService.pullRefreshThreshold());
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surfaceColor =
            isDark ? AppColors.surface2 : AppColors.surface1Light;
        final lapisAccent =
            isDark ? AppColors.lapis400 : AppColors.lapis500;
        final inkMuted =
            isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

        final progress =
            (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);
        final rotationRadians = progress * math.pi;

        final showArrow = !isRefreshing &&
            !_forceSuccessUI &&
            (refreshState == RefreshIndicatorMode.drag ||
                refreshState == RefreshIndicatorMode.armed ||
                refreshState == RefreshIndicatorMode.inactive);
        final showSpinner = isRefreshing && !_forceSuccessUI;
        final showCheck = isDone || _forceSuccessUI;

        final scale = isRefreshing || isDone || _forceSuccessUI
            ? 1.0
            : (0.82 + (progress * 0.18));

        final showSuccessChrome = _forceSuccessUI || isDone;

        return SizedBox(
          height: refreshIndicatorExtent,
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: surfaceColor.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusCircular,
                  ),
                  border: Border.all(
                    color: lapisAccent.withValues(
                      alpha: showSuccessChrome ? 0.5 : 0.35,
                    ),
                    width: AppDimensions.dividerThickness,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: lapisAccent.withValues(
                        alpha: isDark ? 0.16 : 0.1,
                      ),
                      blurRadius: showSuccessChrome ? 20 : 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingLg,
                    vertical: AppDimensions.spacingSm,
                  ),
                  child: SizedBox(
                    width: _innerExtent,
                    height: _innerExtent,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedOpacity(
                          opacity: showArrow ? 1.0 : 0.0,
                          duration: _opacitySnapDuration,
                          child: IgnorePointer(
                            ignoring: !showArrow,
                            child: Transform.rotate(
                              angle: rotationRadians,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: _innerExtent,
                                color: inkMuted,
                              ),
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: showSpinner ? 1.0 : 0.0,
                          duration: _opacitySnapDuration,
                          child: IgnorePointer(
                            ignoring: !showSpinner,
                            child: CupertinoActivityIndicator(
                              radius: 12,
                              color: lapisAccent,
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: showCheck ? 1.0 : 0.0,
                          duration: _checkSnapDuration,
                          child: IgnorePointer(
                            ignoring: !showCheck,
                            child: Icon(
                              Icons.check_rounded,
                              size: _innerExtent,
                              color: lapisAccent,
                            ),
                          ),
                        ),
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
