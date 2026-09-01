import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Google profile avatar with wax-seal rings — the identity mark of the account passport.
class AccountAvatarSeal extends StatefulWidget {
  const AccountAvatarSeal({
    required this.isDark,
    required this.displayName,
    super.key,
    this.photoUrl,
    this.diameter = 104,
    this.isPlaceholder = false,
    this.showGlow = true,
  });

  final bool isDark;
  final String displayName;
  final String? photoUrl;
  final double diameter;
  final bool isPlaceholder;
  final bool showGlow;

  @override
  State<AccountAvatarSeal> createState() => _AccountAvatarSealState();
}

class _AccountAvatarSealState extends State<AccountAvatarSeal> {
  bool _imageFailed = false;

  @override
  void didUpdateWidget(covariant AccountAvatarSeal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _imageFailed = false;
    }
  }

  String? get _resolvedPhotoUrl {
    final raw = widget.photoUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    return raw;
  }

  bool get _showNetworkPhoto =>
      !widget.isPlaceholder && _resolvedPhotoUrl != null && !_imageFailed;

  @override
  Widget build(BuildContext context) {
    final ringColor =
        widget.isDark ? AppColors.surface0 : AppColors.surface0Light;
    final outerRingColor = widget.isDark
        ? AppColors.borderStrong
        : AppColors.borderStrongLight;
    final fillColor =
        widget.isDark ? AppColors.surface4 : AppColors.surface2Light;
    final inkPrimary =
        widget.isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted =
        widget.isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final initials = _initials(widget.displayName);
    final innerSize = widget.diameter - 8;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: widget.showGlow && widget.isDark && !widget.isPlaceholder
            ? AppGlows.haloSm
            : null,
      ),
      child: Container(
        width: widget.diameter,
        height: widget.diameter,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ringColor,
          border: Border.all(
            color: outerRingColor,
            width: AppDimensions.dividerThickness,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isPlaceholder
                  ? (widget.isDark
                      ? AppColors.borderSubtle
                      : AppColors.borderSubtleLight)
                  : AppColors.lapis400.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: SizedBox(
              width: innerSize,
              height: innerSize,
              child: _showNetworkPhoto
                  ? Image.network(
                      _resolvedPhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholderContent(
                        fillColor,
                        inkPrimary,
                        inkMuted,
                        initials,
                      ),
                    )
                  : _placeholderContent(
                      fillColor,
                      inkPrimary,
                      inkMuted,
                      initials,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderContent(
    Color fillColor,
    Color inkPrimary,
    Color inkMuted,
    String initials,
  ) {
    if (widget.isPlaceholder) {
      return ColoredBox(
        color: fillColor,
        child: Icon(
          Icons.account_circle_outlined,
          size: widget.diameter * 0.42,
          color: inkMuted,
        ),
      );
    }

    return ColoredBox(
      color: fillColor,
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.titleLarge.copyWith(
            color: inkPrimary,
            fontSize: widget.diameter * 0.28,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    String firstChar(String s) => s.isNotEmpty ? s[0] : '';
    if (parts.length == 1) {
      return firstChar(parts.first).toUpperCase();
    }
    return '${firstChar(parts.first)}${firstChar(parts.last)}'.toUpperCase();
  }
}

/// Skeleton placeholder matching [AccountAvatarSeal] geometry.
class AccountAvatarSealSkeleton extends StatelessWidget {
  const AccountAvatarSealSkeleton({
    super.key,
    this.diameter = 104,
  });

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: Bone.circle(size: diameter),
    );
  }
}
