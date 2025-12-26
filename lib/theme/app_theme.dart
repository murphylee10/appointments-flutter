import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system spacing constants
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Design system border radius constants
class AppRadius {
  static const double sm = 6.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
}

/// Design system colors (semantic and status colors)
class AppColors {
  // Status colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Neutrals
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFFC4C8CC);
  static const Color border = Color(0xFFE1E4E8);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color backgroundCard = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF9FAFB);
}

/// Main theme builder
class AppTheme {
  /// Build the light theme for the application
  static ThemeData buildLightTheme() {
    // Create color scheme from seed
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4169E1), // Professional blue
      brightness: Brightness.light,
    ).copyWith(
      surface: AppColors.backgroundLight,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      error: AppColors.errorRed,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,

      // Typography
      textTheme: GoogleFonts.interTextTheme().copyWith(
        // Display styles
        displayLarge: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        displayMedium: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.25,
        ),
        displaySmall: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),

        // Headline styles
        headlineMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),

        // Title styles
        titleLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),

        // Body styles
        bodyLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),

        // Label styles
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),

      // AppBar theme
      appBarTheme: AppBarTheme(
        elevation: 1,
        backgroundColor: AppColors.backgroundCard,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.05),
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.25,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
          size: 20,
        ),
      ),

      // Card theme
      cardTheme: CardTheme(
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.08),
        surfaceTintColor: Colors.transparent,
        color: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 2),
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        hintStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: const BorderSide(color: AppColors.borderLight),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Icon button theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: 20,
          padding: const EdgeInsets.all(AppSpacing.sm),
          minimumSize: const Size(32, 32),
        ),
      ),

      // DataTable theme
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AppColors.surfaceVariant),
        headingTextStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
        dataTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        dataRowMinHeight: 52,
        dataRowMaxHeight: 52,
        horizontalMargin: AppSpacing.lg,
        columnSpacing: AppSpacing.xl,
        dividerThickness: 1,
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),

      // Dialog theme
      dialogTheme: DialogTheme(
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.15),
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
