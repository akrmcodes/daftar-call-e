import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/presentation/screens/premium/widgets/plan_tier_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

/// Vertical stack of Free / Pro / Pro+ plan cards.
class PlanTierStack extends StatelessWidget {
  const PlanTierStack({
    required this.selectedTier,
    required this.currentTier,
    required this.codeFieldFocused,
    required this.onTierSelected,
    required this.onTierCta,
    super.key,
  });

  final AppTier selectedTier;
  final AppTier currentTier;

  /// When true, card CTAs demote so the activation panel owns the sole glow.
  final bool codeFieldFocused;
  final ValueChanged<AppTier> onTierSelected;
  final ValueChanged<AppTier> onTierCta;

  static const List<AppTier> _order = [
    AppTier.free,
    AppTier.pro,
    AppTier.proPlus,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _order.length; i++) ...[
          if (i > 0) const Gap(AppDimensions.spacingMd),
          PlanTierCard(
            tier: _order[i],
            isSelected: selectedTier == _order[i],
            isCurrentPlan: currentTier == _order[i],
            isRecommended:
                currentTier == AppTier.free && _order[i] == AppTier.pro,
            emphasizeCta: !codeFieldFocused &&
                selectedTier == _order[i] &&
                _order[i] != AppTier.free &&
                currentTier != _order[i],
            onSelect: () => onTierSelected(_order[i]),
            onCtaPressed: () => onTierCta(_order[i]),
          )
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: 40 + i * 50),
                duration: 350.ms,
              )
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
        ],
      ],
    );
  }
}
