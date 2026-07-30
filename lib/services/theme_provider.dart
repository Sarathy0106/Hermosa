import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider extends ChangeNotifier {
  static const _boxName = 'theme_prefs';
  static const _key = 'settings';

  late final Box _box;

  // User-customizable settings
  double _primaryHue = 262.0; // default violet
  double _primarySaturation = 0.72;
  double _primaryLightness = 0.58;
  int _surfacePreset = 1; // 0=deep, 1=default, 2=elevated, 3=high-contrast
  double _fontScale = 1.0;
  double _densityScale = 1.0; // 0.85=compact, 1.0=comfy, 1.15=spacious
  bool _dynamicColor = false; // Material You
  Color? _dynamicSeed;

  // Computed colors (cached)
  late Color _primary;
  late Color _accent;
  late Color _bg;
  late Color _surface;
  late Color _surfaceHigh;
  late Color _textPrimary;
  late Color _textSecondary;
  late Color _danger;
  late LinearGradient _heroGradient;

  ThemeProvider();

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _load();
    _recomputeColors();
  }

  void _load() {
    final raw = _box.get(_key);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      _primaryHue = (map['primaryHue'] as num?)?.toDouble() ?? _primaryHue;
      _primarySaturation = (map['primarySaturation'] as num?)?.toDouble() ?? _primarySaturation;
      _primaryLightness = (map['primaryLightness'] as num?)?.toDouble() ?? _primaryLightness;
      _surfacePreset = (map['surfacePreset'] as int?) ?? _surfacePreset;
      _fontScale = (map['fontScale'] as num?)?.toDouble() ?? _fontScale;
      _densityScale = (map['densityScale'] as num?)?.toDouble() ?? _densityScale;
      _dynamicColor = (map['dynamicColor'] as bool?) ?? _dynamicColor;
      if (map['dynamicSeed'] != null) {
        _dynamicSeed = Color((map['dynamicSeed'] as int));
      }
    } catch (_) {
      // ignore corrupt prefs
    }
  }

  Future<void> _save() async {
    await _box.put(_key, jsonEncode({
      'primaryHue': _primaryHue,
      'primarySaturation': _primarySaturation,
      'primaryLightness': _primaryLightness,
      'surfacePreset': _surfacePreset,
      'fontScale': _fontScale,
      'densityScale': _densityScale,
      'dynamicColor': _dynamicColor,
      'dynamicSeed': _dynamicSeed?.toARGB32(),
    }));
  }

  void _recomputeColors() {
    // Primary from HSL
    _primary = HSLColor.fromAHSL(1.0, _primaryHue, _primarySaturation, _primaryLightness).toColor();

    // Accent: complementary hue (180° shift), same saturation/lightness
    final accentHue = (_primaryHue + 180) % 360;
    _accent = HSLColor.fromAHSL(1.0, accentHue, _primarySaturation, _primaryLightness).toColor();

    // Surface presets
    const presets = [
      // 0: Deep (darker)
      {'bg': 0xFF030305, 'surface': 0xFF0A0A10, 'surfaceHigh': 0xFF11111A},
      // 1: Default
      {'bg': 0xFF07070C, 'surface': 0xFF12121C, 'surfaceHigh': 0xFF1B1B29},
      // 2: Elevated (lighter)
      {'bg': 0xFF0C0C14, 'surface': 0xFF181822, 'surfaceHigh': 0xFF222230},
      // 3: High contrast
      {'bg': 0xFF000000, 'surface': 0xFF1A1A1A, 'surfaceHigh': 0xFF2A2A2A},
    ];
    final p = presets[_surfacePreset.clamp(0, presets.length - 1)];
    _bg = Color(p['bg']!);
    _surface = Color(p['surface']!);
    _surfaceHigh = Color(p['surfaceHigh']!);

    // Text colors adapt to surface brightness
    final bgLuminance = _bg.computeLuminance();
    _textPrimary = bgLuminance > 0.5 ? Colors.black : Colors.white;
    _textSecondary = _textPrimary.withValues(alpha: 0.6);

    _danger = const Color(0xFFFF6B81);

    _heroGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_primary, _accent],
    );
  }

  // Getters
  Color get primary => _primary;
  Color get accent => _accent;
  Color get bg => _bg;
  Color get surface => _surface;
  Color get surfaceHigh => _surfaceHigh;
  Color get textPrimary => _textPrimary;
  Color get textSecondary => _textSecondary;
  Color get danger => _danger;
  LinearGradient get heroGradient => _heroGradient;

  double get primaryHue => _primaryHue;
  double get primarySaturation => _primarySaturation;
  double get primaryLightness => _primaryLightness;
  int get surfacePreset => _surfacePreset;
  double get fontScale => _fontScale;
  double get densityScale => _densityScale;
  bool get dynamicColor => _dynamicColor;
  Color? get dynamicSeed => _dynamicSeed;

  // Setters
  Future<void> setPrimaryHue(double hue) async {
    _primaryHue = hue.clamp(0, 360);
    _recomputeColors();
    notifyListeners();
    await _save();
  }

  Future<void> setPrimarySaturation(double sat) async {
    _primarySaturation = sat.clamp(0.0, 1.0);
    _recomputeColors();
    notifyListeners();
    await _save();
  }

  Future<void> setPrimaryLightness(double light) async {
    _primaryLightness = light.clamp(0.0, 1.0);
    _recomputeColors();
    notifyListeners();
    await _save();
  }

  Future<void> setPrimaryHSL({double? hue, double? saturation, double? lightness}) async {
    if (hue != null) _primaryHue = hue.clamp(0, 360);
    if (saturation != null) _primarySaturation = saturation.clamp(0.0, 1.0);
    if (lightness != null) _primaryLightness = lightness.clamp(0.0, 1.0);
    _recomputeColors();
    notifyListeners();
    await _save();
  }

  Future<void> setSurfacePreset(int preset) async {
    _surfacePreset = preset.clamp(0, 3);
    _recomputeColors();
    notifyListeners();
    await _save();
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale.clamp(0.8, 1.4);
    notifyListeners();
    await _save();
  }

  Future<void> setDensityScale(double scale) async {
    _densityScale = scale.clamp(0.75, 1.3);
    notifyListeners();
    await _save();
  }

  Future<void> setDynamicColor(bool enabled, {Color? seed}) async {
    _dynamicColor = enabled;
    _dynamicSeed = seed;
    if (enabled && seed != null) {
      // Apply Material You scheme from seed
      _applyDynamicScheme(seed);
    } else {
      _recomputeColors();
    }
    notifyListeners();
    await _save();
  }

  void _applyDynamicScheme(Color seed) {
    // Simplified: use seed as primary, derive rest
    final hsl = HSLColor.fromColor(seed);
    _primaryHue = hsl.hue;
    _primarySaturation = hsl.saturation;
    _primaryLightness = hsl.lightness;
    _recomputeColors();
  }

  // Convenience presets
  static const List<Color> presetHues = [
    Color(0xFF9B7BFF), // Violet (default)
    Color(0xFF00BFA6), // Teal
    Color(0xFFFF6B6B), // Coral
    Color(0xFFFFA500), // Amber
    Color(0xFF7C4DFF), // Deep Purple
    Color(0xFF00E676), // Green
    Color(0xFFFFD600), // Yellow
    Color(0xFFD500F9), // Magenta
  ];

  // Density presets
  static const Map<String, double> densityPresets = {
    'Compact': 0.85,
    'Comfy': 1.0,
    'Spacious': 1.15,
  };

  // Surface preset names
  static const List<String> surfacePresetNames = [
    'Deep',
    'Default',
    'Elevated',
    'High Contrast',
  ];

  @override
  void dispose() {
    _box.close();
    super.dispose();
  }

  /// Manually scale font sizes so we never hit the
  /// `TextStyle.apply` assertion (`fontSize` must be non-null when `fontSizeFactor != 1.0`).
  static TextTheme _scaleTextTheme(TextTheme theme, double factor) {
    if (factor == 1.0) return theme;
    return TextTheme(
      displayLarge: _scaleStyle(theme.displayLarge, factor),
      displayMedium: _scaleStyle(theme.displayMedium, factor),
      displaySmall: _scaleStyle(theme.displaySmall, factor),
      headlineLarge: _scaleStyle(theme.headlineLarge, factor),
      headlineMedium: _scaleStyle(theme.headlineMedium, factor),
      headlineSmall: _scaleStyle(theme.headlineSmall, factor),
      titleLarge: _scaleStyle(theme.titleLarge, factor),
      titleMedium: _scaleStyle(theme.titleMedium, factor),
      titleSmall: _scaleStyle(theme.titleSmall, factor),
      bodyLarge: _scaleStyle(theme.bodyLarge, factor),
      bodyMedium: _scaleStyle(theme.bodyMedium, factor),
      bodySmall: _scaleStyle(theme.bodySmall, factor),
      labelLarge: _scaleStyle(theme.labelLarge, factor),
      labelMedium: _scaleStyle(theme.labelMedium, factor),
      labelSmall: _scaleStyle(theme.labelSmall, factor),
    );
  }

  static TextStyle? _scaleStyle(TextStyle? style, double factor) {
    if (style == null || style.fontSize == null) return style;
    return style.copyWith(fontSize: style.fontSize! * factor);
  }

  // Build ThemeData from current settings
  ThemeData buildTheme({Color? dynamicSeedOverride}) {
    final effectivePrimary = dynamicSeedOverride ?? _primary;
    final effectiveAccent = dynamicSeedOverride != null
        ? HSLColor.fromColor(dynamicSeedOverride).withHue((HSLColor.fromColor(dynamicSeedOverride).hue + 180) % 360).toColor()
        : _accent;
    final effectiveGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [effectivePrimary, effectiveAccent],
    );

    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: _bg,
      colorScheme: ColorScheme.dark(
        primary: effectivePrimary,
        secondary: effectiveAccent,
        surface: _surface,
        onSurface: _textPrimary,
        error: _danger,
      ),
    );

    final interTheme = GoogleFonts.interTextTheme(base.textTheme);
    final scaled = _scaleTextTheme(interTheme, _fontScale);
    final body = scaled.apply(
      bodyColor: _textPrimary,
      displayColor: _textPrimary,
    );

    final text = body.copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(textStyle: body.displayLarge),
      displayMedium: GoogleFonts.spaceGrotesk(textStyle: body.displayMedium),
      displaySmall: GoogleFonts.spaceGrotesk(textStyle: body.displaySmall),
      headlineLarge: GoogleFonts.spaceGrotesk(textStyle: body.headlineLarge, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.spaceGrotesk(textStyle: body.headlineMedium, fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.spaceGrotesk(textStyle: body.headlineSmall, fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.spaceGrotesk(textStyle: body.titleLarge, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.spaceGrotesk(textStyle: body.titleMedium, fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
        iconTheme: IconThemeData(color: _textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _bg.withValues(alpha: 0.93),
        indicatorColor: effectivePrimary.withValues(alpha: 0.18),
        height: (64 * _densityScale).roundToDouble(),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontSize: (11 * _fontScale * _densityScale).roundToDouble(), fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? effectivePrimary
                : _textSecondary,
            size: 24 * _densityScale,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3 * _densityScale,
        activeTrackColor: effectivePrimary,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
        thumbColor: Colors.white,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6 * _densityScale),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14 * _densityScale),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceHigh,
        contentTextStyle: GoogleFonts.inter(color: _textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * _densityScale)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24 * _densityScale)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface.withValues(alpha: 0.62),
        hintStyle: GoogleFonts.inter(color: _textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16 * _densityScale),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 18 * _densityScale,
          vertical: 14 * _densityScale,
        ),
      ),
      // Expose custom colors via extensions
      extensions: <ThemeExtension<dynamic>>[
        HermosaColors(
          primary: effectivePrimary,
          accent: effectiveAccent,
          bg: _bg,
          surface: _surface,
          surfaceHigh: _surfaceHigh,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
          danger: _danger,
          heroGradient: effectiveGradient,
          densityScale: _densityScale,
          fontScale: _fontScale,
        ),
      ],
    );
  }
}

/// ThemeExtension for easy access to Hermosa colors in widgets
class HermosaColors extends ThemeExtension<HermosaColors> {
  final Color primary;
  final Color accent;
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color textPrimary;
  final Color textSecondary;
  final Color danger;
  final LinearGradient heroGradient;
  final double densityScale;
  final double fontScale;

  const HermosaColors({
    required this.primary,
    required this.accent,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.textPrimary,
    required this.textSecondary,
    required this.danger,
    required this.heroGradient,
    required this.densityScale,
    required this.fontScale,
  });

  @override
  HermosaColors copyWith({
    Color? primary,
    Color? accent,
    Color? bg,
    Color? surface,
    Color? surfaceHigh,
    Color? textPrimary,
    Color? textSecondary,
    Color? danger,
    LinearGradient? heroGradient,
    double? densityScale,
    double? fontScale,
  }) {
    return HermosaColors(
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      danger: danger ?? this.danger,
      heroGradient: heroGradient ?? this.heroGradient,
      densityScale: densityScale ?? this.densityScale,
      fontScale: fontScale ?? this.fontScale,
    );
  }

  @override
  HermosaColors lerp(ThemeExtension<HermosaColors>? other, double t) {
    if (other is! HermosaColors) return this;
    return HermosaColors(
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
      densityScale: densityScale + (other.densityScale - densityScale) * t,
      fontScale: fontScale + (other.fontScale - fontScale) * t,
    );
  }
}

extension HermosaTheme on BuildContext {
  HermosaColors get hermosa => Theme.of(this).extension<HermosaColors>()!;
}