import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

/// Khazna vault success seal — heroBrand halo + lock-to-checkmark morph.
class BackupVaultSuccessSeal extends StatefulWidget {
  const BackupVaultSuccessSeal({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  State<BackupVaultSuccessSeal> createState() => _BackupVaultSuccessSealState();
}

class _BackupVaultSuccessSealState extends State<BackupVaultSuccessSeal> {
  bool _showVerified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        setState(() => _showVerified = true);
        unawaited(HapticService.heavy());
        return;
      }
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 320), () {
          if (!mounted) return;
          setState(() => _showVerified = true);
          unawaited(HapticService.heavy());
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final icon = _showVerified
        ? Icons.verified_user_outlined
        : Icons.lock_outline_rounded;

    final glow = reduceMotion
        ? Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppGlows.heroBrand,
            ),
          )
        : Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppGlows.heroBrand,
            ),
          )
            .animate(onPlay: (c) => c.repeat())
            .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.08, 1.08),
              duration: 1600.ms,
              curve: Curves.easeInOut,
            );

    final iconWidget = AnimatedSwitcher(
      duration:
          reduceMotion ? Duration.zero : AppDimensions.animationMedium,
      switchInCurve: Curves.easeOutBack,
      child: Icon(
        icon,
        key: ValueKey<bool>(_showVerified),
        size: 72,
        color: inkPrimary,
      ),
    )
        .animate(autoPlay: !reduceMotion)
        .scale(
          begin: const Offset(0.3, 0.3),
          end: const Offset(1, 1),
          duration: 650.ms,
          curve: Curves.easeOutBack,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 180,
          height: 112,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              glow,
              iconWidget,
            ],
          ),
        ),
        const Gap(AppDimensions.spacingLg),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: AppTextStyles.titleLarge.copyWith(
            color: inkPrimary,
            fontWeight: FontWeight.w800,
          ),
        )
            .animate(autoPlay: !reduceMotion)
            .fadeIn(delay: 200.ms, duration: 300.ms),
        const Gap(AppDimensions.spacingXs),
        Text(
          widget.subtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: inkSecondary,
            height: 1.45,
          ),
        )
            .animate(autoPlay: !reduceMotion)
            .fadeIn(delay: 350.ms, duration: 300.ms),
      ],
    );
  }
}
