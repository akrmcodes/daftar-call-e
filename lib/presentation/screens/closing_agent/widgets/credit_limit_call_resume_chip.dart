import 'dart:async' show unawaited;

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/providers/closing_agent_controller.dart';
import 'package:daftar/presentation/shared/widgets/khazna_specular_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Monochrome resume chip with lapis glow edge for an active credit-limit call.
class CreditLimitCallResumeChip extends ConsumerWidget {
  /// Creates the chip.
  ///
  /// When [contactId] is set, the chip appears only when the session targets
  /// that contact (contact detail). On home, omit [contactId].
  const CreditLimitCallResumeChip({
    this.contactId,
    super.key,
  });

  /// Optional contact filter for contact-detail placement.
  final String? contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(closingAgentControllerProvider);
    if (!state.isCreditLimitCallSessionActive) {
      return const SizedBox.shrink();
    }
    if (contactId != null && state.creditLimitSessionContactId != contactId) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final label = state.creditLimitCallSessionTerminal
        ? l10n.creditLimitCallSessionViewCall
        : l10n.creditLimitCallSessionResumeChip;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppDimensions.pagePaddingH,
      ),
      child: Align(
        alignment: AlignmentDirectional.center,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
            boxShadow: const [AppGlows.glowSm],
          ),
          child: KhaznaSpecularPanel(
            shape: KhaznaSpecularPanelShape.pill,
            onTap: () {
              unawaited(HapticService.selection());
              unawaited(context.pushNamed(RouteNames.closingAgent));
            },
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: AppDimensions.spacingXs + 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone_in_talk_outlined,
                  size: AppDimensions.iconSmall,
                  color: ink,
                ),
                const Gap(AppDimensions.spacingXs),
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: ink,
                    letterSpacing: 0.2,
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
