import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hermosa Material 3 / Next-Gen Design Tokens
class AppColors {
  // Deep obsidian & glass surfaces
  static const bg = Color(0xFF0A090F);
  static const surface = Color(0xFF13111A);
  static const surfaceHigh = Color(0xFF1D1A27);
  static const surfaceContainerHighest = Color(0xFF2B2638);
  
  // Expressive Material 3 Accents
  static const primary = Color(0xFFD0BCFF);
  static const primaryContainer = Color(0xFF5A4880);
  static const onPrimaryContainer = Color(0xFFEADDFF);
  
  static const secondary = Color(0xFF70F3DE);
  static const secondaryContainer = Color(0xFF004F47);
  static const onSecondaryContainer = Color(0xFF8CFBE8);
  
  static const accent = Color(0xFF8FD8CC);
  static const tertiary = Color(0xFFFFB4AB);
  
  // Text & Content colors
  static const textPrimary = Color(0xFFF6F2FF);
  static const textSecondary = Color(0xFFC7C2D6);
  static const textTertiary = Color(0xFF8E88A0);
  
  static const danger = Color(0xFFFF6B81);
  static const success = Color(0xFF4ECCA3);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9B7BFF), Color(0xFF5EEAD4)],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF221E30), Color(0xFF171422)],
  );
}

ThemeData buildHermosaTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      surface: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      error: AppColors.danger,
    ),
  );

  final body = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  final text = body.copyWith(
    displayLarge: GoogleFonts.spaceGrotesk(textStyle: body.displayLarge, fontWeight: FontWeight.w700),
    displayMedium: GoogleFonts.spaceGrotesk(textStyle: body.displayMedium, fontWeight: FontWeight.w700),
    displaySmall: GoogleFonts.spaceGrotesk(textStyle: body.displaySmall, fontWeight: FontWeight.w700),
    headlineLarge: GoogleFonts.spaceGrotesk(textStyle: body.headlineLarge, fontWeight: FontWeight.w700),
    headlineMedium: GoogleFonts.spaceGrotesk(textStyle: body.headlineMedium, fontWeight: FontWeight.w700),
    headlineSmall: GoogleFonts.spaceGrotesk(textStyle: body.headlineSmall, fontWeight: FontWeight.w700),
    titleLarge: GoogleFonts.spaceGrotesk(textStyle: body.titleLarge, fontWeight: FontWeight.w600),
    titleMedium: GoogleFonts.spaceGrotesk(textStyle: body.titleMedium, fontWeight: FontWeight.w600),
    titleSmall: GoogleFonts.inter(textStyle: body.titleSmall, fontWeight: FontWeight.w600),
    bodyLarge: GoogleFonts.inter(textStyle: body.bodyLarge),
    bodyMedium: GoogleFonts.inter(textStyle: body.bodyMedium),
    bodySmall: GoogleFonts.inter(textStyle: body.bodySmall, color: AppColors.textSecondary),
    labelLarge: GoogleFonts.inter(textStyle: body.labelLarge, fontWeight: FontWeight.w600),
  );

  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.headlineSmall,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryContainer,
      elevation: 0,
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.inter(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? Colors.white : AppColors.textSecondary,
          size: 24,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceHigh,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size.square(44)),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: const WidgetStatePropertyAll(AppColors.surfaceHigh),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceContainerHighest,
      contentTextStyle: GoogleFonts.inter(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
  );
}
