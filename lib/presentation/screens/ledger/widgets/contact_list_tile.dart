import 'dart:async' show unawaited;
import 'dart:ui' as ui;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/presentation/shared/widgets/list_tile_action_menu.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
/// Squircle geometry for individual account cards.
///
/// Uses `radiusMd` (12dp) with iOS-continuous smoothing — the same
/// parameterization as the home screen ledger tiles.
SmoothBorderRadius get _contactTileSquircleRadius => SmoothBorderRadius(
  cornerRadius: AppDimensions.radiusMd,
  cornerSmoothing: 0.6,
);

/// Private-banking account card for the ledger contact list.
///
/// **Visual architecture:** flat surface fill with borderSubtle and optional
/// listTileEdge micro-shadow — no live blur in scroll lists.
///
/// **Avatar removed** — the monogram initials were causing premature name
/// truncation by consuming 48+12 = 60dp of horizontal space. The minimalist
/// revision reclaims this for the account name, which now has the full
/// `Expanded` width to breathe. This follows the Stripe/Mercury pattern
/// where data density is prioritized over decorative avatars.
///
/// **Interaction model:**
///   - Press: `AnimatedScale` to 0.98 + `HapticService.light()`
///   - Release: spring back via `easeOutBack`
///   - Ripple/splash: disabled entirely — scale is the only feedback
class ContactListTile extends StatefulWidget {
  const ContactListTile({
    required this.contact,
    required this.netBalance,
    required this.currencyCode,
    required this.transactionsCount,
    required this.onTap,
    required this.onDismissed,
    this.swipeEnabled = false,
    this.onEdit,
    this.onDelete,
    this.confirmDelete,
    this.enableHero = true,
    super.key,
  });

  final Contact contact;
  final int netBalance;
  final String currencyCode;
  final int transactionsCount;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final bool swipeEnabled;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Future<bool> Function()? confirmDelete;
  final bool enableHero;

  @override
  State<ContactListTile> createState() => _ContactListTileState();
}

class _ContactListTileState extends State<ContactListTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final squircleRadius = _contactTileSquircleRadius;

    // ── Balance semantics ──
    final balanceColor = widget.netBalance == 0
        ? (isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight)
        : widget.netBalance > 0
            ? (isDark ? AppColors.payment : AppColors.paymentLight)
            : (isDark ? AppColors.debt : AppColors.debtLight);

    final balanceMagnitude = MoneyUtil.formatMinorUnitsForCode(
      widget.netBalance.abs(),
      widget.currencyCode,
    );
    final balanceText = widget.netBalance > 0
        ? '+$balanceMagnitude'
        : widget.netBalance < 0
            ? '-$balanceMagnitude'
            : balanceMagnitude;
    final transactionsText = l10n.transactionsCount(widget.transactionsCount);

    // ── Dismiss direction (RTL-aware) ──
    final isRtl = Directionality.of(context) == ui.TextDirection.rtl;
    final dismissDirection =
        isRtl ? DismissDirection.startToEnd : DismissDirection.endToStart;

    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _pressed = true);
        unawaited(HapticService.light());
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: AppDimensions.animationFast,
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: isDark ? AppColors.surface2 : AppColors.surface1Light,
            shape: SmoothRectangleBorder(
              borderRadius: squircleRadius,
              side: BorderSide(
                color: isDark
                    ? AppColors.borderSubtle
                    : AppColors.borderSubtleLight,
                width: AppDimensions.dividerThickness,
              ),
            ),
            shadows: AppGlows.listTileEdge,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
                      // ── Inner top highlight (Khazna Float, dark only) ──
                      if (isDark)
                        const PositionedDirectional(
                          top: 0,
                          start: 0,
                          end: 0,
                          child: SizedBox(
                            height: AppDimensions.dividerThickness,
                            child: ColoredBox(
                              color: AppColors.innerTopHighlight,
                            ),
                          ),
                        ),

                      // ── Content row (no avatar — maximized name space) ──
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppDimensions.listTilePaddingH,
                          AppDimensions.listTilePaddingV,
                          AppDimensions.listTilePaddingH,
                          AppDimensions.listTilePaddingV,
                        ),
                        child: Row(
                          children: [
                            // ── Name + metadata column ──
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ContactNameLabel(
                                    contactId: widget.contact.id,
                                    name: widget.contact.name,
                                    isDark: isDark,
                                    enableHero: widget.enableHero,
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacingXs,
                                  ),
                                  Text(
                                    transactionsText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        AppTextStyles.bodySmall.copyWith(
                                      color: isDark
                                          ? AppColors.inkMuted
                                          : AppColors.inkMutedLight,
                                      fontFamily:
                                          AppTextStyles.latinFontFamily,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacingMd),

                            // ── Balance badge ──
                            _BalancePill(
                              balanceText: balanceText,
                              balanceColor: balanceColor,
                              isDark: isDark,
                              isNeutral: widget.netBalance == 0,
                            ),

                            if (widget.onEdit != null ||
                                widget.onDelete != null)
                              ListTileActionMenu(
                                menuSemanticsLabel: l10n.editContact,
                                isDark: isDark,
                                onEdit: widget.onEdit,
                                onDelete: widget.onDelete,
                              ),

                            // ── Chevron ──
                            Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(
                                start: AppDimensions.spacingXxs,
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: AppDimensions.iconMedium - 4,
                                color: isDark
                                    ? AppColors.inkDisabled
                                    : AppColors.inkDisabledLight,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Semantic accent stripe (trailing edge) ──
                      if (widget.netBalance != 0)
                        PositionedDirectional(
                          top: 0,
                          bottom: 0,
                          end: 0,
                          child: _SemanticAccentStripe(
                            color: balanceColor,
                            isDark: isDark,
                          ),
                        ),
                    ],
                  ),
        ),
      ),
    );

    final clipped = ClipSmoothRect(
      radius: squircleRadius,
      child: widget.swipeEnabled
          ? Dismissible(
              key: ValueKey<String>('contact-dismiss-${widget.contact.id}'),
              direction: dismissDirection,
              background: _DismissDeleteBackground(
                alignment: AlignmentDirectional.centerStart,
                label: l10n.delete,
              ),
              secondaryBackground: _DismissDeleteBackground(
                alignment: AlignmentDirectional.centerEnd,
                label: l10n.delete,
              ),
              confirmDismiss: (_) async {
                final confirm = widget.confirmDelete;
                if (confirm == null) {
                  return false;
                }
                return confirm();
              },
              onDismissed: (_) => widget.onDismissed(),
              child: card,
            )
          : card,
    );

    return Semantics(
      button: true,
      label: _semanticLabel(
        name: widget.contact.name,
        transactionsText: transactionsText,
        balanceText: balanceText,
      ),
      child: clipped,
    );
  }
}

// =============================================================================
// _BalancePill — financial amount badge with semantic tinting
// =============================================================================

/// Capsule-shaped badge displaying the net balance with semantic coloring.
///
/// - **Debt (negative):** faint red tint background + red text
/// - **Payment (positive):** faint green tint background + green text
/// - **Neutral (zero):** plain monochrome surface + muted text
///
/// Uses `amountSmall` (Inter, tabular figures) for monetary consistency.
class _BalancePill extends StatelessWidget {
  const _BalancePill({
    required this.balanceText,
    required this.balanceColor,
    required this.isDark,
    required this.isNeutral,
  });

  final String balanceText;
  final Color balanceColor;
  final bool isDark;
  final bool isNeutral;

  @override
  Widget build(BuildContext context) {
    // Semantic tint: very faint color wash behind the amount.
    final pillBackground = isNeutral
        ? (isDark
            ? AppColors.surface4.withValues(alpha: 0.5)
            : AppColors.surface2Light)
        : balanceColor.withValues(alpha: isDark ? 0.10 : 0.08);

    final pillBorder = isNeutral
        ? (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight)
        : balanceColor.withValues(alpha: isDark ? 0.18 : 0.14);

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingXs + 2,
      ),
      constraints: const BoxConstraints(minWidth: 80),
      decoration: ShapeDecoration(
        color: pillBackground,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: AppDimensions.radiusSm,
            cornerSmoothing: 0.6,
          ),
          side: BorderSide(
            color: pillBorder,
            width: AppDimensions.dividerThickness,
          ),
        ),
      ),
      child: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            balanceText,
            maxLines: 1,
            textAlign: TextAlign.end,
            style: AppTextStyles.amountSmall.copyWith(
              color: balanceColor,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _SemanticAccentStripe — trailing edge color accent
// =============================================================================

/// A 2dp vertical stripe at the trailing edge of the card that provides
/// instant at-a-glance balance polarity recognition.
///
/// Emits a micro-glow outward (startward) for depth.
class _SemanticAccentStripe extends StatelessWidget {
  const _SemanticAccentStripe({
    required this.color,
    required this.isDark,
  });

  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.70 : 0.55),
          borderRadius: const BorderRadiusDirectional.only(
            topEnd: Radius.circular(AppDimensions.radiusMd),
            bottomEnd: Radius.circular(AppDimensions.radiusMd),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _DismissDeleteBackground — swipe-to-delete backdrop
// =============================================================================

/// Full-width dismiss background with semantic error color and squircle clip.
class _DismissDeleteBackground extends StatelessWidget {
  const _DismissDeleteBackground({
    required this.alignment,
    required this.label,
  });

  final AlignmentGeometry alignment;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: isDark ? AppColors.debt : AppColors.debtLight,
        shape: SmoothRectangleBorder(
          borderRadius: _contactTileSquircleRadius,
        ),
      ),
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingXl,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: AppDimensions.iconMedium,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _ContactNameLabel — optional Hero for list → detail transition
// =============================================================================

class _ContactNameLabel extends StatelessWidget {
  const _ContactNameLabel({
    required this.contactId,
    required this.name,
    required this.isDark,
    required this.enableHero,
  });

  final String contactId;
  final String name;
  final bool isDark;
  final bool enableHero;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.titleMedium.copyWith(
        color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
        fontWeight: FontWeight.w600,
        height: 1.15,
      ),
    );

    if (!enableHero) {
      return text;
    }

    return Hero(
      tag: 'contact_name_hero_$contactId',
      child: Material(
        type: MaterialType.transparency,
        child: text,
      ),
    );
  }
}

// =============================================================================
// Helpers
// =============================================================================

String _semanticLabel({
  required String name,
  required String transactionsText,
  required String balanceText,
}) {
  final buffer = StringBuffer(name)
    ..write(', $transactionsText')
    ..write(', $balanceText');
  return buffer.toString();
}
