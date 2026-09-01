import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:flutter/material.dart';

/// Sheet/header close control without Material [Tooltip] (avoids ticker conflicts).
class DaftarCloseIconButton extends StatelessWidget {
  const DaftarCloseIconButton({
    super.key,
    this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = MaterialLocalizations.of(context).closeButtonTooltip;

    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed == null
            ? null
            : () {
                unawaited(HapticService.selection());
                onPressed!();
              },
        child: SizedBox(
          width: AppDimensions.minTapTarget,
          height: AppDimensions.minTapTarget,
          child: Icon(
            Icons.close_rounded,
            size: AppDimensions.iconMedium,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
