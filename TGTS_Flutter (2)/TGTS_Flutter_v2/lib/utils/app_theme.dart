import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// App theme configuration matching the reference CSS design
class AppTheme {
  // Border radius based on CSS --radius: 0.625rem = 10px
  static const double radiusBase = 10.0;
  static const double radiusSm = 6.0; // radiusBase - 4px
  static const double radiusMd = 8.0; // radiusBase - 2px
  static const double radiusLg = 10.0; // radiusBase
  static const double radiusXl = 14.0; // radiusBase + 4px
  
  // Spacing system (CSS --spacing: 0.25rem = 4px base)
  static const double spacingBase = 4.0;
  
  // Typography sizes from CSS
  static const double fontSizeXs = 12.0; // 0.75rem
  static const double fontSizeSm = 14.0; // 0.875rem
  static const double fontSizeBase = 16.0; // 1rem
  static const double fontSizeLg = 18.0; // 1.125rem
  static const double fontSizeXl = 20.0; // 1.25rem
  static const double fontSize2Xl = 24.0; // 1.5rem
  static const double fontSize3Xl = 30.0; // 1.875rem
  
  // Font weights
  static const FontWeight fontWeightNormal = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;
  
  /// Light theme matching the reference CSS
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Color scheme based on Indian flag colors
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryLight,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryLight,
        tertiary: AppColors.accent,
        tertiaryContainer: AppColors.accentLight,
        surface: AppColors.background,
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSecondary: AppColors.textOnSecondary,
        onTertiary: AppColors.textOnAccent,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
        outline: AppColors.border,
        shadow: AppColors.shadowLight,
      ),
      
      // Primary color
      primaryColor: AppColors.primary,
      
      // Scaffold background
      scaffoldBackgroundColor: AppColors.backgroundGrey,
      
      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textOnPrimary),
        actionsIconTheme: IconThemeData(color: AppColors.textOnPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textOnPrimary,
          fontSize: fontSizeXl,
          fontWeight: fontWeightSemiBold,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      
      // Card theme
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 2,
        shadowColor: AppColors.shadowLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: spacingBase * 2,
          vertical: spacingBase,
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingBase * 4,
          vertical: spacingBase * 3,
        ),
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: fontSizeBase,
          fontWeight: fontWeightNormal,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: fontSizeBase,
          fontWeight: fontWeightMedium,
        ),
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 2,
          shadowColor: AppColors.shadowLight,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingBase * 6,
            vertical: spacingBase * 3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: fontSizeBase,
            fontWeight: fontWeightMedium,
          ),
        ),
      ),
      
      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingBase * 6,
            vertical: spacingBase * 3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: fontSizeBase,
            fontWeight: fontWeightMedium,
          ),
        ),
      ),
      
      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingBase * 4,
            vertical: spacingBase * 2,
          ),
          textStyle: const TextStyle(
            fontSize: fontSizeBase,
            fontWeight: fontWeightMedium,
          ),
        ),
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 24,
      ),
      
      // Divider theme
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: spacingBase * 4,
      ),
      
      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.muted,
        deleteIconColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: fontSizeSm,
          fontWeight: fontWeightMedium,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingBase * 3,
          vertical: spacingBase * 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      
      // Floating action button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
      
      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: TextStyle(
          fontSize: fontSizeXs,
          fontWeight: fontWeightMedium,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: fontSizeXs,
          fontWeight: fontWeightNormal,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBackground,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: fontSizeXl,
          fontWeight: fontWeightSemiBold,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: fontSizeBase,
          fontWeight: fontWeightNormal,
        ),
      ),
      
      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        circularTrackColor: AppColors.muted,
      ),
      
      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          color: AppColors.textOnPrimary,
          fontSize: fontSizeBase,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: fontSize3Xl,
          fontWeight: fontWeightBold,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontSize: fontSize2Xl,
          fontWeight: fontWeightBold,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          fontSize: fontSizeXl,
          fontWeight: fontWeightSemiBold,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        headlineLarge: TextStyle(
          fontSize: fontSize2Xl,
          fontWeight: fontWeightMedium,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        headlineMedium: TextStyle(
          fontSize: fontSizeXl,
          fontWeight: fontWeightMedium,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        headlineSmall: TextStyle(
          fontSize: fontSizeLg,
          fontWeight: fontWeightMedium,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        titleLarge: TextStyle(
          fontSize: fontSizeXl,
          fontWeight: fontWeightMedium,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        titleMedium: TextStyle(
          fontSize: fontSizeLg,
          fontWeight: fontWeightMedium,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        titleSmall: TextStyle(
          fontSize: fontSizeBase,
          fontWeight: fontWeightMedium,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        bodyLarge: TextStyle(
          fontSize: fontSizeBase,
          fontWeight: fontWeightNormal,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: fontSizeBase,
          fontWeight: fontWeightNormal,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: fontSizeSm,
          fontWeight: fontWeightNormal,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: fontSizeBase,
          fontWeight: fontWeightMedium,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        labelMedium: TextStyle(
          fontSize: fontSizeSm,
          fontWeight: fontWeightMedium,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        labelSmall: TextStyle(
          fontSize: fontSizeXs,
          fontWeight: fontWeightMedium,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
  
  /// Dark theme (optional, for future use)
  static ThemeData get darkTheme {
    return lightTheme.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      // Add dark theme customizations here if needed
    );
  }
}

