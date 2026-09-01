import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Circular store logo with wax-seal rings and optional camera badge.
class StoreLogoSeal extends StatefulWidget {
  const StoreLogoSeal({
    required this.diameter,
    required this.isDark,
    required this.hasLogo,
    required this.logoPath,
    required this.profile,
    required this.loadLogoBytes,
    super.key,
    this.tappable = false,
    this.onTap,
    this.showCameraBadge = false,
    this.ringWidth = AppDimensions.dividerThickness,
  });

  final double diameter;
  final bool isDark;
  final bool hasLogo;
  final String? logoPath;
  final MerchantProfile? profile;
  final Future<Uint8List?> Function(String path) loadLogoBytes;
  final bool tappable;
  final VoidCallback? onTap;
  final bool showCameraBadge;
  final double ringWidth;

  @override
  State<StoreLogoSeal> createState() => _StoreLogoSealState();
}

class _StoreLogoSealState extends State<StoreLogoSeal> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ringColor =
        widget.isDark ? AppColors.surface0 : AppColors.surface0Light;
    final placeholderColor =
        widget.isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final placeholderFill =
        widget.isDark ? AppColors.surface3 : AppColors.surface2Light;
    final outerRingColor = widget.isDark
        ? AppColors.borderStrong
        : AppColors.borderStrongLight;
    final innerDiameter = widget.diameter - (widget.ringWidth * 2);

    Widget logoContent;
    if (widget.hasLogo && widget.logoPath != null) {
      final bytesKey = ValueKey<Object?>(
        widget.profile?.updatedAt ?? widget.logoPath,
      );
      logoContent = FutureBuilder<Uint8List?>(
        key: ValueKey<String>(
          'logo_${widget.logoPath}${widget.profile?.updatedAt}',
        ),
        future: widget.loadLogoBytes(widget.logoPath!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Skeletonizer(
              child: Bone.circle(size: innerDiameter),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) {
            return ColoredBox(
              color: placeholderFill,
              child: Icon(
                Icons.store_rounded,
                size: innerDiameter * 0.38,
                color: placeholderColor,
              ),
            );
          }
          return Image.memory(
            bytes,
            key: bytesKey,
            fit: BoxFit.cover,
            width: innerDiameter,
            height: innerDiameter,
            gaplessPlayback: true,
          );
        },
      );
    } else {
      logoContent = ColoredBox(
        color: placeholderFill,
        child: Icon(
          Icons.store_rounded,
          size: innerDiameter * 0.38,
          color: placeholderColor,
        ),
      );
    }

    final avatar = AnimatedScale(
      scale: _pressed && widget.tappable ? 0.96 : 1,
      duration: AppDimensions.animationFast,
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: widget.diameter + 16,
        height: widget.diameter + 16,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Wax-seal outer ring
            Container(
              width: widget.diameter + 12,
              height: widget.diameter + 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: outerRingColor.withValues(alpha: 0.35),
                  width: 0.5,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: widget.isDark
                    ? AppGlows.khazaFloat
                    : AppGlows.shadowFloat,
              ),
              child: Container(
                width: widget.diameter,
                height: widget.diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringColor,
                    width: widget.ringWidth,
                  ),
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: innerDiameter,
                    height: innerDiameter,
                    child: logoContent,
                  ),
                ),
              ),
            ),
            if (widget.showCameraBadge && widget.tappable)
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isDark
                        ? AppColors.surface4
                        : AppColors.surface1Light,
                    border: Border.all(
                      color: widget.isDark
                          ? AppColors.borderSubtle
                          : AppColors.borderSubtleLight,
                      width: AppDimensions.dividerThickness,
                    ),
                    boxShadow: widget.isDark
                        ? AppGlows.haloXs
                        : AppGlows.shadowSoft,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spacingXs),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: AppDimensions.iconSmall,
                      color: widget.isDark
                          ? AppColors.inkSecondary
                          : AppColors.inkSecondaryLight,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (!widget.tappable || widget.onTap == null) {
      return avatar;
    }

    return Semantics(
      button: true,
      label: widget.showCameraBadge ? 'Upload logo' : 'Store logo',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          unawaited(HapticService.light());
          widget.onTap?.call();
        },
        child: avatar,
      ),
    );
  }
}
