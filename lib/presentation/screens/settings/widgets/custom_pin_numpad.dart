import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:flutter/material.dart';

/// Luxury circular numpad for PIN entry (digits always LTR).
///
/// Sizes keys from [LayoutBuilder] constraints so the pad never overflows
/// small bottom sheets or short phones.
class CustomPinNumpad extends StatelessWidget {
  const CustomPinNumpad({
    required this.onDigit,
    required this.onBackspace,
    super.key,
    this.maxHeight,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Optional cap for total numpad height (e.g. inside a bottom sheet).
  final double? maxHeight;

  static const _keys = <String>[
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '',
    '0',
    'back',
  ];

  static const _rowCount = 4;
  static const _columnCount = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final digitColor =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final keySurface =
        isDark ? AppColors.surface3 : AppColors.surface2Light;
    final accent = theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width -
                AppDimensions.pagePaddingH * 2;
        final heightBudget = maxHeight ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : 320);

        final spacing = heightBudget < 260
            ? AppDimensions.spacingXs
            : AppDimensions.spacingSm;
        final cellWidth =
            (width - spacing * (_columnCount - 1)) / _columnCount;
        final cellHeight = math.max(
          AppDimensions.minTapTarget,
          math.min(
            cellWidth * 0.92,
            (heightBudget - spacing * (_rowCount - 1)) / _rowCount,
          ),
        );
        final padHeight =
            cellHeight * _rowCount + spacing * (_rowCount - 1);

        return Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: padHeight,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columnCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                mainAxisExtent: cellHeight,
              ),
              itemCount: _keys.length,
              itemBuilder: (context, index) {
                final key = _keys[index];
                if (key.isEmpty) {
                  return const SizedBox.shrink();
                }

                if (key == 'back') {
                  return _NumpadKey(
                    onPressed: () {
                      unawaited(HapticService.amountPadDelete());
                      onBackspace();
                    },
                    child: Icon(
                      Icons.backspace_outlined,
                      color: digitColor.withValues(alpha: 0.85),
                      size: math.min(26, cellHeight * 0.38),
                    ),
                  );
                }

                return _NumpadKey(
                  onPressed: () {
                    unawaited(HapticService.pinPress());
                    onDigit(key);
                  },
                  backgroundColor: keySurface,
                  borderColor: accent.withValues(alpha: 0.12),
                  child: Text(
                    key,
                    style: AppTextStyles.amountMedium.copyWith(
                      fontFamily: AppTextStyles.latinFontFamily,
                      color: digitColor,
                      fontWeight: FontWeight.w600,
                      fontSize: math.min(28, cellHeight * 0.42),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _NumpadKey extends StatelessWidget {
  const _NumpadKey({
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.borderColor,
  });

  final VoidCallback onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fill = backgroundColor ??
        (isDark ? AppColors.surface5 : AppColors.surface1Light);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.18),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 0.5)
                : null,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
