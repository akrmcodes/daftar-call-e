import 'dart:async' show Timer, unawaited;
import 'dart:ui';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_vault_success_seal.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

enum VaultCeremonyMode { create, restoreLocal, restoreDrive }

/// External controller for the vault ceremony overlay.
class VaultCeremonyController extends ChangeNotifier {
  bool _isSuccessVisible = false;
  String _successTitle = '';
  String _successSubtitle = '';
  bool _dismissed = false;

  bool get isSuccessVisible => _isSuccessVisible;
  String get successTitle => _successTitle;
  String get successSubtitle => _successSubtitle;
  bool get dismissed => _dismissed;

  void revealSuccess({required String title, required String subtitle}) {
    if (_dismissed) return;
    _isSuccessVisible = true;
    _successTitle = title;
    _successSubtitle = subtitle;
    notifyListeners();
  }

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    notifyListeners();
  }
}

/// Full-screen vault ceremony — obsidian veil, lock breathing, progress arc.
abstract final class BackupVaultCeremonyOverlay {
  static VaultCeremonyController show(
    BuildContext context, {
    required VaultCeremonyMode mode,
  }) {
    final controller = VaultCeremonyController();

    unawaited(
      showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        transitionDuration: AppDimensions.animationMedium,
        transitionBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.curveEnter,
          );
          return FadeTransition(opacity: curved, child: child);
        },
        pageBuilder: (dialogContext, _, _) {
          return UncontrolledProviderScope(
            container: ProviderScope.containerOf(context),
            child: _CeremonyOverlayContent(
              mode: mode,
              controller: controller,
              onDismiss: () {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }
              },
            ),
          );
        },
      ),
    );

    return controller;
  }

  /// Shows ceremony, awaits [operation], then success seal hold, then dismisses.
  static Future<bool> runWithCeremony({
    required BuildContext context,
    required VaultCeremonyMode mode,
    required Future<bool> Function() operation,
    required String successTitle,
    required String successSubtitle,
  }) async {
    final controller = show(context, mode: mode);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final ok = await operation();

    if (!context.mounted) {
      controller.dismiss();
      return ok;
    }

    if (ok) {
      controller.revealSuccess(
        title: successTitle,
        subtitle: successSubtitle,
      );
      await Future<void>.delayed(const Duration(milliseconds: 1800));
    }

    controller.dismiss();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    return ok;
  }
}

class _CeremonyOverlayContent extends ConsumerStatefulWidget {
  const _CeremonyOverlayContent({
    required this.mode,
    required this.controller,
    required this.onDismiss,
  });

  final VaultCeremonyMode mode;
  final VaultCeremonyController controller;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_CeremonyOverlayContent> createState() =>
      _CeremonyOverlayContentState();
}

class _CeremonyOverlayContentState
    extends ConsumerState<_CeremonyOverlayContent> {
  Timer? _phaseTimer;
  int _phaseIndex = 0;
  late List<String> _phases;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPhaseRotation());
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    if (widget.controller.dismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDismiss();
      });
    }
    setState(() {});
  }

  void _startPhaseRotation() {
    final l10n = AppLocalizations.of(context)!;
    _phases = switch (widget.mode) {
      VaultCeremonyMode.create => [
          l10n.backupCeremonyValidating,
          l10n.backupCeremonyApplying,
        ],
      VaultCeremonyMode.restoreLocal => [
          l10n.backupCeremonyValidating,
          l10n.backupCeremonyDecrypting,
          l10n.backupCeremonyApplying,
        ],
      VaultCeremonyMode.restoreDrive => [
          l10n.backupCeremonyDownloading,
          l10n.backupCeremonyValidating,
          l10n.backupCeremonyDecrypting,
          l10n.backupCeremonyApplying,
        ],
    };

    if (MediaQuery.disableAnimationsOf(context)) return;

    _phaseTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted || widget.controller.isSuccessVisible) return;
      setState(() {
        _phaseIndex = (_phaseIndex + 1) % _phases.length;
      });
    });
  }

  String get _phaseMessage => _phases.isEmpty
      ? ''
      : _phases[_phaseIndex % _phases.length];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final trackColor = isDark ? AppColors.surface5 : AppColors.surface3Light;

    final backupState = ref.watch(backupProvider);
    final driveState = ref.watch(driveBackupProvider);

    final isDriveDownloading = widget.mode == VaultCeremonyMode.restoreDrive &&
        driveState.isTransferring &&
        driveState.transferKind == DriveTransferKind.download;

    final determinateProgress =
        isDriveDownloading ? driveState.progress.clamp(0.0, 1.0) : null;

    final isWorking = widget.mode == VaultCeremonyMode.create
        ? backupState.isCreating
        : backupState.isRestoring || isDriveDownloading;

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (widget.controller.isSuccessVisible) {
      return RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ObsidianVeil(isDark: isDark),
              Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                  ),
                  child: BackupVaultSuccessSeal(
                    title: widget.controller.successTitle,
                    subtitle: widget.controller.successSubtitle,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ObsidianVeil(isDark: isDark),
            Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppDimensions.pagePaddingH,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: DaftarCard(
                    variant: DaftarCardVariant.compact,
                    padding: const EdgeInsetsDirectional.all(
                      AppDimensions.spacingXxl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.backupCeremonyTitle,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: inkPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Gap(AppDimensions.spacingXl),
                        _BreathingLock(reduceMotion: reduceMotion),
                        const Gap(AppDimensions.spacingXl),
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: determinateProgress != null
                              ? CircularProgressIndicator(
                                  value: determinateProgress,
                                  strokeWidth: 4,
                                  backgroundColor: trackColor,
                                  color: AppColors.lapis400,
                                )
                              : CircularProgressIndicator(
                                  strokeWidth: 4,
                                  backgroundColor: trackColor,
                                  color: AppColors.lapis400,
                                ),
                        ),
                        const Gap(AppDimensions.spacingLg),
                        AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : AppDimensions.animationFast,
                          child: Text(
                            isWorking
                                ? _phaseMessage
                                : l10n.backupRestoring,
                            key: ValueKey<String>(
                              isWorking ? _phaseMessage : 'idle',
                            ),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: inkSecondary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObsidianVeil extends StatelessWidget {
  const _ObsidianVeil({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: ColoredBox(
        color: (isDark ? AppColors.surface0 : AppColors.surface0Light)
            .withValues(alpha: 0.72),
      ),
    );
  }
}

class _BreathingLock extends StatefulWidget {
  const _BreathingLock({required this.reduceMotion});

  final bool reduceMotion;

  @override
  State<_BreathingLock> createState() => _BreathingLockState();
}

class _BreathingLockState extends State<_BreathingLock>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppDimensions.animationBreath,
    );
    _scale = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _ctrl, curve: AppMotion.curveBreath),
    );
    if (!widget.reduceMotion) {
      unawaited(_ctrl.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.reduceMotion ? 1.0 : _scale.value,
          child: child,
        );
      },
      child: Icon(
        Icons.lock_outline_rounded,
        size: 48,
        color: inkPrimary,
      ),
    );
  }
}
