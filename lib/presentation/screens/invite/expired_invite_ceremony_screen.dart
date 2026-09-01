import 'dart:async' show unawaited;

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_claim_result.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_claimed_by.dart';
import 'package:daftar/presentation/providers/deep_link_providers.dart';
import 'package:daftar/presentation/screens/invite/deep_link_outcome_message.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Expired / revoked / already-claimed invite ceremony (Stage 8.5.1).
class ExpiredInviteCeremonyScreen extends ConsumerStatefulWidget {
  /// Creates the ceremony screen.
  const ExpiredInviteCeremonyScreen({
    required this.token,
    required this.status,
    this.claimedBy,
    super.key,
  });

  /// Opaque deep-link token.
  final String token;

  /// Wire status: `expired` | `revoked` | `already_claimed`.
  final String status;

  /// When [status] is `already_claimed`.
  final String? claimedBy;

  @override
  ConsumerState<ExpiredInviteCeremonyScreen> createState() =>
      _ExpiredInviteCeremonyScreenState();
}

class _ExpiredInviteCeremonyScreenState
    extends ConsumerState<ExpiredInviteCeremonyScreen> {
  bool _requesting = false;
  bool _notified = false;
  String? _error;
  final _manualController = TextEditingController();

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  DeepLinkClaimResult get _result {
    switch (widget.status) {
      case 'expired':
        return const DeepLinkClaimExpired();
      case 'already_claimed':
        final by = DeepLinkClaimedBy.fromString(widget.claimedBy) ??
            DeepLinkClaimedBy.byOther;
        return DeepLinkClaimAlreadyClaimed(by);
      case 'revoked':
      default:
        return const DeepLinkClaimRevoked();
    }
  }

  Future<void> _dismissToHome() async {
    await ref.read(handledDeepLinkStoreProvider).markHandled(widget.token);
    if (!mounted) {
      return;
    }
    context.go(RouteNames.homePath);
  }

  Future<void> _requestNewInvite() async {
    if (_requesting || _notified) {
      return;
    }
    setState(() {
      _requesting = true;
      _error = null;
    });
    final result =
        await ref.read(requestNewInviteUseCaseProvider).call(widget.token);
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    result.fold(
      (failure) {
        setState(() {
          _requesting = false;
          // Failure.message is an English engineering diagnostic — never
          // show it to a merchant reading the app in Arabic.
          _error = ErrorTranslator.message(l10n, failure);
        });
      },
      (_) {
        setState(() {
          _requesting = false;
          _notified = true;
        });
      },
    );
  }

  Future<void> _submitManualCode() async {
    final raw = _manualController.text.trim();
    if (raw.isEmpty) {
      return;
    }
    final outcome =
        await ref.read(deepLinkControllerProvider.notifier).handleToken(raw);
    if (!mounted) {
      return;
    }
    setState(() {
      _error = deepLinkOutcomeMessage(AppLocalizations.of(context)!, outcome);
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      return;
    }
    _manualController.text = text;
    await _submitManualCode();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final muted = isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    final title = switch (_result) {
      DeepLinkClaimExpired() => l10n.inviteCeremonyExpiredTitle,
      DeepLinkClaimRevoked() ||
      DeepLinkClaimNotFound() =>
        l10n.inviteCeremonyRevokedTitle,
      DeepLinkClaimAlreadyClaimed(:final claimedBy) =>
        claimedBy == DeepLinkClaimedBy.byYou
            ? l10n.inviteCeremonyAlreadyClaimedByYouTitle
            : l10n.inviteCeremonyAlreadyClaimedTitle,
      DeepLinkClaimOk() => l10n.inviteCeremonyExpiredTitle,
    };

    final body = switch (_result) {
      DeepLinkClaimExpired() => l10n.inviteCeremonyExpiredBody,
      DeepLinkClaimRevoked() ||
      DeepLinkClaimNotFound() =>
        l10n.inviteCeremonyRevokedBody,
      DeepLinkClaimAlreadyClaimed(:final claimedBy) =>
        claimedBy == DeepLinkClaimedBy.byYou
            ? l10n.inviteCeremonyAlreadyClaimedByYouBody
            : l10n.inviteCeremonyAlreadyClaimedBody,
      DeepLinkClaimOk() => l10n.inviteCeremonyExpiredBody,
    };

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          unawaited(
            ref.read(handledDeepLinkStoreProvider).markHandled(widget.token),
          );
        }
      },
      child: Scaffold(
      backgroundColor: isDark ? AppColors.surface1 : AppColors.surface0Light,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surface2 : AppColors.surface1Light,
        title: Text(
          l10n.inviteCeremonyTitle,
          style: AppTextStyles.headlineLarge.copyWith(color: ink),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.pagePaddingH,
            vertical: AppDimensions.spacingXxl,
          ),
          children: [
            Container(
              padding: const EdgeInsetsDirectional.all(AppDimensions.spacingXl),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface2 : AppColors.surface1Light,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(color: AppColors.lapis400, width: 0.5),
                boxShadow: AppGlows.haloSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.headlineMedium.copyWith(color: ink),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Text(
                    body,
                    style: AppTextStyles.bodyLarge.copyWith(color: muted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),
                  if (_notified)
                    Text(
                      l10n.inviteCeremonyPendingBody,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: isDark
                            ? AppColors.payment
                            : AppColors.paymentLight,
                      ),
                      textAlign: TextAlign.center,
                    )
                  else
                    DaftarButton(
                      label: l10n.inviteCeremonyRequestCta,
                      onPressed: _requesting ? null : _requestNewInvite,
                      isLoading: _requesting,
                      isExpanded: true,
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: AppDimensions.spacingMd),
                    Text(
                      _error!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? AppColors.debt : AppColors.debtLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXxl),
            DaftarButton(
              label: l10n.inviteCeremonyOpenHome,
              variant: DaftarButtonVariant.secondary,
              isExpanded: true,
              onPressed: _dismissToHome,
            ),
            const SizedBox(height: AppDimensions.spacingXxl),
            Text(
              l10n.inviteCeremonyManualCodeLabel,
              style: AppTextStyles.headlineMedium.copyWith(color: ink),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            DaftarTextField(
              controller: _manualController,
              label: l10n.inviteCeremonyManualCodeLabel,
              hint: l10n.inviteCeremonyManualCodeHint,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitManualCode(),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              children: [
                Expanded(
                  child: DaftarButton(
                    label: l10n.inviteCeremonyPasteClipboard,
                    onPressed: _pasteFromClipboard,
                    variant: DaftarButtonVariant.secondary,
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: DaftarButton(
                    label: l10n.inviteCeremonySubmitCode,
                    onPressed: _submitManualCode,
                    variant: DaftarButtonVariant.tertiary,
                    isExpanded: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}
