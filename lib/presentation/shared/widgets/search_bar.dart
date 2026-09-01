import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Premium search field with debounce and RTL-aware clear affordance.
class SearchBar extends StatefulWidget {
  const SearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.initialText = '',
    this.debounceDuration = const Duration(milliseconds: 300),
    this.onChanged,
    this.onDebouncedChanged,
    this.onSubmitted,
    this.onCleared,
    this.autofocus = false,
    this.enabled = true,
    this.leadingIcon = Icons.search_rounded,
    this.textInputAction = TextInputAction.search,
    this.keyboardType = TextInputType.text,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String initialText;
  final Duration debounceDuration;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onDebouncedChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onCleared;
  final bool autofocus;
  final bool enabled;
  final IconData leadingIcon;
  final TextInputAction textInputAction;
  final TextInputType keyboardType;

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  bool _hasText = false;
  bool _isFocused = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller, initialText: widget.initialText);
    _attachFocusNode(widget.focusNode);
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
    _syncState();
  }

  @override
  void didUpdateWidget(covariant SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      final previousController = _controller
        ..removeListener(_handleTextChanged);
      if (_ownsController) {
        previousController.dispose();
      }

      _attachController(
        widget.controller,
        initialText: previousController.text,
      );
      _controller.addListener(_handleTextChanged);
      _syncState();
    }

    if (oldWidget.focusNode != widget.focusNode) {
      final previousFocusNode = _focusNode..removeListener(_handleFocusChanged);
      if (_ownsFocusNode) {
        previousFocusNode.dispose();
      }

      _attachFocusNode(widget.focusNode);
      _focusNode.addListener(_handleFocusChanged);
      _syncState();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_handleTextChanged);
    _focusNode.removeListener(_handleFocusChanged);

    if (_ownsController) {
      _controller.dispose();
    }

    if (_ownsFocusNode) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  void _attachController(
    TextEditingController? controller, {
    required String initialText,
  }) {
    if (controller != null) {
      _controller = controller;
      _ownsController = false;
      return;
    }

    _controller = TextEditingController(text: initialText);
    _ownsController = true;
  }

  void _attachFocusNode(FocusNode? focusNode) {
    if (focusNode != null) {
      _focusNode = focusNode;
      _ownsFocusNode = false;
      return;
    }

    _focusNode = FocusNode();
    _ownsFocusNode = true;
  }

  void _handleTextChanged() {
    _syncState();
    widget.onChanged?.call(_controller.text);

    _debounceTimer?.cancel();
    if (widget.onDebouncedChanged == null) {
      return;
    }

    _debounceTimer = Timer(widget.debounceDuration, () {
      if (mounted) {
        widget.onDebouncedChanged?.call(_controller.text);
      }
    });
  }

  void _handleFocusChanged() {
    _syncState();
  }

  void _syncState() {
    if (!mounted) {
      return;
    }

    setState(() {
      _hasText = _controller.text.isNotEmpty;
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _clearText() {
    _debounceTimer?.cancel();
    _controller.clear();
    widget.onCleared?.call();
    widget.onDebouncedChanged?.call('');
    widget.onChanged?.call('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.surface3
        : AppColors.surface2Light;
    final borderColor = _isFocused
        ? (isDark ? AppColors.lapis400 : AppColors.lapis500)
        : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight);
    final onSurfaceColor = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final mutedColor = isDark
        ? AppColors.inkMuted
        : AppColors.inkMutedLight;
    final hintColor = isDark
        ? AppColors.inkMuted
        : AppColors.inkMutedLight;

    return AnimatedContainer(
      duration: AppDimensions.animationMedium,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: borderColor,
          width: AppDimensions.dividerThickness,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textAlignVertical: TextAlignVertical.center,
        style: AppTextStyles.bodyMedium.copyWith(
          color: onSurfaceColor,
        ),
        cursorColor: isDark ? AppColors.lapis400 : AppColors.lapis500,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: widget.hintText ?? l10n.searchHint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: hintColor,
          ),
          prefixIcon: Icon(
            widget.leadingIcon,
            color: mutedColor,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: AppDimensions.comfortableTapTarget,
            minHeight: AppDimensions.comfortableTapTarget,
          ),
          suffixIcon: AnimatedSwitcher(
            duration: AppDimensions.animationFast,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child: _hasText
                ? Semantics(
                    key: const ValueKey('search_clear_button'),
                    button: true,
                    label: MaterialLocalizations.of(context).clearButtonTooltip,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.enabled ? _clearText : null,
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: Icon(
                          Icons.close_rounded,
                          color: mutedColor,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(
                    key: ValueKey('search_clear_placeholder'),
                  ),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: AppDimensions.comfortableTapTarget,
            minHeight: AppDimensions.comfortableTapTarget,
          ),
          contentPadding: const EdgeInsetsDirectional.fromSTEB(
            AppDimensions.spacingSm,
            AppDimensions.spacingMd,
            AppDimensions.spacingSm,
            AppDimensions.spacingMd,
          ),
        ),
      ),
    );
  }
}
