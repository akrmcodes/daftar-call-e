import 'package:flutter/material.dart';

/// Convenience extensions on [BuildContext] for accessing commonly
/// used theme and layout properties without verbose boilerplate.
///
/// ## Usage
/// ```dart
/// final colors = context.colorScheme;
/// final isRtl = context.isRtl;
/// final width = context.screenWidth;
/// ```
extension ContextExtensions on BuildContext {
  // ── Theme ──────────────────────────────────────────────────────────

  /// The current [ThemeData].
  ThemeData get theme => Theme.of(this);

  /// The current [TextTheme] from the active theme.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// The current [ColorScheme] from the active theme.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  // ── Media Query ────────────────────────────────────────────────────

  /// The current [MediaQueryData].
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Screen width in logical pixels.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Screen height in logical pixels.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// The bottom padding (safe area inset for notches/home indicators).
  double get bottomPadding => MediaQuery.paddingOf(this).bottom;

  /// The top padding (safe area inset for status bar).
  double get topPadding => MediaQuery.paddingOf(this).top;

  /// The device pixel ratio.
  double get devicePixelRatio => MediaQuery.devicePixelRatioOf(this);

  // ── Directionality ─────────────────────────────────────────────────

  /// `true` if the current text direction is right-to-left.
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;

  /// `true` if the current text direction is left-to-right.
  bool get isLtr => Directionality.of(this) == TextDirection.ltr;

  // ── Navigation ─────────────────────────────────────────────────────

  /// The current [NavigatorState].
  NavigatorState get navigator => Navigator.of(this);

  /// The current [FocusScopeNode] — useful for dismissing keyboard.
  FocusScopeNode get focusScope => FocusScope.of(this);

  /// Dismisses the on-screen keyboard.
  void unfocus() => focusScope.unfocus();
}
