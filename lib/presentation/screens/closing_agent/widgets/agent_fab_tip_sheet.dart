import 'package:daftar/presentation/shared/widgets/daftar_coach_mark.dart';
import 'package:flutter/material.dart';

/// Retired bottom-sheet chrome. Spotlight copy lives on [DaftarCoachMarkTooltip].
class AgentFabTipSheet extends StatelessWidget {
  /// Creates the tip body (tests and leftover callers).
  const AgentFabTipSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DaftarCoachMarkTooltip(
      onGotIt: () => Navigator.of(context).maybePop(),
    );
  }
}
