import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Closing-plan checklist with confirm-state + journal (no Drive).
class AgentPlanChecklist extends StatelessWidget {
  /// Creates the plan checklist.
  const AgentPlanChecklist({
    required this.steps,
    required this.isConfirming,
    required this.confirmIsPrimary,
    required this.onConfirm,
    required this.onSkip,
    super.key,
  });

  /// Plan steps from `propose_closing_plan`.
  final List<ClosingPlanStep> steps;

  /// When true, confirm shows a spinner.
  final bool isConfirming;

  /// When true, confirm owns the lapis glow.
  final bool confirmIsPrimary;

  /// Confirms the plan (journal only).
  final VoidCallback onConfirm;

  /// Skips without journaling.
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final checkColor = isDark ? AppColors.payment : AppColors.paymentLight;

    return RepaintBoundary(
      child: DaftarCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.closingAgentPlanTitle,
              style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
            ),
            const Gap(AppDimensions.spacingXs),
            Text(
              l10n.closingAgentPlanSendSplit,
              style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
            ),
            const Gap(AppDimensions.spacingXs),
            Text(
              l10n.closingAgentPlanDeviceRuns,
              style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
            ),
            const Gap(AppDimensions.spacingMd),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final step = steps[index];
                final delay = Duration(
                  milliseconds: index < 8 ? index * 30 : 0,
                );
                return FadeSlideTransition(
                  delay: delay,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: AppDimensions.spacingSm,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: AppDimensions.iconMedium,
                          color: checkColor,
                        ),
                        const Gap(AppDimensions.spacingSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.title,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: inkPrimary,
                                ),
                              ),
                              if (step.notes != null &&
                                  step.notes!.trim().isNotEmpty)
                                Text(
                                  step.notes!.trim(),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: inkSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Gap(AppDimensions.spacingMd),
            DaftarButton(
              label: l10n.closingAgentConfirmPlan,
              variant: confirmIsPrimary
                  ? DaftarButtonVariant.primary
                  : DaftarButtonVariant.secondary,
              isExpanded: true,
              isLoading: isConfirming,
              onPressed: isConfirming ? null : onConfirm,
            ),
            const Gap(AppDimensions.spacingSm),
            DaftarButton(
              label: l10n.closingAgentSkip,
              variant: DaftarButtonVariant.tertiary,
              isExpanded: true,
              onPressed: isConfirming ? null : onSkip,
            ),
          ],
        ),
      ),
    );
  }
}
