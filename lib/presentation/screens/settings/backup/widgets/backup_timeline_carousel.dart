import 'dart:async' show unawaited;
import 'dart:ui' show PointerDeviceKind;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/presentation/screens/premium/widgets/snappy_page_scroll_physics.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_timeline_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Focal-depth horizontal carousel for backup snapshot history.
class BackupTimelineCarousel extends StatefulWidget {
  const BackupTimelineCarousel({
    required this.backups,
    required this.isRestoring,
    required this.onShare,
    required this.onRestore,
    required this.onDelete,
    super.key,
  });

  final List<BackupMetadata> backups;
  final bool isRestoring;
  final void Function(BackupMetadata meta) onShare;
  final void Function(BackupMetadata meta) onRestore;
  final void Function(BackupMetadata meta) onDelete;

  static const double carouselHeight = 200;
  static const double _viewportFraction = 0.82;
  static const double _minScale = 0.88;
  static const double _minOpacity = 0.55;

  @override
  State<BackupTimelineCarousel> createState() => _BackupTimelineCarouselState();
}

class _BackupTimelineCarouselState extends State<BackupTimelineCarousel> {
  late final PageController _controller;
  int _currentIndex = 0;
  int _lastHapticPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      viewportFraction: BackupTimelineCarousel._viewportFraction,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  BackupMetadata get _selected => widget.backups[_currentIndex];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final borderColor =
        isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    if (widget.backups.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppDimensions.pagePaddingH,
            ),
            child: BackupTimelineCard(
              meta: widget.backups.first,
              l10n: l10n,
              isLatest: true,
            ),
          ),
          const Gap(AppDimensions.spacingLg),
          _ActionBar(
            l10n: l10n,
            isRestoring: widget.isRestoring,
            onShare: () => widget.onShare(widget.backups.first),
            onRestore: () => widget.onRestore(widget.backups.first),
            onDelete: () => widget.onDelete(widget.backups.first),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: BackupTimelineCarousel.carouselHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppDimensions.pagePaddingH,
                ),
                child: _TimelineRail(
                  count: widget.backups.length,
                  activeIndex: _currentIndex,
                  borderColor: borderColor,
                  viewportHeight: BackupTimelineCarousel.carouselHeight,
                ),
              ),
              const Gap(AppDimensions.spacingSm),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const _CarouselScrollBehavior(),
                  child: PageView.builder(
                    clipBehavior: Clip.none,
                    controller: _controller,
                    padEnds: false,
                    physics: const BouncingScrollPhysics(
                      parent: SnappyPageScrollPhysics(),
                    ),
                    itemCount: widget.backups.length,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                      if (index != _lastHapticPage) {
                        _lastHapticPage = index;
                        unawaited(HapticService.selection());
                      }
                    },
                    itemBuilder: (context, index) {
                      final meta = widget.backups[index];
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final currentPage = _controller.hasClients
                              ? (_controller.page ??
                                  _controller.initialPage.toDouble())
                              : 0.0;
                          final distance = (currentPage - index).abs();
                          final scale = (1.0 -
                                  distance *
                                      (1.0 -
                                          BackupTimelineCarousel._minScale))
                              .clamp(BackupTimelineCarousel._minScale, 1.0);
                          final opacity = (1.0 -
                                  distance *
                                      (1.0 -
                                          BackupTimelineCarousel._minOpacity))
                              .clamp(BackupTimelineCarousel._minOpacity, 1.0);
                          return Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            end: index == widget.backups.length - 1
                                ? AppDimensions.pagePaddingH
                                : AppDimensions.spacingSm,
                          ),
                          child: BackupTimelineCard(
                            meta: meta,
                            l10n: l10n,
                            isLatest: index == 0,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const Gap(AppDimensions.spacingSm),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.pagePaddingH,
          ),
          child: Text(
            l10n.backupTimelineSwipeHint,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: inkMuted,
              height: 1.35,
            ),
          ),
        ),
        const Gap(AppDimensions.spacingLg),
        _ActionBar(
          l10n: l10n,
          isRestoring: widget.isRestoring,
          onShare: () => widget.onShare(_selected),
          onRestore: () => widget.onRestore(_selected),
          onDelete: () => widget.onDelete(_selected),
        ),
      ],
    );
  }
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({
    required this.count,
    required this.activeIndex,
    required this.borderColor,
    required this.viewportHeight,
  });

  /// Caps rail slots so layout stays O(1) regardless of backup count.
  static const int _maxVisibleDots = 9;

  final int count;
  final int activeIndex;
  final Color borderColor;
  final double viewportHeight;

  List<_RailSlot> get _slots {
    final window = count.clamp(1, _maxVisibleDots);
    if (count <= window) {
      return List.generate(count, (index) {
        return _RailSlot(
          isActive: index == activeIndex,
          isCompressed: false,
          showTopConnector: index > 0,
          showBottomConnector: index < count - 1,
        );
      });
    }

    final half = window ~/ 2;
    var start = activeIndex - half;
    if (start < 0) {
      start = 0;
    }
    if (start + window > count) {
      start = count - window;
    }

    return List.generate(window, (slot) {
      final index = start + slot;
      final atLeadingEdge = slot == 0 && start > 0;
      final atTrailingEdge = slot == window - 1 && start + window < count;
      return _RailSlot(
        isActive: index == activeIndex,
        isCompressed: atLeadingEdge || atTrailingEdge,
        showTopConnector: slot > 0,
        showBottomConnector: slot < window - 1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;

    return SizedBox(
      width: 20,
      height: viewportHeight,
      child: Column(
        children: [
          for (var i = 0; i < slots.length; i++)
            Expanded(
              child: _TimelineRailDot(
                isActive: slots[i].isActive,
                isCompressed: slots[i].isCompressed,
                borderColor: borderColor,
                showTopConnector: slots[i].showTopConnector,
                showBottomConnector: slots[i].showBottomConnector,
              ),
            ),
        ],
      ),
    );
  }
}

class _RailSlot {
  const _RailSlot({
    required this.isActive,
    required this.isCompressed,
    required this.showTopConnector,
    required this.showBottomConnector,
  });

  final bool isActive;
  final bool isCompressed;
  final bool showTopConnector;
  final bool showBottomConnector;
}

class _TimelineRailDot extends StatelessWidget {
  const _TimelineRailDot({
    required this.isActive,
    required this.isCompressed,
    required this.borderColor,
    required this.showTopConnector,
    required this.showBottomConnector,
  });

  final bool isActive;
  final bool isCompressed;
  final Color borderColor;
  final bool showTopConnector;
  final bool showBottomConnector;

  @override
  Widget build(BuildContext context) {
    final dotSize = isActive ? 10.0 : (isCompressed ? 5.0 : 7.0);
    final inactiveAlpha = isCompressed ? 0.35 : 0.6;

    return Column(
      children: [
        if (showTopConnector)
          Expanded(
            child: Container(
              width: 0.5,
              color: borderColor,
            ),
          )
        else
          const Spacer(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppColors.payment
                : borderColor.withValues(alpha: inactiveAlpha),
            border: Border.all(
              color: isActive ? AppColors.payment : borderColor,
              width: 0.5,
            ),
          ),
        ),
        if (showBottomConnector)
          Expanded(
            child: Container(
              width: 0.5,
              color: borderColor,
            ),
          )
        else
          const Spacer(),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.l10n,
    required this.isRestoring,
    required this.onShare,
    required this.onRestore,
    required this.onDelete,
  });

  final AppLocalizations l10n;
  final bool isRestoring;
  final VoidCallback onShare;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppDimensions.pagePaddingH,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DaftarButton(
                  label: l10n.backupShare,
                  icon: Icons.share_rounded,
                  variant: DaftarButtonVariant.tertiary,
                  size: DaftarButtonSize.small,
                  isExpanded: true,
                  onPressed: onShare,
                ),
              ),
              const Gap(AppDimensions.spacingSm),
              Expanded(
                child: DaftarButton(
                  label: l10n.backupRestore,
                  icon: Icons.restore_rounded,
                  variant: DaftarButtonVariant.secondary,
                  size: DaftarButtonSize.small,
                  isExpanded: true,
                  onPressed: isRestoring ? null : onRestore,
                ),
              ),
            ],
          ),
          const Gap(AppDimensions.spacingSm),
          DaftarButton(
            label: l10n.backupDelete,
            icon: Icons.delete_outline_rounded,
            variant: DaftarButtonVariant.destructiveOutlined,
            size: DaftarButtonSize.small,
            isExpanded: true,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _CarouselScrollBehavior extends MaterialScrollBehavior {
  const _CarouselScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
