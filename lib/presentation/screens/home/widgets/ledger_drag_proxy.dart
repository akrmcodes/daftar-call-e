import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// Drag proxy for reorderable ledger tiles on the home grid.
Widget buildLedgerDragProxy(
  int index,
  Widget child,
  ImageProvider<Object>? screenshot,
) {
  return Transform.scale(
    scale: 1.04,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    ),
  );
}
