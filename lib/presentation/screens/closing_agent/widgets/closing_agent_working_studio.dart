import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_vault_seal.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Ceremonial wait while the Closing Agent turn is in flight.
class ClosingAgentWorkingStudio extends StatefulWidget {
  const ClosingAgentWorkingStudio({
    required this.isDark,
    this.paddingBottom = 0,
    super.key,
  });

  final bool isDark;
  final double paddingBottom;

  @override
  State<ClosingAgentWorkingStudio> createState() =>
      _ClosingAgentWorkingStudioState();
}

class _ClosingAgentWorkingStudioState extends State<ClosingAgentWorkingStudio> {
  bool _hapticFired = false;

  @override
  Widget build(BuildContext context) {
    if (!_hapticFired) {
      _hapticFired = true;
      unawaited(HapticService.light());
    }

    final l10n = AppLocalizations.of(context)!;
    final inkPrimary = widget.isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppDimensions.pagePaddingH,
            ),
            child: FadeSlideTransition(
              curve: AppMotion.curveBreath,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ClosingAgentVaultSeal(
                    mode: ClosingAgentVaultSealMode.working,
                  ),
                  const Gap(AppDimensions.spacingLg),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.closingAgentSpeakWorking,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: inkPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.paddingBottom > 0)
          SliverToBoxAdapter(child: SizedBox(height: widget.paddingBottom)),
      ],
    );
  }
}
