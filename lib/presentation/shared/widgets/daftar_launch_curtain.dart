import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/widgets/daftar_brand_mark.dart';
import 'package:flutter/material.dart';

/// Brief Flutter launch curtain — seamless handoff from native splash.
///
/// Monochrome canvas (`surface0` / `surface0Light`), centered mark with
/// `glowXl` at full opacity from the first frame. Not a route; dismisses
/// automatically and never blocks bootstrap.
class DaftarLaunchCurtain extends StatefulWidget {
  /// Creates the launch curtain overlay.
  const DaftarLaunchCurtain({super.key});

  /// Key on the curtain while visible (absent after dismiss).
  static const overlayKey = ValueKey<String>('daftarLaunchCurtain');

  @override
  State<DaftarLaunchCurtain> createState() => _DaftarLaunchCurtainState();
}

class _DaftarLaunchCurtainState extends State<DaftarLaunchCurtain>
    with SingleTickerProviderStateMixin {
  static const _totalMs = 450;
  static const double _holdWeight = 200;
  static const double _fadeOutWeight = 250;

  late final AnimationController _controller;
  late final Animation<double> _opacity;
  bool _started = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: _holdWeight,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0).chain(
          CurveTween(curve: AppMotion.curveExit),
        ),
        weight: _fadeOutWeight,
      ),
    ]).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _dismissed = true);
      return;
    }
    unawaited(
      _controller.forward().whenComplete(() {
        if (mounted) {
          setState(() => _dismissed = true);
        }
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvas = isDark ? AppColors.surface0 : AppColors.surface0Light;

    return Positioned.fill(
      key: DaftarLaunchCurtain.overlayKey,
      child: IgnorePointer(
        child: ColoredBox(
          color: canvas,
          child: FadeTransition(
            opacity: _opacity,
            child: Center(
              child: Semantics(
                image: true,
                label: l10n.appTitle,
                child: const DaftarBrandMark(
                  size: 96,
                  glow: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
