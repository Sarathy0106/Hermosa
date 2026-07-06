import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hermosa design tokens — deep near-black surfaces with a violet→teal accent.
class AppColors {
  static const bg = Color(0xFF07070C);
  static const surface = Color(0xFF12121C);
  static const surfaceHigh = Color(0xFF1B1B29);
  static const primary = Color(0xFF9B7BFF);
  static const accent = Color(0xFF5EEAD4);
  static const textPrimary = Color(0xFFF4F2FF);
  static const textSecondary = Color(0xFF8E8CA3);
  static const danger = Color(0xFFFF6B81);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9B7BFF), Color(0xFF5EEAD4)],
  );
}

ThemeData buildHermosaTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    ),
  );

  final body = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  // Space Grotesk for display/headline text, Inter for everything else.
  final text = body.copyWith(
    displayLarge: GoogleFonts.spaceGrotesk(textStyle: body.displayLarge),
    displayMedium: GoogleFonts.spaceGrotesk(textStyle: body.displayMedium),
    displaySmall: GoogleFonts.spaceGrotesk(textStyle: body.displaySmall),
    headlineLarge: GoogleFonts.spaceGrotesk(
        textStyle: body.headlineLarge, fontWeight: FontWeight.w700),
    headlineMedium: GoogleFonts.spaceGrotesk(
        textStyle: body.headlineMedium, fontWeight: FontWeight.w700),
    headlineSmall: GoogleFonts.spaceGrotesk(
        textStyle: body.headlineSmall, fontWeight: FontWeight.w700),
    titleLarge: GoogleFonts.spaceGrotesk(
        textStyle: body.titleLarge, fontWeight: FontWeight.w600),
    titleMedium: GoogleFonts.spaceGrotesk(
        textStyle: body.titleMedium, fontWeight: FontWeight.w600),
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
      backgroundColor: const Color(0xEE0B0B12),
      indicatorColor: AppColors.primary.withValues(alpha: .18),
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textSecondary,
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: Colors.white.withValues(alpha: .12),
      thumbColor: Colors.white,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: GoogleFonts.inter(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface.withValues(alpha: .62),
      hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
  );
}
