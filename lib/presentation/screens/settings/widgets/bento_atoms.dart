import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Circular status ring — visual metaphor for backup health.
///
/// Renders a thin arc ring (similar to Apple Fitness rings).
/// Progress values:
/// - 0.0 → no backup (empty, warning color)
/// - 0.0–1.0 → partial (animates in on mount)
/// - 1.0 → fully backed up (payment / success green)
///
/// The ring is painted via [CustomPainter] for pixel-exact control.
/// A subtle inner text badge displays the status label.
class BackupStatusRing extends StatefulWidget {
  const BackupStatusRing({
    required this.progress,
    required this.statusLabel,
    required this.statusColor,
    super.key,
    this.size = 72,
    this.strokeWidth = 6,
  });

  /// 0.0 to 1.0 fill level.
  final double progress;

  /// Short label shown in the ring center (e.g., "OK", "!").
  final String statusLabel;

  /// Ring fill color — semantic: [AppColors.payment] or [AppColors.warning].
  final Color statusColor;

  final double size;
  final double strokeWidth;

  @override
  State<BackupStatusRing> createState() => _BackupStatusRingState();
}

class _BackupStatusRingState extends State<BackupStatusRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppDimensions.animationXSlow,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)
        .drive(Tween(begin: 0, end: widget.progress));
    unawaited(_ctrl.forward());
  }

  @override
  void didUpdateWidget(BackupStatusRing old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)
          .drive(Tween(begin: _anim.value, end: widget.progress));
      _ctrl.reset();
      unawaited(_ctrl.forward());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor =
        isDark ? AppColors.surface4 : AppColors.surface3Light;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: _anim.value,
              fillColor: widget.statusColor,
              trackColor: trackColor,
              strokeWidth: widget.strokeWidth,
            ),
            child: Center(
              child: Text(
                widget.statusLabel,
                style: AppTextStyles.amountMicro.copyWith(
                  color: widget.statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.fillColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color fillColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -1.5708; // -π/2 (12 o'clock)

    // Track ring
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      6.2832, // 2π
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    // Fill arc — radiates a faint glow via mask filter
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      6.2832 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = fillColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 0.5),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor;
}

/// Dual health rings — inner arc = local backup, outer arc = cloud sync.
///
/// Progress values:
/// - [localProgress]: 0.0 (none) → 1.0 (backed up locally)
/// - [cloudProgress]: 0.0 (none) → 0.5 (signed in, not synced) → 1.0 (synced)
class VaultHealthRings extends StatefulWidget {
  const VaultHealthRings({
    required this.localProgress,
    required this.cloudProgress,
    required this.localColor,
    required this.cloudColor,
    required this.centerLabel,
    required this.centerColor,
    super.key,
    this.size = 96,
    this.outerStrokeWidth = 5,
    this.innerStrokeWidth = 5,
    this.showLegend = false,
    this.localLegend,
    this.cloudLegend,
  });

  final double localProgress;
  final double cloudProgress;
  final Color localColor;
  final Color cloudColor;
  final String centerLabel;
  final Color centerColor;
  final double size;
  final double outerStrokeWidth;
  final double innerStrokeWidth;
  final bool showLegend;
  final String? localLegend;
  final String? cloudLegend;

  @override
  State<VaultHealthRings> createState() => _VaultHealthRingsState();
}

class _VaultHealthRingsState extends State<VaultHealthRings>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _localAnim;
  late Animation<double> _cloudAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppDimensions.animationXSlow,
    );
    _localAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)
        .drive(Tween(begin: 0, end: widget.localProgress));
    _cloudAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)
        .drive(Tween(begin: 0, end: widget.cloudProgress));
    unawaited(_ctrl.forward());
  }

  @override
  void didUpdateWidget(VaultHealthRings old) {
    super.didUpdateWidget(old);
    if (old.localProgress != widget.localProgress ||
        old.cloudProgress != widget.cloudProgress) {
      _localAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)
          .drive(
        Tween(begin: _localAnim.value, end: widget.localProgress),
      );
      _cloudAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)
          .drive(
        Tween(begin: _cloudAnim.value, end: widget.cloudProgress),
      );
      _ctrl.reset();
      unawaited(_ctrl.forward());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor =
        isDark ? AppColors.surface4 : AppColors.surface3Light;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _DualRingPainter(
                  outerProgress: _cloudAnim.value,
                  innerProgress: _localAnim.value,
                  outerColor: widget.cloudColor,
                  innerColor: widget.localColor,
                  trackColor: trackColor,
                  outerStrokeWidth: widget.outerStrokeWidth,
                  innerStrokeWidth: widget.innerStrokeWidth,
                ),
                child: Center(
                  child: Text(
                    widget.centerLabel,
                    style: AppTextStyles.amountMicro.copyWith(
                      color: widget.centerColor,
                      fontWeight: FontWeight.w700,
                      fontSize: widget.size > 60 ? 14 : 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.showLegend &&
            widget.localLegend != null &&
            widget.cloudLegend != null) ...[
          const Gap(AppDimensions.spacingSm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LegendDot(color: widget.localColor, label: widget.localLegend!),
              const Gap(AppDimensions.spacingMd),
              _LegendDot(color: widget.cloudColor, label: widget.cloudLegend!),
            ],
          ),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const Gap(4),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: inkMuted),
        ),
      ],
    );
  }
}

class _DualRingPainter extends CustomPainter {
  const _DualRingPainter({
    required this.outerProgress,
    required this.innerProgress,
    required this.outerColor,
    required this.innerColor,
    required this.trackColor,
    required this.outerStrokeWidth,
    required this.innerStrokeWidth,
  });

  final double outerProgress;
  final double innerProgress;
  final Color outerColor;
  final Color innerColor;
  final Color trackColor;
  final double outerStrokeWidth;
  final double innerStrokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const startAngle = -1.5708;

    final outerRadius = (size.width - outerStrokeWidth) / 2;
    final innerRadius = outerRadius - outerStrokeWidth - 4;

    void drawTrack(double radius, double stroke) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        6.2832,
        false,
        Paint()
          ..color = trackColor
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    void drawArc(
      double radius,
      double stroke,
      double progress,
      Color color,
    ) {
      if (progress <= 0) return;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        6.2832 * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 0.5),
      );
    }

    drawTrack(outerRadius, outerStrokeWidth);
    drawTrack(innerRadius, innerStrokeWidth);
    drawArc(outerRadius, outerStrokeWidth, outerProgress, outerColor);
    drawArc(innerRadius, innerStrokeWidth, innerProgress, innerColor);
  }

  @override
  bool shouldRepaint(_DualRingPainter old) =>
      old.outerProgress != outerProgress ||
      old.innerProgress != innerProgress ||
      old.outerColor != outerColor ||
      old.innerColor != innerColor;
}

/// Compact stats badge — used inside the Merchant Identity card.
class BentoStatBadge extends StatelessWidget {
  const BentoStatBadge({
    required this.value,
    required this.label,
    super.key,
    this.valueColor,
  });

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTextStyles.amountMedium.copyWith(
            color: valueColor ?? inkPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(2),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: inkMuted,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Pill-shaped theme segment (Light / System / Dark).
///
/// Active state includes a micro icon-bounce and a whisper-thin lapis glow.
class ThemeSegmentPill extends StatelessWidget {
  const ThemeSegmentPill({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDimensions.animationMedium,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingSm,
            vertical: AppDimensions.spacingSm,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? AppColors.surface4 : AppColors.surface2Light)
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusSm),
            border: isActive
                ? Border.all(
                    color: AppColors.lapis400.withValues(alpha: 0.3),
                    width: AppDimensions.dividerThickness,
                  )
                : null,
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x1A0356C5),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isActive ? 1.15 : 1.0,
                duration: AppDimensions.animationMedium,
                curve: isActive ? Curves.elasticOut : Curves.easeOutCubic,
                child: Icon(
                  icon,
                  size: AppDimensions.iconSmall + 2,
                  color: isActive ? inkPrimary : inkSecondary,
                ),
              ),
              const Gap(3),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: isActive ? inkPrimary : inkSecondary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal utility dock item — icon + label, tappable.
class UtilityDockItem extends StatefulWidget {
  const UtilityDockItem({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
    this.sublabel,
    this.trailingWidget,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;
  final Widget? trailingWidget;

  @override
  State<UtilityDockItem> createState() => _UtilityDockItemState();
}

class _UtilityDockItemState extends State<UtilityDockItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        unawaited(HapticService.buttonPress());
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: AppDimensions.animationFast,
        curve: Curves.easeOutCubic,
        color: _pressed
            ? (isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02))
            : Colors.transparent,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: AppDimensions.spacingMd,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: AppDimensions.iconSmall + 2,
                  color: inkSecondary,
                ),
                const Gap(AppDimensions.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.label,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: inkPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.sublabel != null) ...[
                        const Gap(2),
                        Text(
                          widget.sublabel!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: inkSecondary.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.trailingWidget != null)
                  widget.trailingWidget!
                else
                  AnimatedSlide(
                    offset: Offset(_pressed ? 0.15 : 0, 0),
                    duration: AppDimensions.animationFast,
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      size: AppDimensions.iconMedium,
                      color: inkSecondary.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
