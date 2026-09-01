import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Daftar brand mark — black on light canvases, bone on dark canvases.
///
/// The lapis bar is baked into the SVG. Do not tint with [ColorFilter].
/// Never mirrored in RTL (`matchTextDirection: false`).
class DaftarBrandMark extends StatelessWidget {
  const DaftarBrandMark({
    super.key,
    this.size = 64,
    this.glow = false,
  });

  /// Logical width and height. The SVG is square.
  final double size;

  /// When true, applies [AppGlows.heroBrand]. Use as the sole lapis-glow
  /// moment on that screen (lock / splash).
  final bool glow;

  static const String onLightAsset = 'assets/brand/daftar_mark_on_light.svg';
  static const String onDarkAsset = 'assets/brand/daftar_mark_on_dark.svg';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final mark = SvgPicture.asset(
      isDark ? onDarkAsset : onLightAsset,
      width: size,
      height: size,
    );

    return Semantics(
      image: true,
      label: l10n.appTitle,
      child: SizedBox(
        width: size,
        height: size,
        child: glow
            ? DecoratedBox(
                decoration: const BoxDecoration(boxShadow: AppGlows.heroBrand),
                child: mark,
              )
            : mark,
      ),
    );
  }
}
