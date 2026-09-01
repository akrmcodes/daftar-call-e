import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// Expands the hit-test area to at least [minSize] without changing how
/// [child] is painted — the visual stays centered in the larger box.
///
/// Pair with [HitTestBehavior.opaque] on a parent [GestureDetector] so
/// transparent padding remains tappable.
class DaftarTapTarget extends StatelessWidget {
  const DaftarTapTarget({
    required this.child,
    super.key,
    this.minSize = AppDimensions.minTapTarget,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final double minSize;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      child: Align(
        alignment: alignment,
        child: child,
      ),
    );
  }
}
