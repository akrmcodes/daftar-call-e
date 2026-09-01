import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/presentation/screens/ledger/widgets/archive_vault_success_seal.dart';
import 'package:flutter/material.dart';

class ArchiveCeremonyController extends ChangeNotifier {
  bool _isSuccessVisible = false;
  String _successTitle = '';
  String _successSubtitle = '';
  bool _dismissed = false;

  bool get isSuccessVisible => _isSuccessVisible;
  String get successTitle => _successTitle;
  String get successSubtitle => _successSubtitle;
  bool get dismissed => _dismissed;

  void revealSuccess({required String title, required String subtitle}) {
    if (_dismissed) {
      return;
    }
    _isSuccessVisible = true;
    _successTitle = title;
    _successSubtitle = subtitle;
    notifyListeners();
  }

  void dismiss() {
    if (_dismissed) {
      return;
    }
    _dismissed = true;
    notifyListeners();
  }
}

abstract final class ArchiveCeremonyOverlay {
  static const Duration _preRevealDelay = Duration(milliseconds: 60);
  static const Duration _successHoldDuration = Duration(milliseconds: 2000);
  static const Duration _postDismissSettle = AppDimensions.animationSnappyExit;

  static ArchiveCeremonyController show(BuildContext context) {
    final controller = ArchiveCeremonyController();

    unawaited(
      showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        transitionDuration: AppDimensions.animationMedium,
        transitionBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: animation.status == AnimationStatus.reverse
                ? AppMotion.curveExit
                : AppMotion.curveEnter,
          );
          return FadeTransition(opacity: curved, child: child);
        },
        pageBuilder: (dialogContext, _, _) {
          return _ArchiveCeremonyContent(
            controller: controller,
            onDismiss: () {
              if (dialogContext.mounted) {
                Navigator.of(dialogContext, rootNavigator: true).pop();
              }
            },
          );
        },
      ),
    );

    return controller;
  }

  static Future<bool> runWithCeremony({
    required BuildContext context,
    required Future<bool> Function() operation,
    required String successTitle,
    required String successSubtitle,
  }) async {
    final ok = await operation();

    if (!context.mounted) {
      return ok;
    }

    if (!ok) {
      return false;
    }

    final controller = show(context);
    await Future<void>.delayed(_preRevealDelay);
    if (!context.mounted) {
      controller.dismiss();
      return ok;
    }

    controller.revealSuccess(
      title: successTitle,
      subtitle: successSubtitle,
    );

    await Future<void>.delayed(_successHoldDuration);

    controller.dismiss();
    await Future<void>.delayed(_postDismissSettle);
    return ok;
  }
}

class _ArchiveCeremonyContent extends StatefulWidget {
  const _ArchiveCeremonyContent({
    required this.controller,
    required this.onDismiss,
  });

  final ArchiveCeremonyController controller;
  final VoidCallback onDismiss;

  @override
  State<_ArchiveCeremonyContent> createState() => _ArchiveCeremonyContentState();
}

class _ArchiveCeremonyContentState extends State<_ArchiveCeremonyContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _visibilityController;
  late final Animation<double> _fadeAnimation;
  bool _exitHandled = false;

  @override
  void initState() {
    super.initState();
    _visibilityController = AnimationController(
      vsync: this,
      duration: AppDimensions.animationMedium,
      reverseDuration: AppDimensions.animationSnappyExit,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _visibilityController,
      curve: AppMotion.curveEnter,
      reverseCurve: AppMotion.curveExit,
    );
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _visibilityController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) {
      return;
    }

    if (widget.controller.isSuccessVisible && _visibilityController.value == 0) {
      unawaited(_visibilityController.forward());
    }

    if (widget.controller.dismissed && !_exitHandled) {
      _exitHandled = true;
      unawaited(
        _visibilityController.reverse().then((_) {
          if (mounted) {
            widget.onDismiss();
          }
        }),
      );
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isSuccessVisible && !_exitHandled) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnimation,
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
                  child: ArchiveVaultSuccessSeal(
                    title: widget.controller.successTitle,
                    subtitle: widget.controller.successSubtitle,
                  ),
                ),
              ),
            ],
          ),
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
