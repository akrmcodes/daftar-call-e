import 'package:flutter/material.dart';

/// iOS-grade page snap — low flick threshold, fast spring landing.
class SnappyPageScrollPhysics extends PageScrollPhysics {
  const SnappyPageScrollPhysics({super.parent});

  @override
  SnappyPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnappyPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 1.5;

  @override
  double get minFlingVelocity => 20;

  @override
  Tolerance get tolerance => const Tolerance(
    velocity: 20,
    distance: 0.35,
  );

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.42,
    stiffness: 460,
    damping: 30,
  );
}
