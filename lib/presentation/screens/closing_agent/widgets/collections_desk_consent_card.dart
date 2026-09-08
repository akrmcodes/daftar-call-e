import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_call_progress_bar.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_desk_rail_chip.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Compact HITL dock: two rail chips + one dynamic primary CTA.
class CollectionsDeskConsentCard extends StatefulWidget {
  /// Creates the consent dock.
  const CollectionsDeskConsentCard({
    required this.callCount,
    required this.emailCount,
    required this.callConsented,
    required this.sendOutreachEnabled,
    required this.busy,
    required this.isDispatching,
    required this.onCommit,
    this.callProgress,
    this.retryOfferCount = 0,
    this.onRetryUnanswered,
    super.key,
  });

  /// CALL-E call-set size (controls call-rail visibility).
  final int callCount;

  /// Email-rail size (controls send enablement).
  final int emailCount;

  /// Merchant already consented to outbound calls.
  final bool callConsented;

  /// Plan-level Confirm & Send was chosen (SMTP available).
  final bool sendOutreachEnabled;

  /// Desk row action in flight.
  final bool busy;

  /// SMTP send-batch in flight.
  final bool isDispatching;

  /// Commits chip selection: call and/or send, or seal when both off.
  final void Function({required bool call, required bool send}) onCommit;

  /// Seeded after Confirm & Call.
  final CollectionsCallProgress? callProgress;

  /// Contacts eligible for one no-answer/voicemail retry.
  final int retryOfferCount;

  /// Merchant consents to retry unanswered calls.
  final VoidCallback? onRetryUnanswered;

  @override
  State<CollectionsDeskConsentCard> createState() =>
      _CollectionsDeskConsentCardState();
}

class _CollectionsDeskConsentCardState extends State<CollectionsDeskConsentCard> {
  late bool _callSelected;
  late bool _sendSelected;

  @override
  void initState() {
    super.initState();
    _syncChipDefaults();
  }

  @override
  void didUpdateWidget(CollectionsDeskConsentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.callConsented != widget.callConsented ||
        oldWidget.callCount != widget.callCount ||
        oldWidget.emailCount != widget.emailCount ||
        oldWidget.sendOutreachEnabled != widget.sendOutreachEnabled) {
      _syncChipDefaults();
    }
  }

  void _syncChipDefaults() {
    final showCall = _showCallChip;
    final showSend = _showSendChip;
    _callSelected = showCall;
    _sendSelected = showSend && widget.emailCount > 0;
  }

  bool get _showCallChip => !widget.callConsented && widget.callCount > 0;

  bool get _showSendChip => widget.sendOutreachEnabled;

  bool get _callChipLocked =>
      widget.callConsented ||
      widget.busy ||
      widget.isDispatching ||
      (widget.callProgress != null && !widget.callProgress!.isTerminal);

  bool get _sendChipLocked =>
      widget.busy ||
      widget.isDispatching ||
      (widget.callProgress != null && !widget.callProgress!.isTerminal);

  bool get _ctaDisabled =>
      widget.busy ||
      widget.isDispatching ||
      (widget.callProgress != null && !widget.callProgress!.isTerminal);

  bool get _ctaLoading =>
      widget.isDispatching ||
      (widget.callConsented &&
          widget.callProgress != null &&
          !widget.callProgress!.isTerminal);

  _DeskCommitMode get _commitMode {
    final call = _showCallChip && _callSelected;
    final send = _showSendChip && _sendSelected && widget.emailCount > 0;
    if (call && send) {
      return _DeskCommitMode.both;
    }
    if (call) {
      return _DeskCommitMode.callOnly;
    }
    if (send) {
      return _DeskCommitMode.emailOnly;
    }
    return _DeskCommitMode.seal;
  }

  String _ctaLabel(AppLocalizations l10n) {
    switch (_commitMode) {
      case _DeskCommitMode.both:
        return l10n.collectionsDeskCommitOutreachBoth(
          widget.callCount,
          widget.emailCount,
        );
      case _DeskCommitMode.callOnly:
        return l10n.collectionsDeskCommitCallsOnly(widget.callCount);
      case _DeskCommitMode.emailOnly:
        return l10n.collectionsDeskCommitEmailOnly(widget.emailCount);
      case _DeskCommitMode.seal:
        return l10n.collectionsDeskCommitSeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hairline = isDark
        ? AppColors.borderSubtle.withValues(alpha: 0.8)
        : AppColors.borderSubtleLight.withValues(alpha: 0.9);
    final showChips = _showCallChip || _showSendChip;
    final ctaLabel = _ctaLabel(l10n);
    final ctaPrimary = _commitMode != _DeskCommitMode.seal;
    final showRetry =
        widget.retryOfferCount > 0 &&
        widget.onRetryUnanswered != null &&
        !_ctaLoading;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: hairline, width: 0.5),
        ),
      ),
      child: DaftarCard(
        variant: DaftarCardVariant.premium,
        margin: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.pagePaddingH,
          AppDimensions.spacingSm,
          AppDimensions.pagePaddingH,
          AppDimensions.spacingMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.callProgress != null) ...[
              CollectionsCallProgressBar(progress: widget.callProgress!),
              const Gap(AppDimensions.spacingSm),
            ],
            if (showRetry) ...[
              DaftarButton(
                label: l10n.collectionsDeskRetryUnanswered(widget.retryOfferCount),
                isExpanded: true,
                onPressed: widget.busy || widget.isDispatching
                    ? null
                    : () {
                        unawaited(HapticService.selection());
                        widget.onRetryUnanswered!();
                      },
              ),
              const Gap(AppDimensions.spacingSm),
            ],
            if (showChips) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showCallChip)
                    Expanded(
                      child: CollectionsDeskRailChip(
                        label: l10n.collectionsDeskRailChipVoiceCalls(
                          widget.callCount,
                        ),
                        selected: _callSelected,
                        enabled: !_callChipLocked,
                        onToggle: () {
                          setState(() => _callSelected = !_callSelected);
                        },
                      ),
                    ),
                  if (_showCallChip && _showSendChip)
                    const Gap(AppDimensions.spacingSm),
                  if (_showSendChip)
                    Expanded(
                      child: CollectionsDeskRailChip(
                        label: l10n.collectionsDeskRailChipEmail(
                          widget.emailCount,
                        ),
                        selected: _sendSelected,
                        enabled: !_sendChipLocked && widget.emailCount > 0,
                        onToggle: () {
                          setState(() => _sendSelected = !_sendSelected);
                        },
                      ),
                    ),
                ],
              ),
              const Gap(AppDimensions.spacingSm),
            ],
            AnimatedSwitcher(
              duration: AppDimensions.animationMedium,
              switchInCurve: AppMotion.curveEnter,
              switchOutCurve: AppMotion.curveExit,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: DaftarButton(
                key: ValueKey<String>(ctaLabel),
                label: ctaLabel,
                variant: ctaPrimary
                    ? DaftarButtonVariant.primary
                    : DaftarButtonVariant.secondary,
                isExpanded: true,
                isLoading: _ctaLoading,
                onPressed: _ctaDisabled
                    ? null
                    : () {
                        if (ctaPrimary) {
                          unawaited(HapticService.medium());
                        }
                        final call = _showCallChip && _callSelected;
                        final send =
                            _showSendChip &&
                            _sendSelected &&
                            widget.emailCount > 0;
                        widget.onCommit(call: call, send: send);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DeskCommitMode {
  both,
  callOnly,
  emailOnly,
  seal,
}
