import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// Transparent title row that scrolls with screen content.
///
/// Unlike a pinned [SliverAppBar] or a fixed [Stack] overlay, this scrolls
/// off-screen naturally and never paints an opaque strip over content below.
class DaftarScrollScreenTitle extends StatelessWidget {
  const DaftarScrollScreenTitle({
    this.title,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    super.key,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final effectiveLeading = leading ??
        (automaticallyImplyLeading && canPop
            ? BackButton(onPressed: () => Navigator.maybePop(context))
            : null);

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: AppDimensions.appBarHeight,
        child: NavigationToolbar(
          leading: effectiveLeading,
          middle: title,
          trailing: actions != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                )
              : null,
          centerMiddle: false,
        ),
      ),
    );
  }
}

/// [DaftarScrollScreenTitle] as a [CustomScrollView] sliver.
class DaftarScrollScreenTitleSliver extends StatelessWidget {
  const DaftarScrollScreenTitleSliver({
    this.title,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    super.key,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: DaftarScrollScreenTitle(
        title: title,
        leading: leading,
        actions: actions,
        automaticallyImplyLeading: automaticallyImplyLeading,
      ),
    );
  }
}
