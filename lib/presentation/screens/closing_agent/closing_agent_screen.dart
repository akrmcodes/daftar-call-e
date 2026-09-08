import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/application/agent/group_capture_proposals.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/agent_speech.dart';
import 'package:daftar/core/utils/closing_mic_hold_session.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/native_contact_picker_service.dart';
import 'package:daftar/domain/constants/built_in_currencies.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/collections_send_queue_status.dart';
import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/closing_agent_controller.dart';
import 'package:daftar/presentation/providers/closing_agent_state.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/screens/closing_agent/share_agent_statement.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/agent_ask_card.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/agent_capture_bundle_card.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/agent_confirm_card.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_composer.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_idle_studio.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_mic_hint_chip.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_taskmaster.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_working_glow.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_working_studio.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_ritual_panel.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_desk_panel.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/credit_limit_call_session.dart';
import 'package:daftar/presentation/screens/contact/credit_limit_b_trigger.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_close_icon_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_error_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_permission_banner.dart';
import 'package:daftar/presentation/shared/widgets/daftar_snack_bar.dart';
import 'package:daftar/presentation/shared/widgets/khazna_radial_well.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

/// Khazna intent-preview studio for the Closing Agent (not a chat).
class ClosingAgentScreen extends ConsumerStatefulWidget {
  /// Creates the Closing Agent screen.
  const ClosingAgentScreen({super.key});

  @override
  ConsumerState<ClosingAgentScreen> createState() => _ClosingAgentScreenState();
}

class _ClosingAgentScreenState extends ConsumerState<ClosingAgentScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _composerController;
  final ClosingMicHoldSession _mic = ClosingMicHoldSession();
  Timer? _voiceCapTimer;
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref
            .read(closingAgentControllerProvider.notifier)
            .hydrateInFlightQueue(),
      );
    });
  }

  @override
  void dispose() {
    _voiceCapTimer?.cancel();
    unawaited(AgentSpeech.stop());
    unawaited(_mic.dispose());
    WidgetsBinding.instance.removeObserver(this);
    _composerController.dispose();
    ref.read(closingAgentControllerProvider.notifier).resetSpeechSession();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _wasInBackground = true;
        unawaited(_abandonRecordingForBackground());
      case AppLifecycleState.resumed:
        if (_wasInBackground) {
          _wasInBackground = false;
          unawaited(_onHostResumed());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _abandonRecordingForBackground() async {
    _voiceCapTimer?.cancel();
    if (!_mic.isRecording) {
      return;
    }
    await _mic.abandonForBackground();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _onHostResumed() async {
    await ref
        .read(closingAgentControllerProvider.notifier)
        .onHostResumed(
          hasMicrophonePermission: () async {
            final status = await _mic.currentStatus();
            return status.isGranted;
          },
        );
  }

  Future<void> _showAgentFailure(
    AppLocalizations l10n,
    Failure failure,
  ) {
    if (failure.code == kAgentOpenIdGrantRequiredCode) {
      return DaftarErrorSheet.show(
        context,
        content: ErrorTranslator.translate(l10n, failure),
        actionLabel: l10n.backupDriveOfflineGrantAction,
        onAction: () {
          unawaited(
            ref
                .read(driveOfflineGrantControllerProvider.notifier)
                .completeDriveAuthorization(),
          );
        },
      );
    }
    return AppBottomSheet.showError(context, error: failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final surface = isDark ? AppColors.surface0 : AppColors.surface0Light;
    final agentState = ref.watch(closingAgentControllerProvider);
    ref.listen<ClosingAgentState>(closingAgentControllerProvider, (
      previous,
      next,
    ) {
      final pending = next.pendingCreditLimitPromptContactId;
      if (pending == null || pending.trim().isEmpty) {
        return;
      }
      if (previous?.pendingCreditLimitPromptContactId == pending) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          CreditLimitBTrigger.presentPendingPrompt(
            context: context,
            ref: ref,
            contactId: pending,
          ),
        );
      });
    });
    final ledgersAsync = ref.watch(ledgersProvider);
    final ledgers = ledgersAsync.asData?.value ?? const <Ledger>[];
    final ledgersReady = ledgersAsync.hasValue;

    ref
      ..listen(closingAgentControllerProvider, (previous, next) {
        final failure = next.actionFailure;
        if (failure != null && failure != previous?.actionFailure) {
          unawaited(_showAgentFailure(l10n, failure));
          ref
              .read(closingAgentControllerProvider.notifier)
              .clearActionFailure();
        }
        if (next.committedIds.length > (previous?.committedIds.length ?? 0)) {
          unawaited(HapticService.transactionSaved());
        }
      })
      ..listen(ledgersProvider, (previous, next) {
        final value = next.asData?.value;
        if (value != null) {
          ref
              .read(closingAgentControllerProvider.notifier)
              .applySoleLedgerIfNeeded(value);
        }
      })
      ..listen(driveOfflineGrantControllerProvider, (previous, next) {
        if (previous?.isLoading == true &&
            next is AsyncData<void> &&
            ref
                .read(closingAgentControllerProvider)
                .ritualDeskPreflightPending) {
          unawaited(
            ref
                .read(closingAgentControllerProvider.notifier)
                .resumeCollectionsDeskAfterPreflight(),
          );
        }
      });

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final dockScrollInset =
        ClosingAgentComposer.scrollInset + bottomSafe + AppDimensions.spacingMd;
    final wellOpacity =
        agentState.phase == ClosingAgentPhase.idle ||
            agentState.phase == ClosingAgentPhase.running
        ? 1.0
        : 0.35;

    final glowActive =
        agentState.phase == ClosingAgentPhase.running ||
        (agentState.isCreditLimitCallSessionActive &&
            agentState.callConsented &&
            !agentState.creditLimitCallSessionTerminal);

    return Scaffold(
      backgroundColor: surface,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          KhaznaRadialWell(opacity: wellOpacity),
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: ClosingAgentWorkingGlow(active: glowActive),
          ),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.spacingSm,
                  ),
                  child: SizedBox(
                    height: AppDimensions.minTapTarget,
                    child: Row(
                      children: [
                        DaftarCloseIconButton(onPressed: () => context.pop()),
                        Expanded(
                          child: Text(
                            l10n.closingAgentTitle,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.titleLarge.copyWith(
                              color: inkPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.minTapTarget),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _AgentBody(
                  agentState: agentState,
                  ledgers: ledgers,
                  ledgersReady: ledgersReady,
                  isDark: isDark,
                  keyboardOpen: keyboardOpen,
                  paddingBottom: dockScrollInset,
                  onExampleSelected: _fillComposer,
                  onCloseToday: _onCloseToday,
                ),
              ),
            ],
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (agentState.micBannerKind != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppDimensions.pagePaddingH,
                      AppDimensions.spacingSm,
                      AppDimensions.pagePaddingH,
                      AppDimensions.spacingXs,
                    ),
                    child: AnimatedSwitcher(
                      duration: AppDimensions.animationMedium,
                      switchInCurve: AppMotion.curveEnter,
                      switchOutCurve: AppMotion.curveExit,
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: AppMotion.curveEnter,
                          reverseCurve: AppMotion.curveExit,
                        );
                        return FadeTransition(
                          opacity: curved,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.12),
                              end: Offset.zero,
                            ).animate(curved),
                            child: child,
                          ),
                        );
                      },
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: AlignmentDirectional.bottomCenter,
                          children: [
                            ...previousChildren,
                            ?currentChild,
                          ],
                        );
                      },
                      child: switch (agentState.micBannerKind!) {
                        ClosingMicBannerKind.holdHint =>
                          ClosingAgentMicHintChip(
                            key: const ValueKey<String>(
                              'closing-agent-mic-hold-hint',
                            ),
                            message: l10n.closingAgentMicBanner,
                          ),
                        ClosingMicBannerKind.permissionDenied =>
                          DaftarPermissionBanner(
                            key: const ValueKey<String>(
                              'closing-agent-mic-permission',
                            ),
                            message: l10n.closingAgentMicPermissionDenied,
                            actionLabel: l10n.closingAgentMicOpenSettings,
                            onAction: () {
                              unawaited(openAppSettings());
                            },
                            semanticsLabel:
                                l10n.closingAgentPermissionBannerSemantics,
                          ),
                      },
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: agentState.isCreditLimitCallSessionActive
                      ? const SizedBox.shrink()
                      : ClosingAgentComposer(
                          controller: _composerController,
                          isRunning:
                              agentState.phase == ClosingAgentPhase.running ||
                              agentState.phase ==
                                  ClosingAgentPhase.ritualRunning,
                          isRecording: _mic.isRecording,
                          amplitudeStream: _mic.isRecording
                              ? _mic.amplitudeStream()
                              : null,
                          sendIsPrimary: !agentState.ownsPrimaryGlow,
                          onSubmit: _submit,
                          onMicTap: _onMicTap,
                          onMicHoldStart: () => unawaited(_onMicHoldStart()),
                          onMicHoldEnd: () => unawaited(_onMicHoldEnd()),
                          onMicHoldCancel: () =>
                              unawaited(_onMicHoldCancel()),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _fillComposer(String example) {
    _composerController
      ..text = example
      ..selection = TextSelection.collapsed(offset: example.length);
  }

  void _onCloseToday() {
    final goal = AppLocalizations.of(context)!.closingAgentCloseTodayGoal;
    _fillComposer(goal);
    _submit(goal);
  }

  void _submit(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _composerController.clear();
    unawaited(
      ref.read(closingAgentControllerProvider.notifier).submitGoal(trimmed),
    );
  }

  void _onMicTap() {
    final phase = ref.read(closingAgentControllerProvider).phase;
    if (_mic.isRecording ||
        phase == ClosingAgentPhase.running ||
        phase == ClosingAgentPhase.ritualRunning) {
      return;
    }
    ref
        .read(closingAgentControllerProvider.notifier)
        .showMicBanner(ClosingMicBannerKind.holdHint);
  }

  Future<void> _onMicHoldStart() async {
    final phase = ref.read(closingAgentControllerProvider).phase;
    if (_mic.isRecording ||
        phase == ClosingAgentPhase.running ||
        phase == ClosingAgentPhase.ritualRunning) {
      return;
    }
    ref.read(closingAgentControllerProvider.notifier).dismissMicBanner();
    unawaited(AgentSpeech.stop());
    final outcome = await _mic.begin();
    if (!mounted) {
      if (outcome == ClosingMicHoldBegin.started) {
        await _mic.cancel();
      }
      return;
    }
    if (outcome == ClosingMicHoldBegin.denied ||
        outcome == ClosingMicHoldBegin.failed) {
      ref
          .read(closingAgentControllerProvider.notifier)
          .showMicBanner(ClosingMicBannerKind.permissionDenied);
      return;
    }
    if (outcome != ClosingMicHoldBegin.started) {
      return;
    }
    unawaited(HapticService.medium());
    setState(() {});
    _voiceCapTimer?.cancel();
    _voiceCapTimer = Timer(ClosingAgentConstants.maxVoiceCapture, () {
      unawaited(_onMicHoldEnd());
    });
  }

  Future<void> _onMicHoldEnd() async {
    _voiceCapTimer?.cancel();
    final clip = await _mic.end();
    if (mounted) {
      setState(() {});
    }
    if (!mounted || clip == null) {
      return;
    }
    unawaited(
      ref.read(closingAgentControllerProvider.notifier).submitVoice(clip),
    );
  }

  Future<void> _onMicHoldCancel() async {
    _voiceCapTimer?.cancel();
    await _mic.cancel();
    if (mounted) {
      setState(() {});
    }
  }
}

class _AgentBody extends ConsumerWidget {
  const _AgentBody({
    required this.agentState,
    required this.ledgers,
    required this.ledgersReady,
    required this.isDark,
    required this.keyboardOpen,
    required this.paddingBottom,
    required this.onExampleSelected,
    required this.onCloseToday,
  });

  final ClosingAgentState agentState;
  final List<Ledger> ledgers;
  final bool ledgersReady;
  final bool isDark;
  final bool keyboardOpen;
  final double paddingBottom;
  final ValueChanged<String> onExampleSelected;
  final VoidCallback onCloseToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(appSettingsProvider).asData?.value ?? const AppSettings();
    final speechLocale = agentState.resolvedSpeechLocale(settings.locale);
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;

    if (agentState.phase == ClosingAgentPhase.idle) {
      return ClosingAgentIdleStudio(
        isDark: isDark,
        keyboardOpen: keyboardOpen,
        paddingBottom: paddingBottom,
        onExampleSelected: onExampleSelected,
        onCloseToday: onCloseToday,
      );
    }

    if (agentState.phase == ClosingAgentPhase.running) {
      return _RunningBody(
        agentState: agentState,
        isDark: isDark,
        paddingBottom: paddingBottom,
        ttsMuted: settings.ttsMuted,
        ttsLocale: speechLocale,
        onAskCandidateSelected: (contactId) {
          unawaited(
            ref
                .read(closingAgentControllerProvider.notifier)
                .resolveAskCandidate(contactId),
          );
        },
      );
    }

    if (agentState.phase == ClosingAgentPhase.ritualDesk) {
      final notifier = ref.read(closingAgentControllerProvider.notifier);
      if (agentState.callBatchTrigger == CallBatchTrigger.creditLimit) {
        return CreditLimitCallSession(paddingBottom: paddingBottom);
      }
      // Dedicated Collections Desk after aging — not compact taskmaster chrome.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CollectionsDeskPanel(
              paddingBottom: paddingBottom,
              rows: agentState.deskRows,
              callCount: agentState.deskCallCount,
              emailCount: agentState.deskEmailCount,
              deskSubtitle: agentState.callBatchTrigger ==
                      CallBatchTrigger.creditLimit
                  ? AppLocalizations.of(context)!
                      .collectionsDeskCreditLimitSubtitle
                  : null,
              callConsented: agentState.callConsented,
              sendOutreachEnabled: agentState.sendOutreachEnabled,
              callProgress: agentState.callProgress,
              startSendingIsPrimary: agentState.ownsPrimaryGlow,
              busyContactId: agentState.deskBusyContactId,
              isQueueInFlight: agentState.isQueueInFlight,
              isQueuePaused:
                  agentState.queueStatus == CollectionsSendQueueStatus.paused,
              queueIndex: agentState.queueSendingIndex,
              queueTotal: agentState.deskRows.length,
              queueContactName:
                  agentState.firstPendingDeskRow?.candidate.name ?? '',
              onCommitOutreach: ({required bool call, required bool send}) {
                unawaited(notifier.commitDeskOutreach(call: call, send: send));
              },
              onSkip: (contactId) {
                unawaited(notifier.skipDeskRow(contactId));
              },
              onCopy: (contactId) {
                unawaited(_copyDeskRow(context, ref, contactId));
              },
              onOpen: (contactId) {
                // Leftover Hybrid E — not the filmed climax or email fallback.
                unawaited(
                  notifier.openDeskRow(
                    contactId: contactId,
                    sharePdf: (row) => _shareDeskPdf(context, ref, row),
                  ),
                );
              },
              onTone: (contactId, tone) {
                unawaited(notifier.setDeskTone(contactId, tone));
              },
              onTogglePdf: (contactId) {
                unawaited(notifier.toggleDeskPdf(contactId));
              },
              onStartSending: () {
                // Leftover Hybrid E — not the filmed climax or email fallback.
                unawaited(
                  notifier.startSending(
                    sharePdf: (row) => _shareDeskPdf(context, ref, row),
                  ),
                );
              },
              onApproveAndSend: () => unawaited(notifier.approveAndSend()),
              onDone: () => unawaited(notifier.skipOutreach()),
              isDispatching: agentState.collectionsDispatching,
              showRetrySend:
                  agentState.actionFailure != null &&
                  !agentState.collectionsDispatching &&
                  agentState.deskRows.any(
                    (row) =>
                        row.status == CollectionsDeskRowStatus.pending,
                  ),
              onQueuePause: () => unawaited(notifier.pauseSendQueue()),
              onQueueResume: () => unawaited(notifier.resumeSendQueue()),
              onQueueSkip: () {
                final pending = agentState.firstPendingDeskRow;
                if (pending == null) {
                  unawaited(notifier.finishDesk());
                  return;
                }
                unawaited(notifier.skipDeskRow(pending.candidate.contactId));
              },
            ),
          ),
        ],
      );
    }

    final proposals =
        agentState.turnResult?.proposals ?? const <AgentProposal>[];
    final narrative = agentState.turnResult?.narrative?.trim();
    final askAnswer = agentState.askAnswer;
    final tiles = buildCaptureProposalTiles(
      proposals: proposals,
      committedIds: agentState.committedIds,
      skippedIds: agentState.skippedIds,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (askAnswer != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppDimensions.pagePaddingH,
                AppDimensions.spacingSm,
                AppDimensions.pagePaddingH,
                AppDimensions.spacingMd,
              ),
              child: AgentAskCard(
                answer: askAnswer,
                isDark: isDark,
                ttsMuted: settings.ttsMuted,
                ttsLocale: speechLocale,
                onCandidateSelected: (contactId) {
                  unawaited(
                    ref
                        .read(closingAgentControllerProvider.notifier)
                        .resolveAskCandidate(contactId),
                  );
                },
              ),
            ),
          ),
        if (narrative != null &&
            narrative.isNotEmpty &&
            agentState.pendingClosingPlan == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppDimensions.pagePaddingH,
                AppDimensions.spacingSm,
                AppDimensions.pagePaddingH,
                AppDimensions.spacingMd,
              ),
              child: Text(
                narrative,
                style: AppTextStyles.bodyMedium.copyWith(color: inkSecondary),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.pagePaddingH,
          ),
          sliver: SliverList.builder(
            itemCount: tiles.length,
            itemBuilder: (context, index) {
              final tile = tiles[index];
              final delay = Duration(
                milliseconds: index < 8 ? index * 30 : 0,
              );
              return Padding(
                key: ValueKey(_tileKey(tile)),
                padding: const EdgeInsetsDirectional.only(
                  bottom: AppDimensions.spacingMd,
                ),
                child: FadeSlideTransition(
                  delay: delay,
                  child: switch (tile) {
                    CaptureBundleTile(:final proposals) => _CaptureBundleTile(
                      proposals: proposals,
                      agentState: agentState,
                      ledgers: ledgers,
                      ledgersReady: ledgersReady,
                      isDark: isDark,
                    ),
                    CaptureSingleTile(:final proposal) => _ProposalTile(
                      key: ValueKey(proposal.proposalId),
                      proposal: proposal,
                      agentState: agentState,
                      ledgers: ledgers,
                      ledgersReady: ledgersReady,
                      isDark: isDark,
                    ),
                  },
                ),
              );
            },
          ),
        ),
        if (agentState.phase == ClosingAgentPhase.ritualRunning ||
            agentState.phase == ClosingAgentPhase.ritualPrompt ||
            agentState.phase == ClosingAgentPhase.ritualReport ||
            agentState.ritualRetryAvailable)
          SliverToBoxAdapter(child: ClosingRitualPanel(agentState: agentState)),
        const SliverToBoxAdapter(child: Gap(AppDimensions.spacingLg)),
        if (paddingBottom > 0)
          SliverToBoxAdapter(child: SizedBox(height: paddingBottom)),
      ],
    );
  }
}

String _tileKey(CaptureProposalTile tile) {
  return switch (tile) {
    CaptureBundleTile(:final proposals) => captureBundleKey(proposals),
    CaptureSingleTile(:final proposal) => proposal.proposalId,
  };
}

class _CaptureBundleTile extends ConsumerWidget {
  const _CaptureBundleTile({
    required this.proposals,
    required this.agentState,
    required this.ledgers,
    required this.ledgersReady,
    required this.isDark,
  });

  final List<AgentProposal> proposals;
  final ClosingAgentState agentState;
  final List<Ledger> ledgers;
  final bool ledgersReady;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(closingAgentControllerProvider.notifier);
    final settings =
        ref.watch(appSettingsProvider).asData?.value ?? const AppSettings();
    final bundleKey = captureBundleKey(proposals);
    final isConfirming =
        agentState.confirmingProposalId == bundleKey ||
        proposals.any(
          (proposal) => proposal.proposalId == agentState.confirmingProposalId,
        );

    return AgentCaptureBundleCard(
      key: ValueKey(bundleKey),
      proposals: proposals,
      ledgers: ledgers,
      ledgersReady: ledgersReady,
      currencies: BuiltInCurrencies.all,
      isMultiCurrencyEnabled: settings.isMultiCurrencyEnabled,
      ttsMuted: settings.ttsMuted,
      ttsLocale: agentState.resolvedSpeechLocale(settings.locale),
      ledgerIdByProposal: agentState.ledgerIdByProposal,
      currencyCodeByProposal: agentState.currencyCodeByProposal,
      contactIdByProposal: agentState.contactIdByProposal,
      createNewByProposal: agentState.createNewByProposal,
      candidatesByProposal: agentState.candidatesByProposal,
      ledgerNameByProposal: agentState.ledgerNameByProposal,
      amountMinorByProposal: agentState.amountMinorByProposal,
      nameByProposal: agentState.nameByProposal,
      phoneByProposal: agentState.phoneByProposal,
      isConfirming: isConfirming,
      onConfirm: () => unawaited(notifier.confirmCaptureBundle(proposals)),
      onSkip: () => unawaited(notifier.cancelCaptureBundle(proposals)),
      onLedgerSelected: notifier.setLedgerForProposal,
      onCurrencySelected: notifier.setCurrencyForProposal,
      onLedgerNameChanged: notifier.setLedgerNameForProposal,
      onContactSelected: notifier.setContactForProposal,
      onCreateNewSelected: notifier.chooseCreateNewContact,
    );
  }
}

class _ProposalTile extends ConsumerWidget {
  const _ProposalTile({
    required this.proposal,
    required this.agentState,
    required this.ledgers,
    required this.ledgersReady,
    required this.isDark,
    super.key,
  });

  final AgentProposal proposal;
  final ClosingAgentState agentState;
  final List<Ledger> ledgers;
  final bool ledgersReady;
  final bool isDark;

  bool _showPhonePicker() {
    if (proposal.tool == ProposalTool.proposeCreateContact) {
      return true;
    }
    switch (proposal.payload) {
      case ProposeDebtPayload(:final contactId):
      case ProposePaymentPayload(:final contactId):
        final picked = agentState.contactIdByProposal[proposal.proposalId]
            ?.trim();
        if (picked != null && picked.isNotEmpty) {
          return false;
        }
        final id = contactId?.trim();
        if (id != null && id.isNotEmpty) {
          return false;
        }
        final candidates =
            agentState.candidatesByProposal[proposal.proposalId] ?? const [];
        if (agentState.createNewByProposal.contains(proposal.proposalId)) {
          return true;
        }
        return candidates.isEmpty;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(closingAgentControllerProvider.notifier);
    final settings =
        ref.watch(appSettingsProvider).asData?.value ?? const AppSettings();

    if (agentState.committedIds.contains(proposal.proposalId)) {
      return _StatusRow(
        isDark: isDark,
        icon: Icons.check_rounded,
        label: l10n.closingAgentConfirmed,
      );
    }
    if (agentState.skippedIds.contains(proposal.proposalId)) {
      return _StatusRow(
        isDark: isDark,
        icon: Icons.remove_rounded,
        label: l10n.closingAgentSkipped,
      );
    }

    switch (proposal.tool) {
      case ProposalTool.proposeClosingPlan:
        return ClosingAgentTaskmaster(
          mode: ClosingAgentTaskmasterMode.planReview,
          localDay: ClosingAgentConstants.merchantLocalDay(),
          showActions: true,
          isConfirming: agentState.confirmingProposalId == proposal.proposalId,
          approveIsPrimary: !agentState.hasPendingMoneyConfirm,
          onConfirmAndSend: () => unawaited(
            notifier.confirm(proposal, sendOutreach: true),
          ),
          onConfirmWithoutSending: () => unawaited(
            notifier.confirm(proposal),
          ),
          onSkip: () => unawaited(notifier.cancel(proposal.proposalId)),
        );
      case ProposalTool.proposeDebt:
      case ProposalTool.proposePayment:
      case ProposalTool.proposeCreateContact:
      case ProposalTool.proposeCreateLedger:
      case ProposalTool.proposeStatement:
        return AgentConfirmCard(
          key: ValueKey(proposal.proposalId),
          proposal: proposal,
          ledgers: ledgers,
          ledgersReady: ledgersReady,
          currencies: BuiltInCurrencies.all,
          isMultiCurrencyEnabled: settings.isMultiCurrencyEnabled,
          ttsMuted: settings.ttsMuted,
          ttsLocale: agentState.resolvedSpeechLocale(settings.locale),
          selectedLedgerId: agentState.ledgerIdByProposal[proposal.proposalId],
          selectedCurrencyCode:
              agentState.currencyCodeByProposal[proposal.proposalId],
          selectedContactId:
              agentState.contactIdByProposal[proposal.proposalId],
          createNewSelected: agentState.createNewByProposal.contains(
            proposal.proposalId,
          ),
          candidates:
              agentState.candidatesByProposal[proposal.proposalId] ?? const [],
          pickedName: agentState.nameByProposal[proposal.proposalId],
          pickedPhone: agentState.phoneByProposal[proposal.proposalId],
          ledgerName: agentState.ledgerNameByProposal[proposal.proposalId],
          amountMinorOverride:
              agentState.amountMinorByProposal[proposal.proposalId],
          onPickFromContacts:
              NativeContactPickerService.isSupported && _showPhonePicker()
              ? () => unawaited(
                  notifier.pickPhoneContact(proposal.proposalId),
                )
              : null,
          contactsPermissionDenied: agentState.contactsPermissionDenied,
          onOpenContactsSettings: () {
            unawaited(openAppSettings());
          },
          isConfirming: agentState.confirmingProposalId == proposal.proposalId,
          onConfirm: () {
            if (proposal.tool == ProposalTool.proposeStatement) {
              unawaited(
                shareAgentStatement(
                  context: context,
                  ref: ref,
                  proposal: proposal,
                ),
              );
              return;
            }
            unawaited(notifier.confirm(proposal));
          },
          onSkip: () => unawaited(notifier.cancel(proposal.proposalId)),
          onLedgerSelected: (ledgerId) {
            notifier.setLedgerForProposal(proposal.proposalId, ledgerId);
          },
          onLedgerNameChanged: (name) {
            notifier.setLedgerNameForProposal(proposal.proposalId, name);
          },
          onCurrencySelected: (currencyCode) {
            notifier.setCurrencyForProposal(proposal.proposalId, currencyCode);
          },
          onContactSelected: (contactId) {
            notifier.setContactForProposal(proposal.proposalId, contactId);
          },
          onCreateNewSelected: () {
            notifier.chooseCreateNewContact(proposal.proposalId);
          },
        );
      case ProposalTool.proposeWhatsappDrafts:
      case ProposalTool.parseGoal:
        return _ReadOnlyRow(proposal: proposal, isDark: isDark);
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.isDark,
    required this.icon,
    required this.label,
  });

  final bool isDark;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    return RepaintBoundary(
      child: DaftarCard(
        variant: DaftarCardVariant.compact,
        child: Row(
          children: [
            Icon(icon, color: inkSecondary, size: AppDimensions.iconMedium),
            const Gap(AppDimensions.spacingMd),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(color: inkSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.proposal,
    required this.isDark,
  });

  final AgentProposal proposal;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final title = _readOnlyTitle(proposal);
    return RepaintBoundary(
      child: DaftarCard(
        variant: DaftarCardVariant.compact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
            ),
            const Gap(AppDimensions.spacingXs),
            Text(
              l10n.closingAgentReadOnlyTool,
              style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _readOnlyTitle(AgentProposal proposal) {
    final payload = proposal.payload;
    return switch (payload) {
      ProposeCreateLedgerPayload(:final name) => name,
      ParseGoalPayload(:final goalClass) => goalClass,
      GenericProposalPayload() => proposal.tool.wireName,
      _ => proposal.tool.wireName,
    };
  }
}

class _RunningBody extends StatelessWidget {
  const _RunningBody({
    required this.agentState,
    required this.isDark,
    required this.paddingBottom,
    required this.ttsMuted,
    required this.ttsLocale,
    required this.onAskCandidateSelected,
  });

  final ClosingAgentState agentState;
  final bool isDark;
  final double paddingBottom;
  final bool ttsMuted;
  final String ttsLocale;
  final ValueChanged<String> onAskCandidateSelected;

  @override
  Widget build(BuildContext context) {
    final askAnswer = agentState.askAnswer;
    if (askAnswer == null) {
      return ClosingAgentWorkingStudio(
        isDark: isDark,
        paddingBottom: paddingBottom,
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppDimensions.pagePaddingH,
            AppDimensions.spacingSm,
            AppDimensions.pagePaddingH,
            AppDimensions.spacingMd,
          ),
          child: AgentAskCard(
            answer: askAnswer,
            isDark: isDark,
            ttsMuted: ttsMuted,
            ttsLocale: ttsLocale,
            onCandidateSelected: onAskCandidateSelected,
          ),
        ),
        Expanded(
          child: ClosingAgentWorkingStudio(
            isDark: isDark,
            paddingBottom: paddingBottom,
          ),
        ),
      ],
    );
  }
}

Future<void> _copyDeskRow(
  BuildContext context,
  WidgetRef ref,
  String contactId,
) async {
  await ref
      .read(closingAgentControllerProvider.notifier)
      .copyDeskRow(contactId);
  if (!context.mounted) {
    return;
  }
  final l10n = AppLocalizations.of(context)!;
  showDaftarSnackBar(
    context: context,
    message: l10n.collectionsDeskCopied,
  );
}

Future<bool> _shareDeskPdf(
  BuildContext context,
  WidgetRef ref,
  CollectionsDeskRow row,
) async {
  final result = await shareContactStatementPdf(
    context: context,
    ref: ref,
    contactId: row.candidate.contactId,
  );
  if (result.failure != null) {
    ref
        .read(closingAgentControllerProvider.notifier)
        .notifyActionFailure(result.failure!);
    return false;
  }
  return result.didShare;
}
