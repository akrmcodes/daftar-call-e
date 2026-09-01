import 'dart:math' as math;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/presentation/shared/widgets/daftar_error_sheet.dart';
import 'package:flutter/material.dart';

/// Reusable bottom-sheet surface with premium spacing and keyboard handling.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.child,
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.scrollable = true,
    this.scrollController,
    this.maxHeightFactor = 0.92,
    this.showDragHandle = true,
    this.padding,
  }) : assert(
         maxHeightFactor > 0 && maxHeightFactor <= 1,
         'maxHeightFactor must be between 0 and 1.',
       );

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool scrollable;
  final ScrollController? scrollController;
  final double maxHeightFactor;
  final bool showDragHandle;
  final EdgeInsetsGeometry? padding;

  /// Presents a localized error bottom sheet for [error].
  ///
  /// Workspace limit failures route to the premium upsell sheet instead.
  static Future<void> showError(
    BuildContext context, {
    required Object error,
  }) {
    return DaftarErrorSheet.showForError(context, error: error);
  }

  /// Shows the sheet using the app's preferred modal bottom-sheet defaults.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    bool scrollable = true,
    ScrollController? scrollController,
    double maxHeightFactor = 0.92,
    bool showDragHandle = true,
    EdgeInsetsGeometry? padding,
  }) {
    final theme = context.theme;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: theme.colorScheme.scrim.withValues(alpha: 0.55),
      sheetAnimationStyle: AppMotion.sheetAnimationStyle,
      builder: (context) {
        return AppBottomSheet(
          title: title,
          subtitle: subtitle,
          leading: leading,
          trailing: trailing,
          scrollable: scrollable,
          scrollController: scrollController,
          maxHeightFactor: maxHeightFactor,
          showDragHandle: showDragHandle,
          padding: padding,
          child: child,
        );
      },
    );
  }

  double _estimatedHeaderHeight({required bool hasTitleRow}) {
    var height = 0.0;
    if (showDragHandle) {
      height += AppDimensions.spacingSm + AppDimensions.dragHandleHeight;
    }
    if (hasTitleRow) {
      height += AppDimensions.spacingMd;
      var rowContentHeight = 0.0;
      if (title != null) {
        const style = AppTextStyles.titleLarge;
        rowContentHeight = (style.fontSize ?? 18) * (style.height ?? 1);
      }
      if (subtitle != null) {
        const style = AppTextStyles.bodyMedium;
        rowContentHeight += AppDimensions.spacingXxs +
            (style.fontSize ?? 14) * (style.height ?? 1);
      }
      if (leading != null || trailing != null) {
        rowContentHeight = math.max(
          rowContentHeight,
          AppDimensions.minTapTarget,
        );
      }
      height += rowContentHeight;
      height += AppDimensions.bottomSheetPadding;
    }
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        theme.bottomSheetTheme.backgroundColor ??
        (isDark ? AppColors.surface2 : AppColors.surface1Light);
    final surfaceBorderColor = isDark
        ? AppColors.borderSubtle.withValues(alpha: 0.8)
        : AppColors.borderSubtleLight.withValues(alpha: 0.9);
    final mutedColor = isDark
        ? AppColors.inkMuted
        : AppColors.inkMutedLight;
    final onSurfaceColor = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final sheetPadding =
        padding ??
        const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.pagePaddingH,
          AppDimensions.spacingMd,
          AppDimensions.pagePaddingH,
          AppDimensions.bottomSheetPadding,
        );

    final mediaQuery = MediaQuery.of(context);
    // Shrink the sheet when the keyboard is open so the header stays visible.
    final availableHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom;

    final maxSheetHeight = availableHeight * maxHeightFactor;
    final headerHeight = _estimatedHeaderHeight(
      hasTitleRow: title != null ||
          subtitle != null ||
          leading != null ||
          trailing != null,
    );

    final sheetSurface = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Material(
        color: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: AppDimensions.elevationHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: surfaceBorderColor),
          ),
          child: LayoutBuilder(
            builder: (context, boxConstraints) {
              final bodyMaxHeight = (boxConstraints.maxHeight - headerHeight)
                  .clamp(0.0, double.infinity);
              final body = scrollable
                  ? ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: bodyMaxHeight),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: sheetPadding,
                        child: child,
                      ),
                    )
                  : Padding(
                      padding: sheetPadding,
                      child: child,
                    );

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showDragHandle)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppDimensions.spacingSm,
                      ),
                      child: Center(
                        child: Container(
                          width: AppDimensions.dragHandleWidth,
                          height: AppDimensions.dragHandleHeight,
                          decoration: BoxDecoration(
                            color: mutedColor,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusCircular,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (title != null ||
                      subtitle != null ||
                      leading != null ||
                      trailing != null)
                    Padding(
                      padding: sheetPadding,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (leading != null) ...[
                            leading!,
                            const SizedBox(width: AppDimensions.spacingMd),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (title != null)
                                  Text(
                                    title!,
                                    textAlign: TextAlign.start,
                                    style: AppTextStyles.titleLarge.copyWith(
                                      color: onSurfaceColor,
                                    ),
                                  ),
                                if (subtitle != null) ...[
                                  const SizedBox(
                                    height: AppDimensions.spacingXxs,
                                  ),
                                  Text(
                                    subtitle!,
                                    textAlign: TextAlign.start,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: mutedColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: AppDimensions.spacingSm),
                            trailing!,
                          ],
                        ],
                      ),
                    ),
                  body,
                ],
              );
            },
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: AppDimensions.animationMedium,
        curve: AppMotion.curveSheetEnter,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: sheetSurface,
            ),
          ],
        ),
      ),
    );
  }
}
