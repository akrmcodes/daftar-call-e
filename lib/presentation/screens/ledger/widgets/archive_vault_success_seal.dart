import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ArchiveVaultSuccessSeal extends StatefulWidget {
  const ArchiveVaultSuccessSeal({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  State<ArchiveVaultSuccessSeal> createState() => _ArchiveVaultSuccessSealState();
}

class _ArchiveVaultSuccessSealState extends State<ArchiveVaultSuccessSeal>
    with SingleTickerProviderStateMixin {
  static const Duration _holdBeforeMorph = Duration(milliseconds: 400);
  static const Duration _morphDuration = Duration(milliseconds: 420);

  late final AnimationController _morphController;
  late final Animation<double> _morphCurve;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: _morphDuration,
    );
    _morphCurve = CurvedAnimation(
      parent: _morphController,
      curve: AppMotion.curveEmphasized,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (MediaQuery.disableAnimationsOf(context)) {
        _morphController.value = 1;
        unawaited(HapticService.heavy());
        return;
      }
      unawaited(
        Future<void>.delayed(_holdBeforeMorph, () {
          if (!mounted) {
            return;
          }
          unawaited(_morphController.forward());
          unawaited(HapticService.heavy());
        }),
      );
    });
  }

  @override
  void dispose() {
    _morphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: AppGlows.heroBrand,
                  ),
                ),
                AnimatedBuilder(
                  animation: _morphCurve,
                  builder: (context, _) {
                    final t = reduceMotion ? 1.0 : _morphCurve.value;
                    final lockOpacity = Curves.easeIn.transform(1 - t);
                    final verifiedOpacity = Curves.easeOut.transform(t);
                    final lockScale = 1.0 - (0.06 * t);
                    final verifiedScale = 0.9 + (0.1 * t);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: lockOpacity,
                          child: Transform.scale(
                            scale: lockScale,
                            child: Icon(
                              Icons.lock_clock_rounded,
                              size: 64,
                              color: inkPrimary,
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: verifiedOpacity,
                          child: Transform.scale(
                            scale: verifiedScale,
                            child: Icon(
                              Icons.verified_user_outlined,
                              size: 64,
                              color: inkPrimary,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const Gap(AppDimensions.spacingXl),
          AnimatedBuilder(
            animation: _morphCurve,
            builder: (context, _) {
              final textOpacity = reduceMotion
                  ? 1.0
                  : Curves.easeOut.transform(
                      ((_morphCurve.value - 0.15) / 0.85).clamp(0.0, 1.0),
                    );

              return Opacity(
                opacity: textOpacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: inkPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(AppDimensions.spacingSm),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: inkSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
