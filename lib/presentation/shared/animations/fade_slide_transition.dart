import 'dart:async';

import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// Fades and subtly slides a child into view.
///
/// Use this for cards, list sections, and other lightweight entrance motion.
class FadeSlideTransition extends StatefulWidget {
  const FadeSlideTransition({
    required this.child,
    super.key,
    this.beginOffset = const Offset(0, 0.06),
    this.duration = AppDimensions.animationMedium,
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Offset beginOffset;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  @override
  State<FadeSlideTransition> createState() => _FadeSlideTransitionState();
}

class _FadeSlideTransitionState extends State<FadeSlideTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: widget.duration,
    vsync: this,
  );

  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void didUpdateWidget(covariant FadeSlideTransition oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAnimation() {
    if (WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations) {
      _controller.value = 1;
      return;
    }

    if (widget.delay == Duration.zero) {
      unawaited(_controller.forward());
      return;
    }

    _delayTimer = Timer(widget.delay, () {
      if (mounted) {
        unawaited(_controller.forward());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations) {
      return widget.child;
    }

    final animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    final slideAnimation = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(animation);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: FractionalTranslation(
            translation: slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
