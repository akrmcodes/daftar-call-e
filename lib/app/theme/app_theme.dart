import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Khazna v3 — `ThemeData` for dark (default) and light modes.
///
/// Both themes:
///   * Use Material 3 (`useMaterial3: true`).
///   * Disable surface tint overlays (`surfaceTintColor: Colors.transparent`).
///   * Disable default Material splash ripple (`NoSplash.splashFactory`) —
///     interaction feedback is provided via custom scale + haptics + lapis
///     glow as per the design system.
///   * Strip default elevation from cards, sheets, dialogs, FABs — depth is
///     produced by `AppGlows` shadows / borders / inner highlights, never by
///     Material's default `shadowColor` paint.
abstract final class AppTheme {
  static final ThemeData dark = _build(_DarkPalette());
  static final ThemeData light = _build(_LightPalette());

  static ThemeData _build(_Palette p) {
    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,

      colorScheme: ColorScheme(
        brightness: p.brightness,
        primary: p.primary,
        onPrimary: p.onPrimary,
        primaryContainer: p.primaryContainer,
        onPrimaryContainer: p.onPrimaryContainer,
        secondary: p.primary,
        onSecondary: p.onPrimary,
        secondaryContainer: p.primaryContainer,
        onSecondaryContainer: p.onPrimaryContainer,
        tertiary: p.primary,
        onTertiary: p.onPrimary,
        surface: p.surface1,
        onSurface: p.inkPrimary,
        surfaceContainerLowest: p.surface0,
        surfaceContainerLow: p.surface1,
        surfaceContainer: p.surface2,
        surfaceContainerHigh: p.surface3,
        surfaceContainerHighest: p.surface4,
        onSurfaceVariant: p.inkSecondary,
        error: p.error,
        onError: p.onError,
        errorContainer: p.errorContainer,
        onErrorContainer: p.onError,
        outline: p.borderStrong,
        outlineVariant: p.borderSubtle,
        scrim: p.scrim,
        inverseSurface: p.inkPrimary,
        onInverseSurface: p.surface0,
        inversePrimary: p.primary,
      ),

      scaffoldBackgroundColor: p.surface0,
      canvasColor: p.surface0,
      dividerColor: p.borderSubtle,
      shadowColor: Colors.transparent,

      fontFamily: AppTextStyles.arabicFontFamily,

      appBarTheme: AppBarTheme(
        backgroundColor: p.surface0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.inkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: AppDimensions.appBarHeight,
        titleTextStyle: AppTextStyles.titleLarge.copyWith(color: p.inkPrimary),
        iconTheme: IconThemeData(
          color: p.inkPrimary,
          size: AppDimensions.iconMedium,
        ),
        actionsIconTheme: IconThemeData(
          color: p.inkPrimary,
          size: AppDimensions.iconMedium,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppDimensions.minTapTarget,
            AppDimensions.minTapTarget,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface2,
        selectedItemColor: p.primary,
        unselectedItemColor: p.inkSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontFamily: AppTextStyles.arabicFontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: AppTextStyles.arabicFontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface3,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface3,
        modalBarrierColor: p.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: p.inkMuted,
        dragHandleSize: const Size(
          AppDimensions.dragHandleWidth,
          AppDimensions.dragHandleHeight,
        ),
      ),

      cardTheme: CardThemeData(
        color: p.surface2,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(color: p.borderSubtle, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimensions.pagePaddingH,
          vertical: AppDimensions.spacingSm,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.surface3,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        barrierColor: p.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        titleTextStyle: AppTextStyles.titleLarge.copyWith(color: p.inkPrimary),
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: p.inkSecondary),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.surface3,
          disabledForegroundColor: p.inkDisabled,
          minimumSize: const Size(
            double.infinity,
            AppDimensions.comfortableTapTarget,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          textStyle: AppTextStyles.labelLarge,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.inkPrimary,
          disabledForegroundColor: p.inkDisabled,
          minimumSize: const Size(
            AppDimensions.minTapTarget,
            AppDimensions.comfortableTapTarget,
          ),
          side: BorderSide(color: p.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.inkPrimary,
          disabledForegroundColor: p.inkDisabled,
          minimumSize: const Size(
            AppDimensions.minTapTarget,
            AppDimensions.minTapTarget,
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.surface3,
          disabledForegroundColor: p.inkDisabled,
          minimumSize: const Size(
            double.infinity,
            AppDimensions.comfortableTapTarget,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          textStyle: AppTextStyles.labelLarge,
          elevation: 0,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface5,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: BorderSide(color: p.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: BorderSide(color: p.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingLg,
          vertical: AppDimensions.spacingMd,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: p.inkMuted),
        labelStyle: AppTextStyles.labelSmall.copyWith(color: p.inkSecondary),
        floatingLabelStyle:
            AppTextStyles.labelSmall.copyWith(color: p.primary),
        errorStyle: AppTextStyles.bodySmall.copyWith(color: p.error),
      ),

      dividerTheme: DividerThemeData(
        color: p.borderSubtle,
        thickness: AppDimensions.dividerThickness,
        space: 0,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.surface2,
        foregroundColor: p.inkPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          side: BorderSide(color: p.primary, width: 0.5),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surface3,
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: p.inkPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(color: p.borderSubtle, width: 0.5),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        actionTextColor: p.inkPrimary,
      ),

      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge.copyWith(color: p.inkPrimary),
        displayMedium:
            AppTextStyles.displayMedium.copyWith(color: p.inkPrimary),
        displaySmall: AppTextStyles.displaySmall.copyWith(color: p.inkPrimary),
        headlineLarge:
            AppTextStyles.headlineLarge.copyWith(color: p.inkPrimary),
        headlineMedium:
            AppTextStyles.headlineMedium.copyWith(color: p.inkPrimary),
        titleLarge: AppTextStyles.titleLarge.copyWith(color: p.inkPrimary),
        titleMedium: AppTextStyles.titleMedium.copyWith(color: p.inkPrimary),
        titleSmall: AppTextStyles.titleSmall.copyWith(color: p.inkPrimary),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: p.inkPrimary),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: p.inkPrimary),
        bodySmall: AppTextStyles.bodySmall.copyWith(color: p.inkSecondary),
        labelLarge: AppTextStyles.labelLarge.copyWith(color: p.inkPrimary),
        labelMedium: AppTextStyles.labelMedium.copyWith(color: p.inkSecondary),
        labelSmall: AppTextStyles.labelSmall.copyWith(color: p.inkMuted),
      ),

      iconTheme: IconThemeData(
        color: p.inkPrimary,
        size: AppDimensions.iconMedium,
      ),

      primaryIconTheme: IconThemeData(
        color: p.onPrimary,
        size: AppDimensions.iconMedium,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.surface3,
        disabledColor: p.surface2,
        selectedColor: p.surface4,
        secondarySelectedColor: p.surface4,
        labelStyle:
            AppTextStyles.titleSmall.copyWith(color: p.inkPrimary),
        secondaryLabelStyle:
            AppTextStyles.titleSmall.copyWith(color: p.inkPrimary),
        side: BorderSide(color: p.borderSubtle, width: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
        ),
        elevation: 0,
        pressElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.listTilePaddingH,
          vertical: AppDimensions.listTilePaddingV,
        ),
        minTileHeight: AppDimensions.minTapTarget,
        titleTextStyle:
            AppTextStyles.titleMedium.copyWith(color: p.inkPrimary),
        subtitleTextStyle:
            AppTextStyles.bodySmall.copyWith(color: p.inkSecondary),
        iconColor: p.inkPrimary,
        textColor: p.inkPrimary,
        tileColor: Colors.transparent,
        selectedTileColor: p.surface4,
        selectedColor: p.primary,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return p.inkDisabled;
          if (states.contains(WidgetState.selected)) return p.inkPrimary;
          return p.inkSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return p.surface2;
          if (states.contains(WidgetState.selected)) return p.surface3;
          return p.surface5;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return p.borderSubtle;
        }),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surface5,
        circularTrackColor: p.surface5,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.surface5,
        thumbColor: p.primary,
        overlayColor: p.primary.withValues(alpha: 0.12),
        valueIndicatorColor: p.surface4,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: p.inkPrimary,
        unselectedLabelColor: p.inkSecondary,
        labelStyle: AppTextStyles.titleSmall,
        unselectedLabelStyle: AppTextStyles.titleSmall,
        indicatorColor: p.primary,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surface4,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: p.borderSubtle, width: 0.5),
        ),
        textStyle: AppTextStyles.bodySmall.copyWith(color: p.inkPrimary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingSm,
          vertical: AppDimensions.spacingXs,
        ),
      ),
    );
  }
}

/// Sealed palette resolver — encapsulates dark vs light token resolution
/// so the `_build()` factory stays mode-agnostic.
abstract class _Palette {
  Brightness get brightness;
  Color get surface0;
  Color get surface1;
  Color get surface2;
  Color get surface3;
  Color get surface4;
  Color get surface5;
  Color get surface6;
  Color get inkPrimary;
  Color get inkSecondary;
  Color get inkMuted;
  Color get inkDisabled;
  Color get borderSubtle;
  Color get borderStrong;
  Color get scrim;
  Color get primary;
  Color get onPrimary;
  Color get primaryContainer;
  Color get onPrimaryContainer;
  Color get error;
  Color get errorContainer;
  Color get onError;
}

class _DarkPalette implements _Palette {
  @override
  Brightness get brightness => Brightness.dark;
  @override
  Color get surface0 => AppColors.surface0;
  @override
  Color get surface1 => AppColors.surface1;
  @override
  Color get surface2 => AppColors.surface2;
  @override
  Color get surface3 => AppColors.surface3;
  @override
  Color get surface4 => AppColors.surface4;
  @override
  Color get surface5 => AppColors.surface5;
  @override
  Color get surface6 => AppColors.surface6;
  @override
  Color get inkPrimary => AppColors.inkPrimary;
  @override
  Color get inkSecondary => AppColors.inkSecondary;
  @override
  Color get inkMuted => AppColors.inkMuted;
  @override
  Color get inkDisabled => AppColors.inkDisabled;
  @override
  Color get borderSubtle => AppColors.borderSubtle;
  @override
  Color get borderStrong => AppColors.borderStrong;
  @override
  Color get scrim => AppColors.scrim;
  @override
  Color get primary => AppColors.lapis400;
  @override
  Color get onPrimary => const Color(0xFFFFFFFF);
  @override
  Color get primaryContainer => AppColors.lapis800;
  @override
  Color get onPrimaryContainer => AppColors.lapis50;
  @override
  Color get error => AppColors.debt;
  @override
  Color get errorContainer => AppColors.debtContainer;
  @override
  Color get onError => AppColors.onDebt;
}

class _LightPalette implements _Palette {
  @override
  Brightness get brightness => Brightness.light;
  @override
  Color get surface0 => AppColors.surface0Light;
  @override
  Color get surface1 => AppColors.surface1Light;
  @override
  Color get surface2 => AppColors.surface2Light;
  @override
  Color get surface3 => AppColors.surface3Light;
  @override
  Color get surface4 => AppColors.surface4Light;
  @override
  Color get surface5 => AppColors.surface3Light;
  @override
  Color get surface6 => AppColors.surface4Light;
  @override
  Color get inkPrimary => AppColors.inkPrimaryLight;
  @override
  Color get inkSecondary => AppColors.inkSecondaryLight;
  @override
  Color get inkMuted => AppColors.inkMutedLight;
  @override
  Color get inkDisabled => AppColors.inkDisabledLight;
  @override
  Color get borderSubtle => AppColors.borderSubtleLight;
  @override
  Color get borderStrong => AppColors.borderStrongLight;
  @override
  Color get scrim => AppColors.scrimLight;
  @override
  Color get primary => AppColors.lapis500;
  @override
  Color get onPrimary => const Color(0xFFFFFFFF);
  @override
  Color get primaryContainer => AppColors.lapis50;
  @override
  Color get onPrimaryContainer => AppColors.lapis800;
  @override
  Color get error => AppColors.debtLight;
  @override
  Color get errorContainer => AppColors.debtContainerLight;
  @override
  Color get onError => AppColors.onDebtLight;
}
