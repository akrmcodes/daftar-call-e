import 'dart:async' show Completer, unawaited;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gap/gap.dart';
import 'package:path_provider/path_provider.dart';

/// WhatsApp-style circular logo crop — pinch to zoom, drag to reposition.
class MerchantLogoCropScreen extends StatefulWidget {
  const MerchantLogoCropScreen({
    required this.imagePath,
    super.key,
  });

  final String imagePath;

  /// Opens the crop flow and returns the cropped image path, or `null` if cancelled.
  static Future<String?> show(BuildContext context, {required String imagePath}) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (context) => MerchantLogoCropScreen(imagePath: imagePath),
      ),
    );
  }

  @override
  State<MerchantLogoCropScreen> createState() => _MerchantLogoCropScreenState();
}

class _MerchantLogoCropScreenState extends State<MerchantLogoCropScreen> {
  static const _cropDiameter = 280.0;
  static const _maxScaleMultiplier = 4.0;
  static const _exportPixelRatio = 2.0;

  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _cropBoundaryKey = GlobalKey();

  Size? _displaySize;
  double _minScale = 1;
  double _sliderScale = 1;
  bool _isExporting = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
    unawaited(_loadImageSize());
  }

  @override
  void dispose() {
    _transformController
      ..removeListener(_onTransformChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final completer = Completer<Size>();
      ui.decodeImageFromList(bytes, (image) {
        completer.complete(
          Size(image.width.toDouble(), image.height.toDouble()),
        );
      });
      final size = await completer.future;
      if (!mounted) {
        return;
      }
      _initializeForImage(size);
    } on Object {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _initializeForImage(Size imageSize) {
    final coverScale = math.max(
      _cropDiameter / imageSize.width,
      _cropDiameter / imageSize.height,
    );
    final displaySize = Size(
      imageSize.width * coverScale,
      imageSize.height * coverScale,
    );

    setState(() {
      _displaySize = displaySize;
      _minScale = 1;
      _sliderScale = 1;
      _initialized = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _centerImage(displaySize);
    });
  }

  void _centerImage(Size displaySize) {
    final dx = (_cropDiameter - displaySize.width) / 2;
    final dy = (_cropDiameter - displaySize.height) / 2;
    _transformController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1);
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _sliderScale).abs() > 0.01) {
      setState(() => _sliderScale = scale);
    }
  }

  void _onSliderChanged(double value) {
    final current = _transformController.value;
    final currentScale = current.getMaxScaleOnAxis();
    if (currentScale == 0) {
      return;
    }

    final scaleFactor = value / currentScale;
    const cropCenter = Offset(_cropDiameter / 2, _cropDiameter / 2);

    _transformController.value = Matrix4.copy(current)
      ..translateByDouble(cropCenter.dx, cropCenter.dy, 0, 1)
      ..scaleByDouble(scaleFactor, scaleFactor, 1, 1)
      ..translateByDouble(-cropCenter.dx, -cropCenter.dy, 0, 1);

    setState(() => _sliderScale = value);
  }

  double get _maxScale => _maxScaleMultiplier;

  Future<void> _onConfirm() async {
    if (_isExporting || !_initialized) {
      return;
    }

    setState(() => _isExporting = true);
    await HapticService.buttonPress();

    try {
      final boundary = _cropBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final image = await boundary.toImage(pixelRatio: _exportPixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/merchant_logo_crop_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(outputPath).writeAsBytes(
        byteData.buffer.asUint8List(),
        flush: true,
      );

      if (mounted) {
        Navigator.of(context).pop(outputPath);
      }
    } on Object {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final guideColor =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surface0 : AppColors.surface0Light,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.backupRestoreCancel,
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.merchantBrandingCropTitle,
          style: AppTextStyles.titleMedium.copyWith(color: inkPrimary),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppDimensions.pagePaddingH,
              ),
              child: Text(
                l10n.merchantBrandingCropHint,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: inkMuted),
              ),
            ),
            const Gap(AppDimensions.spacingXl),
            Expanded(
              child: _initialized && _displaySize != null
                  ? ColoredBox(
                      color: Colors.black.withValues(alpha: 0.58),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildCropViewport(),
                          IgnorePointer(
                            child: CustomPaint(
                              size: const Size(_cropDiameter, _cropDiameter),
                              painter: _LogoCropGuidePainter(
                                guideColor: guideColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: SizedBox(
                        width: _cropDiameter,
                        height: _cropDiameter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? AppColors.surface3
                                : AppColors.surface2Light,
                          ),
                        ),
                      ),
                    ),
            ),
            if (_initialized) ...[
              const Gap(AppDimensions.spacingLg),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppDimensions.pagePaddingH,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.zoom_out_map,
                      size: AppDimensions.iconSmall,
                      color: inkMuted,
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: isDark
                              ? AppColors.inkSecondary
                              : AppColors.inkSecondaryLight,
                          inactiveTrackColor: isDark
                              ? AppColors.surface5
                              : AppColors.surface3Light,
                          thumbColor: inkPrimary,
                          overlayColor: AppColors.lapis400.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        child: Slider(
                          value: _sliderScale.clamp(_minScale, _maxScale),
                          min: _minScale,
                          max: _maxScale,
                          onChanged: _isExporting ? null : _onSliderChanged,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.zoom_in,
                      size: AppDimensions.iconSmall,
                      color: inkMuted,
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppDimensions.pagePaddingH,
                AppDimensions.spacingMd,
                AppDimensions.pagePaddingH,
                AppDimensions.spacingXl,
              ),
              child: DaftarButton(
                label: l10n.merchantBrandingCropConfirm,
                isExpanded: true,
                isLoading: _isExporting,
                onPressed: !_initialized || _isExporting ? null : _onConfirm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropViewport() {
    final displaySize = _displaySize!;

    return SizedBox(
      width: _cropDiameter,
      height: _cropDiameter,
      child: RepaintBoundary(
        key: _cropBoundaryKey,
        child: ClipRect(
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: _minScale,
            maxScale: _maxScale,
            clipBehavior: Clip.none,
            child: Image.file(
              File(widget.imagePath),
              width: displaySize.width,
              height: displaySize.height,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(
                  color: AppColors.surface3,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: AppDimensions.iconLarge,
                    color: AppColors.inkMuted,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular crop ring drawn above the image viewport.
class _LogoCropGuidePainter extends CustomPainter {
  const _LogoCropGuidePainter({required this.guideColor});

  final Color guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = guideColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoCropGuidePainter oldDelegate) =>
      oldDelegate.guideColor != guideColor;
}
