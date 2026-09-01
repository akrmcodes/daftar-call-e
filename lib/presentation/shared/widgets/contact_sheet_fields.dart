import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared height for single-line contact-sheet input surfaces.
const double kContactSheetFieldHeight = 52;

/// Shared corner radius for contact-sheet input surfaces.
const double kContactSheetFieldRadius = 10;

/// Name field flex weight in the name/phone row.
const int kContactSheetNameFlex = 3;

/// Phone field flex weight in the name/phone row.
const int kContactSheetPhoneFlex = 2;

/// Borderless input that lives inside an [AnimatedContainer] surface.
///
/// Listens to its own [focusNode] to animate the lapis focus ring.
class ContactSheetInputField extends StatefulWidget {
  const ContactSheetInputField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.enabled,
    required this.fill,
    required this.lapis,
    required this.inkPrimary,
    required this.inkMuted,
    required this.borderSubtle,
    super.key,
    this.prefixIcon,
    this.leading,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.textDirection,
    this.inputFormatters,
    this.autofillHints,
    this.suffix,
    this.validator,
    this.onSubmitted,
    this.minLines,
    this.maxLines,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData? prefixIcon;
  final Widget? leading;
  final bool enabled;
  final bool autofocus;
  final Color fill;
  final Color lapis;
  final Color inkPrimary;
  final Color inkMuted;
  final Color borderSubtle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextDirection? textDirection;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final int? minLines;
  final int? maxLines;

  @override
  State<ContactSheetInputField> createState() => _ContactSheetInputFieldState();
}

class _ContactSheetInputFieldState extends State<ContactSheetInputField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  bool get _isMultiline =>
      (widget.maxLines ?? 1) > 1 || (widget.minLines ?? 1) > 1;

  @override
  Widget build(BuildContext context) {
    final isFocused = widget.focusNode.hasFocus;

    final field = TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      textDirection: widget.textDirection,
      autofillHints: widget.autofillHints?.toList(),
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      strutStyle: StrutStyle(
        fontFamily: widget.textDirection == null
            ? AppTextStyles.arabicFontFamily
            : AppTextStyles.latinFontFamily,
        fontSize: AppTextStyles.titleSmall.fontSize,
        height: 1,
        leading: 0,
        forceStrutHeight: true,
        fontWeight: FontWeight.w500,
      ),
      style: AppTextStyles.titleSmall.copyWith(
        fontWeight: FontWeight.w500,
        color: widget.inkPrimary,
        height: 1,
        leadingDistribution: TextLeadingDistribution.even,
        fontFamily: widget.textDirection == null
            ? AppTextStyles.arabicFontFamily
            : AppTextStyles.latinFontFamily,
      ),
      decoration: InputDecoration(
        isDense: true,
        visualDensity: VisualDensity.compact,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
        hintText: widget.hint,
        hintStyle: AppTextStyles.bodySmall.copyWith(
          color: widget.inkMuted,
          fontWeight: FontWeight.w400,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        suffix: widget.suffix,
        contentPadding: EdgeInsetsDirectional.fromSTEB(
          0,
          _isMultiline ? AppDimensions.spacingSm : 14,
          AppDimensions.spacingMd,
          _isMultiline ? AppDimensions.spacingSm : 14,
        ),
      ),
    );

    if (_isMultiline) {
      return AnimatedContainer(
        duration: AppDimensions.animationFast,
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(
          minHeight: kContactSheetFieldHeight,
        ),
        decoration: BoxDecoration(
          color: widget.fill,
          borderRadius: BorderRadius.circular(kContactSheetFieldRadius),
          border: isFocused
              ? Border.all(color: widget.lapis, width: 1.5)
              : Border.all(color: widget.borderSubtle, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.prefixIcon != null)
              SizedBox(
                width: kContactSheetFieldHeight,
                height: kContactSheetFieldHeight,
                child: Center(
                  child: Icon(
                    widget.prefixIcon,
                    size: AppDimensions.iconSmall + 2,
                    color: isFocused ? widget.lapis : widget.inkMuted,
                  ),
                ),
              ),
            Expanded(child: field),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: AppDimensions.animationFast,
      curve: Curves.easeOutCubic,
      height: kContactSheetFieldHeight,
      decoration: BoxDecoration(
        color: widget.fill,
        borderRadius: BorderRadius.circular(kContactSheetFieldRadius),
        border: isFocused
            ? Border.all(color: widget.lapis, width: 1.5)
            : Border.all(color: widget.borderSubtle, width: 0.5),
      ),
      child: Row(
        children: [
          if (widget.leading != null)
            SizedBox(
              width: kContactSheetFieldHeight,
              height: kContactSheetFieldHeight,
              child: Center(child: widget.leading),
            )
          else if (widget.prefixIcon != null)
            SizedBox(
              width: kContactSheetFieldHeight,
              height: kContactSheetFieldHeight,
              child: Center(
                child: Icon(
                  widget.prefixIcon,
                  size: AppDimensions.iconSmall + 2,
                  color: isFocused ? widget.lapis : widget.inkMuted,
                ),
              ),
            ),
          Expanded(child: field),
        ],
      ),
    );
  }
}

/// Typography-only section label for contact sheet forms.
class ContactSheetSectionLabel extends StatelessWidget {
  const ContactSheetSectionLabel({
    required this.label,
    required this.inkMuted,
    super.key,
  });

  final String label;
  final Color inkMuted;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(
        color: inkMuted,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}
