import 'dart:async' show scheduleMicrotask, unawaited;
import 'dart:math' as math;

import 'package:daftar/app/router/app_routes.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

/// Test key for the FAB coach Got it CTA.
const Key daftarCoachFabGotItKey = ValueKey<String>('daftarCoachFabGotIt');

/// Test key for the FAB coach Skip control.
const Key daftarCoachFabSkipKey = ValueKey<String>('daftarCoachFabSkip');

/// Test key for the painted tooltip card ([DecoratedBox]).
const Key daftarCoachFabTooltipCardKey =
    ValueKey<String>('daftarCoachFabTooltipCard');

/// Khazna FAB coach — custom overlay spotlight (hole punched in paint).
///
/// Domain and application layers must never import coach UI internals.
abstract final class DaftarCoachMark {
  static OverlayEntry? _overlayEntry;

  /// Last painted spotlight hole in overlay-local coordinates.
  @visibleForTesting
  static Rect? debugHoleRect;

  /// Overlay-local rect for [targetKey], using physical global coordinates.
  static Rect? overlayTargetOf(
    GlobalKey targetKey,
    OverlayState overlay,
  ) {
    final targetContext = targetKey.currentContext;
    if (targetContext == null || !targetContext.mounted) {
      return null;
    }
    try {
      final renderObject = targetContext.findRenderObject();
      if (renderObject is! RenderBox) {
        return null;
      }
      final targetBox = renderObject;
      if (!targetBox.attached || !targetBox.hasSize) {
        return null;
      }
      final size = targetBox.size;
      if (size.width <= 0 || size.height <= 0) {
        return null;
      }
      final overlayRender = overlay.context.findRenderObject();
      if (overlayRender is! RenderBox || !overlayRender.attached) {
        return null;
      }
      final topLeft = overlayRender.globalToLocal(
        targetBox.localToGlobal(Offset.zero),
      );
      if (topLeft.dx.isNaN || topLeft.dy.isNaN) {
        return null;
      }
      return topLeft & size;
    } on Object {
      return null;
    }
  }

  /// Whether [targetKey] can be spotlighted on the root navigator overlay.
  static bool isTargetLaidOut(GlobalKey targetKey) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      return false;
    }
    return overlayTargetOf(targetKey, overlay) != null;
  }

  @visibleForTesting
  static void removeOverlayForTest() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    debugHoleRect = null;
  }

  /// Shows the one-shot center-FAB coach. Overlay absorbs FAB gestures.
  ///
  /// Returns `true` when the overlay is still showing after insertion.
  /// [onDismissed] must not capture widget `ref` — callers capture the use
  /// case while mounted.
  static Future<bool> showFab({
    required BuildContext context,
    required GlobalKey targetKey,
    required VoidCallback onDismissed,
  }) async {
    if (!context.mounted || !isTargetLaidOut(targetKey)) {
      return false;
    }
    if (_overlayEntry != null) {
      return false;
    }

    final overlay = rootNavigatorKey.currentState!.overlay!;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textDirection = Directionality.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    var dismissed = false;

    void dismiss() {
      if (dismissed) {
        return;
      }
      dismissed = true;
      scheduleMicrotask(() {
        try {
          onDismissed();
        } on Object {
          // Coach overlay must never surface as ErrorWidget.builder.
        }
      });
    }

    void closeOverlay() {
      _overlayEntry?.remove();
      _overlayEntry = null;
      debugHoleRect = null;
    }

    void dismissAndClose() {
      closeOverlay();
      dismiss();
    }

    unawaited(HapticService.selection());

    const paddingFocus = 2.0;
    final holeRect = ValueNotifier<Rect?>(null);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return Directionality(
          textDirection: textDirection,
          child: Material(
            type: MaterialType.transparency,
            child: _FabCoachOverlay(
            targetKey: targetKey,
            holeRect: holeRect,
            isDark: isDark,
            reduceMotion: reduceMotion,
            paddingFocus: paddingFocus,
            semanticsLabel: l10n.closingAgentFabTipSemantics,
            skipLabel: l10n.closingAgentFabTipSkip,
            onGotIt: dismissAndClose,
            onSkip: dismissAndClose,
            ),
          ),
        );
      },
    );

    try {
      _overlayEntry = entry;
      overlay.insert(entry);

      for (var frame = 0; frame < 15; frame++) {
        await WidgetsBinding.instance.endOfFrame;
      }
      return _overlayEntry != null;
    } on Object {
      closeOverlay();
      return false;
    }
  }
}

class _FabCoachOverlay extends StatefulWidget {
  const _FabCoachOverlay({
    required this.targetKey,
    required this.holeRect,
    required this.isDark,
    required this.reduceMotion,
    required this.paddingFocus,
    required this.semanticsLabel,
    required this.skipLabel,
    required this.onGotIt,
    required this.onSkip,
  });

  final GlobalKey targetKey;
  final ValueNotifier<Rect?> holeRect;
  final bool isDark;
  final bool reduceMotion;
  final double paddingFocus;
  final String semanticsLabel;
  final String skipLabel;
  final VoidCallback onGotIt;
  final VoidCallback onSkip;

  @override
  State<_FabCoachOverlay> createState() => _FabCoachOverlayState();
}

class _FabCoachOverlayState extends State<_FabCoachOverlay> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    widget.holeRect.addListener(_onHoleRect);
    if (widget.reduceMotion) {
      _opacity = 1;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _opacity = 1);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.holeRect.removeListener(_onHoleRect);
    super.dispose();
  }

  void _onHoleRect() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final hole = widget.holeRect.value;
    final overlayHeight = MediaQuery.sizeOf(context).height;
    final tooltipBottom = hole == null
        ? 0.0
        : overlayHeight - hole.top + AppDimensions.spacingSm;

    final content = Semantics(
      label: widget.semanticsLabel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _FabSpotlightLayer(
              targetKey: widget.targetKey,
              holeRect: widget.holeRect,
              isDark: widget.isDark,
              paddingFocus: widget.paddingFocus,
            ),
          ),
          if (hole != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: tooltipBottom,
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: AppDimensions.spacingSm,
                ),
                child: _FabCoachTooltipAnchor(
                  fabCenterX: hole.center.dx,
                  child: DaftarCoachMarkTooltip(onGotIt: widget.onGotIt),
                ),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: SafeArea(
              child: Listener(
                onPointerDown: (_) {},
                child: InkWell(
                  onTap: widget.onSkip,
                  child: Padding(
                    key: daftarCoachFabSkipKey,
                    padding: const EdgeInsets.all(AppDimensions.spacingMd),
                    child: Text(
                      widget.skipLabel,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.inkPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.reduceMotion) {
      return content;
    }
    return AnimatedOpacity(
      opacity: _opacity,
      duration: AppDimensions.animationMedium,
      curve: AppMotion.curveEnter,
      child: content,
    );
  }
}

class _FabSpotlightLayer extends SingleChildRenderObjectWidget {
  const _FabSpotlightLayer({
    required this.targetKey,
    required this.holeRect,
    required this.isDark,
    required this.paddingFocus,
  });

  final GlobalKey targetKey;
  final ValueNotifier<Rect?> holeRect;
  final bool isDark;
  final double paddingFocus;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderFabSpotlight(
      targetKey: targetKey,
      holeRect: holeRect,
      shadowColor: isDark ? AppColors.surface0 : AppColors.inkPrimaryLight,
      shadowOpacity: isDark ? AppColors.alphaScrim : AppColors.alphaStrong,
      paddingFocus: paddingFocus,
      radius: AppDimensions.radiusSm,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderFabSpotlight renderObject,
  ) {
    renderObject
      ..targetKey = targetKey
      ..holeRect = holeRect
      ..shadowColor = isDark ? AppColors.surface0 : AppColors.inkPrimaryLight
      ..shadowOpacity = isDark ? AppColors.alphaScrim : AppColors.alphaStrong
      ..paddingFocus = paddingFocus
      ..radius = AppDimensions.radiusSm;
  }
}

class _RenderFabSpotlight extends RenderBox {
  _RenderFabSpotlight({
    required GlobalKey targetKey,
    required ValueNotifier<Rect?> holeRect,
    required Color shadowColor,
    required double shadowOpacity,
    required double paddingFocus,
    required double radius,
  })  : _targetKey = targetKey,
        _holeRect = holeRect,
        _shadowColor = shadowColor,
        _shadowOpacity = shadowOpacity,
        _paddingFocus = paddingFocus,
        _radius = radius;

  GlobalKey _targetKey;
  ValueNotifier<Rect?> _holeRect;
  Color _shadowColor;
  double _shadowOpacity;
  double _paddingFocus;
  double _radius;

  GlobalKey get targetKey => _targetKey;
  set targetKey(GlobalKey value) {
    if (_targetKey == value) {
      return;
    }
    _targetKey = value;
    markNeedsPaint();
  }

  ValueNotifier<Rect?> get holeRect => _holeRect;
  set holeRect(ValueNotifier<Rect?> value) {
    if (_holeRect == value) {
      return;
    }
    _holeRect = value;
    markNeedsPaint();
  }

  Color get shadowColor => _shadowColor;
  set shadowColor(Color value) {
    if (_shadowColor == value) {
      return;
    }
    _shadowColor = value;
    markNeedsPaint();
  }

  double get shadowOpacity => _shadowOpacity;
  set shadowOpacity(double value) {
    if (_shadowOpacity == value) {
      return;
    }
    _shadowOpacity = value;
    markNeedsPaint();
  }

  double get paddingFocus => _paddingFocus;
  set paddingFocus(double value) {
    if (_paddingFocus == value) {
      return;
    }
    _paddingFocus = value;
    markNeedsPaint();
  }

  double get radius => _radius;
  set radius(double value) {
    if (_radius == value) {
      return;
    }
    _radius = value;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
  }

  void _notifyHoleRectIfNeeded(Rect hole) {
    if (_holeRect.value == hole) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_holeRect.value != hole) {
        _holeRect.value = hole;
      }
    });
  }

  Rect? _computeHoleRect() {
    final targetContext = _targetKey.currentContext;
    if (targetContext == null || !targetContext.mounted) {
      return null;
    }
    final renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    final topLeft = globalToLocal(renderObject.localToGlobal(Offset.zero));
    return Rect.fromLTWH(
      topLeft.dx - _paddingFocus,
      topLeft.dy - _paddingFocus,
      renderObject.size.width + _paddingFocus * 2,
      renderObject.size.height + _paddingFocus * 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final hole = _computeHoleRect();
    if (hole == null) {
      return;
    }

    DaftarCoachMark.debugHoleRect = hole;
    _notifyHoleRectIfNeeded(hole);

    final canvas = context.canvas;
    final fullRect = offset & size;
    final fullPath = Path()..addRect(fullRect);
    final holeRRect = RRect.fromRectAndRadius(hole, Radius.circular(_radius));
    final holePath = Path()..addRRect(holeRRect);
    final dimPath = Path.combine(PathOperation.difference, fullPath, holePath);

    canvas
      ..drawPath(
        dimPath,
        Paint()
          ..color = _shadowColor.withValues(alpha: _shadowOpacity),
      )
      ..drawRRect(
        holeRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.lapis400
          ..strokeWidth = AppDimensions.dividerThickness,
      );
  }

  @override
  bool hitTestSelf(Offset position) => true;
}

/// Positions the compact tooltip so its center sits on [fabCenterX].
class _FabCoachTooltipAnchor extends SingleChildRenderObjectWidget {
  const _FabCoachTooltipAnchor({
    required this.fabCenterX,
    required super.child,
  });

  final double fabCenterX;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final viewPadding = MediaQuery.paddingOf(context);
    return _RenderFabTipAnchor(
      fabCenterX: fabCenterX,
      insetLeft: AppDimensions.pagePaddingH + viewPadding.left,
      insetRight: AppDimensions.pagePaddingH + viewPadding.right,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderFabTipAnchor renderObject,
  ) {
    final viewPadding = MediaQuery.paddingOf(context);
    renderObject
      ..fabCenterX = fabCenterX
      ..insetLeft = AppDimensions.pagePaddingH + viewPadding.left
      ..insetRight = AppDimensions.pagePaddingH + viewPadding.right;
  }
}

class _RenderFabTipAnchor extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderFabTipAnchor({
    required double fabCenterX,
    required double insetLeft,
    required double insetRight,
  })  : _fabCenterX = fabCenterX,
        _insetLeft = insetLeft,
        _insetRight = insetRight;

  static const double _maxCardWidth = 240;

  double _fabCenterX;
  double _insetLeft;
  double _insetRight;

  double get fabCenterX => _fabCenterX;
  set fabCenterX(double value) {
    if (_fabCenterX == value) {
      return;
    }
    _fabCenterX = value;
    markNeedsLayout();
  }

  double get insetLeft => _insetLeft;
  set insetLeft(double value) {
    if (_insetLeft == value) {
      return;
    }
    _insetLeft = value;
    markNeedsLayout();
  }

  double get insetRight => _insetRight;
  set insetRight(double value) {
    if (_insetRight == value) {
      return;
    }
    _insetRight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size.zero);
      return;
    }

    final availableWidth = constraints.maxWidth - _insetLeft - _insetRight;
    final maxWidth = math.min(_maxCardWidth, availableWidth);
    child.layout(
      BoxConstraints(maxWidth: maxWidth),
      parentUsesSize: true,
    );

    var left = _fabCenterX - child.size.width / 2;
    final maxLeft = constraints.maxWidth - _insetRight - child.size.width;
    if (left < _insetLeft) {
      left = _insetLeft;
    }
    if (left > maxLeft) {
      left = maxLeft;
    }

    (child.parentData! as BoxParentData).offset = Offset(left, 0);
    size = Size(constraints.maxWidth, child.size.height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) {
      final parentData = child.parentData! as BoxParentData;
      context.paintChild(child, offset + parentData.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) {
      return false;
    }
    final parentData = child.parentData! as BoxParentData;
    return result.addWithPaintOffset(
      offset: parentData.offset,
      position: position,
      hitTest: (result, transformed) {
        return child.hitTest(result, position: transformed);
      },
    );
  }
}

/// FAB coach card: title, tap row, hold row, Got it. Not a paragraph.
class DaftarCoachMarkTooltip extends StatelessWidget {
  /// Creates the Khazna tooltip card.
  const DaftarCoachMarkTooltip({
    required this.onGotIt,
    super.key,
  });

  /// Closes the overlay (Got it).
  final VoidCallback onGotIt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final fill = isDark ? AppColors.surface2 : AppColors.surface1Light;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final card = Semantics(
      container: true,
      label: l10n.closingAgentFabTipSemantics,
      child: DecoratedBox(
        key: daftarCoachFabTooltipCardKey,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: isDark ? AppColors.lapis400 : AppColors.lapis500,
            width: AppDimensions.dividerThickness,
          ),
          boxShadow: isDark ? AppGlows.khazaFloat : AppGlows.shadowFloat,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.closingAgentFabTipTitle,
                style: AppTextStyles.titleMedium.copyWith(color: inkPrimary),
              ),
              const Gap(AppDimensions.spacingMd),
              _CoachTipRow(
                icon: Icons.touch_app_rounded,
                label: l10n.closingAgentFabTipTapRow,
                color: inkPrimary,
              ),
              const Gap(AppDimensions.spacingSm),
              _CoachTipRow(
                icon: Icons.pan_tool_outlined,
                label: l10n.closingAgentFabTipHoldRow,
                color: inkSecondary,
              ),
              const Gap(AppDimensions.spacingLg),
              DaftarButton(
                key: daftarCoachFabGotItKey,
                label: l10n.closingAgentFabTipDismiss,
                onPressed: onGotIt,
              ),
            ],
          ),
        ),
      ),
    );

    if (reduceMotion) {
      return card;
    }
    return card
        .animate()
        .fadeIn(
          duration: AppDimensions.animationMedium,
          curve: AppMotion.curveEnter,
        )
        .slideY(
          begin: 0.06,
          duration: AppDimensions.animationMedium,
          curve: AppMotion.curveEnter,
        );
  }
}

class _CoachTipRow extends StatelessWidget {
  const _CoachTipRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppDimensions.iconMedium, color: color),
        const Gap(AppDimensions.spacingSm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: color,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
