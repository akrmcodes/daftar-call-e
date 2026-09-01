import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Khazna v3 text field with floating label and lapis focus ring.
///
/// See `docs/design_system.md` §9.1.
class DaftarTextField extends StatefulWidget {
  const DaftarTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.textDirection,
    this.minLines,
    this.maxLines,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextDirection? textDirection;
  final int? minLines;
  final int? maxLines;

  @override
  State<DaftarTextField> createState() => _DaftarTextFieldState();
}

class _DaftarTextFieldState extends State<DaftarTextField> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;
  bool _ownsController = false;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onTextChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});
  void _onTextChanged() => setState(() {});

  bool get _hasError =>
      widget.errorText != null && widget.errorText!.isNotEmpty;
  bool get _isFocused => _focusNode.hasFocus;
  bool get _hasText => _controller.text.isNotEmpty;
  bool get _floated => _isFocused || _hasText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final fill = isDark ? AppColors.surface5 : AppColors.surface3Light;
    final disabledFill = isDark ? AppColors.surface3 : AppColors.surface2Light;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final inkDisabled = isDark
        ? AppColors.inkDisabled
        : AppColors.inkDisabledLight;
    final errorColor = isDark ? AppColors.debt : AppColors.debtLight;

    final borderColor = _hasError
        ? errorColor
        : _isFocused
        ? lapis
        : Colors.transparent;
    const borderWidthFocused = 1.5;
    final borderWidth = _hasError || _isFocused ? borderWidthFocused : 0.0;
    final labelColor = _hasError
        ? errorColor
        : _isFocused
        ? lapis
        : inkSecondary;
    final iconColor = _hasError
        ? errorColor
        : !widget.enabled
        ? inkDisabled
        : _isFocused
        ? inkPrimary
        : inkMuted;
    final showHint = !_hasText && (widget.label == null || !_floated);
    final maxLines = widget.maxLines ?? widget.minLines ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: AppDimensions.animationMedium,
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: widget.enabled ? fill : disabledFill,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: borderWidth > 0
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppDimensions.spacingLg,
              vertical: AppDimensions.spacingMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.label != null)
                  AnimatedDefaultTextStyle(
                    duration: AppDimensions.animationMedium,
                    curve: Curves.easeInOutCubic,
                    style:
                        (_floated
                                ? AppTextStyles.labelSmall
                                : AppTextStyles.bodyLarge)
                            .copyWith(color: labelColor),
                    child: Text(widget.label!),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.prefixIcon != null) ...[
                      Icon(
                        widget.prefixIcon,
                        size: AppDimensions.iconMedium,
                        color: iconColor,
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: widget.enabled,
                        readOnly: widget.readOnly,
                        autofocus: widget.autofocus,
                        obscureText: widget.obscureText,
                        maxLength: widget.maxLength,
                        minLines: widget.minLines,
                        maxLines: maxLines,
                        keyboardType: widget.keyboardType,
                        textInputAction: widget.textInputAction,
                        inputFormatters: widget.inputFormatters,
                        textCapitalization: widget.textCapitalization,
                        textDirection: widget.textDirection,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: inkPrimary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          hintText: showHint ? widget.hint : null,
                          hintStyle: AppTextStyles.bodyLarge.copyWith(
                            color: inkMuted,
                          ),
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: widget.onChanged,
                        onSubmitted: widget.onSubmitted,
                      ),
                    ),
                    if (_hasText && widget.enabled && !widget.readOnly)
                      IconButton(
                        onPressed: () {
                          _controller.clear();
                          widget.onClear?.call();
                          widget.onChanged?.call('');
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: inkMuted,
                          size: AppDimensions.iconMedium,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: AppDimensions.minTapTarget,
                          minHeight: AppDimensions.minTapTarget,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (widget.helperText != null ||
            widget.errorText != null ||
            widget.maxLength != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: AppDimensions.spacingXs,
              start: AppDimensions.spacingLg,
              end: AppDimensions.spacingLg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _hasError ? widget.errorText! : (widget.helperText ?? ''),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _hasError ? errorColor : inkSecondary,
                    ),
                  ),
                ),
                if (widget.maxLength != null)
                  Text(
                    '${_controller.text.length}/${widget.maxLength}',
                    style: AppTextStyles.bodySmall.copyWith(color: inkMuted),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
