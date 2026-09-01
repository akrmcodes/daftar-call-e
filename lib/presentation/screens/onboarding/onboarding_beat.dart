import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Ordered beats of the contest onboarding spine.
enum OnboardingBeat {
  hero,
  language,
  look,
  store,
  google,
  pro,
  ledger,
}

/// Entrance motion that is a no-op when reduce-motion is on.
class OnboardingBeatMotion extends StatelessWidget {
  const OnboardingBeatMotion({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return FadeSlideTransition(child: child);
  }
}

/// Keyboard-safe scroll shell for every onboarding beat.
class OnboardingBeatFrame extends StatelessWidget {
  const OnboardingBeatFrame({
    required this.child,
    this.centerWhenShort = false,
    super.key,
  });

  final Widget child;
  final bool centerWhenShort;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final topInset = MediaQuery.viewInsetsOf(context).top;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.only(
            start: AppDimensions.spacingXl,
            end: AppDimensions.spacingXl,
            top: topInset > 0 ? AppDimensions.spacingLg : AppDimensions.spacing3xl,
            bottom: AppDimensions.spacingXxl + bottomInset,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: centerWhenShort
                ? Center(child: child)
                : child,
          ),
        );
      },
    );
  }
}

/// Icon chip + title + optional subtitle for onboarding beats.
class OnboardingBeatHeader extends StatelessWidget {
  const OnboardingBeatHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final chipFill = isDark ? AppColors.surface2 : AppColors.surface1Light;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppGlows.haloXs,
            ),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: chipFill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.lapis400,
                  width: AppDimensions.dividerThickness,
                ),
              ),
              child: Icon(
                icon,
                size: AppDimensions.iconMedium,
                color: inkPrimary,
              ),
            ),
          ),
        ),
        Gap(
          keyboardOpen ? AppDimensions.spacingLg : AppDimensions.spacingXxl,
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineMedium.copyWith(color: inkPrimary),
        ),
        if (subtitle != null) ...[
          const Gap(AppDimensions.spacingMd),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: inkMuted,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact icon + text row for trust / feature lines on onboarding beats.
class OnboardingBeatLine extends StatelessWidget {
  const OnboardingBeatLine({
    required this.icon,
    required this.text,
    super.key,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: ink),
        const Gap(AppDimensions.spacingSm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(color: ink, height: 1.45),
          ),
        ),
      ],
    );
  }
}
