import 'package:flutter/services.dart';

/// Khazna v3 — haptic feedback engine.
///
/// Wraps `HapticFeedback.*` with try/catch (platforms without haptic hardware
/// will silently no-op) and exposes both:
///   * low-level methods (`light`, `medium`, `heavy`, `selection`)
///   * semantic methods that mirror `docs/design_system.md` §7.5 directly
///
/// Haptics are an accessibility channel — they fire regardless of ringer
/// silent mode. They are NEVER reduced under `MediaQuery.disableAnimations`.
abstract final class HapticService {
  // ==========================================================================
  // LOW-LEVEL — direct mapping to platform haptic types
  // ==========================================================================

  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } on Object catch (_) {/* unsupported platform */}
  }

  static Future<void> medium() async {
    try {
      await HapticFeedback.mediumImpact();
    } on Object catch (_) {}
  }

  static Future<void> heavy() async {
    try {
      await HapticFeedback.heavyImpact();
    } on Object catch (_) {}
  }

  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } on Object catch (_) {}
  }

  // ==========================================================================
  // SEMANTIC — mirrors design-system §7.5 haptic map
  // ==========================================================================

  /// Successful save / create — satisfying confirmation pulse.
  static Future<void> success() => medium();

  static Future<void> transactionSaved() => success();
  static Future<void> deleteConfirmed() => heavy();

  /// Undo on deletion snackbars — confirms tap and data restoration.
  static Future<void> undoTapped() => medium();

  /// PIN / safe numpad digit — crisp mechanical tick.
  static Future<void> pinPress() => selection();
  static Future<void> amountPadDigit() => selection();
  static Future<void> amountPadDelete() => light();

  static Future<void> bottomSheetSnap() => light();
  static Future<void> pullRefreshThreshold() => medium();
  static Future<void> swipeThreshold() => selection();
  static Future<void> toggleFlipped() => light();
  static Future<void> buttonPress() => light();
  static Future<void> longPress() => medium();

  static Future<void> validationError() => heavy();
  static Future<void> saveSuccess() => medium();

  static Future<void> lockUnlockSuccess() => light();
  static Future<void> lockUnlockFailure() => heavy();

  static Future<void> reorderPickUp() => medium();
  static Future<void> reorderDrop() => light();

  /// Tier upgrade celebration — heavy impact followed by light 200ms later.
  /// Paired with the lapis-glow expansion animation on the balance card.
  static Future<void> tierUpgrade() async {
    await heavy();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await light();
  }
}
