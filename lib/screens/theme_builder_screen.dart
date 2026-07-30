import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/theme_provider.dart';
import '../widgets/glass.dart';

class ThemeBuilderScreen extends StatelessWidget {
  const ThemeBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final h = context.hermosa;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Builder'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 160),
        children: [
          // Live preview card
          _PreviewCard(theme: theme),
          const SizedBox(height: 24),

          // Primary color section
          _SectionHeader(title: 'Accent Color'),
          _ColorWheelPicker(theme: theme),
          const SizedBox(height: 16),
          _PresetColors(theme: theme),
          const SizedBox(height: 24),

          // Surface preset
          _SectionHeader(title: 'Surface Depth'),
          _SurfacePresetPicker(theme: theme),
          const SizedBox(height: 24),

          // Typography
          _SectionHeader(title: 'Typography'),
          _FontScaleSlider(theme: theme),
          const SizedBox(height: 24),

          // Density
          _SectionHeader(title: 'Layout Density'),
          _DensityPicker(theme: theme),
          const SizedBox(height: 24),

          // Dynamic color (Material You)
          _SectionHeader(title: 'Dynamic Color (Material You)'),
          _DynamicColorToggle(theme: theme),
          const SizedBox(height: 24),

          // Reset button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              onPressed: () => _showResetDialog(context, theme),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Reset to defaults'),
              style: OutlinedButton.styleFrom(
                foregroundColor: h.textSecondary,
                side: BorderSide(color: h.textSecondary.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.hermosa.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset theme?'),
        content: const Text('This will restore all theme settings to defaults.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.hermosa.danger),
            onPressed: () {
              theme.setPrimaryHSL(hue: 262, saturation: 0.72, lightness: 0.58);
              theme.setSurfacePreset(1);
              theme.setFontScale(1.0);
              theme.setDensityScale(1.0);
              theme.setDynamicColor(false);
              Navigator.pop(ctx);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final ThemeProvider theme;
  const _PreviewCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final h = context.hermosa;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Glass(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Preview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                // Primary button
                FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: h.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Primary'),
                ),
                const SizedBox(width: 12),
                // Outlined button
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: h.accent,
                    side: BorderSide(color: h.accent, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Accent'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Slider preview
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: h.primary,
                inactiveTrackColor: h.surfaceHigh,
                thumbColor: h.primary,
                trackHeight: 4,
              ),
              child: Slider(value: 0.65, onChanged: (_) {}),
            ),
            const SizedBox(height: 12),
            // Text samples
            Text('Headline Large', style: Theme.of(context).textTheme.headlineLarge),
            Text('Title Medium', style: Theme.of(context).textTheme.titleMedium),
            Text('Body Medium', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: h.textSecondary)),
            const SizedBox(height: 12),
            // Card preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: h.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: h.heroGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sample Card', style: Theme.of(context).textTheme.titleMedium),
                        Text('Surface elevation preview', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: h.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _ColorWheelPicker extends StatelessWidget {
  final ThemeProvider theme;
  const _ColorWheelPicker({required this.theme});

  @override
  Widget build(BuildContext context) {
    final h = context.hermosa;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Glass(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hue', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: h.textSecondary)),
            const SizedBox(height: 12),
            _HueSlider(theme: theme),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saturation', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: h.textSecondary)),
                      const SizedBox(height: 8),
                      Slider(
                        value: theme.primarySaturation,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        activeColor: h.primary,
                        onChanged: (v) => theme.setPrimarySaturation(v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lightness', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: h.textSecondary)),
                      const SizedBox(height: 8),
                      Slider(
                        value: theme.primaryLightness,
                        min: 0.1,
                        max: 0.9,
                        divisions: 16,
                        activeColor: h.primary,
                        onChanged: (v) => theme.setPrimaryLightness(v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HueSlider extends StatelessWidget {
  final ThemeProvider theme;
  const _HueSlider({required this.theme});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            final dx = details.localPosition.dx.clamp(0, constraints.maxWidth);
            final hue = (dx / constraints.maxWidth) * 360;
            theme.setPrimaryHue(hue);
          },
          onTapDown: (details) {
            final dx = details.localPosition.dx.clamp(0, constraints.maxWidth);
            final hue = (dx / constraints.maxWidth) * 360;
            theme.setPrimaryHue(hue);
          },
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF0000), // 0° Red
                  Color(0xFFFF7F00), // 30° Orange
                  Color(0xFFFFFF00), // 60° Yellow
                  Color(0xFF7FFF00), // 90° Chartreuse
                  Color(0xFF00FF00), // 120° Green
                  Color(0xFF00FF7F), // 150° Spring Green
                  Color(0xFF00FFFF), // 180° Cyan
                  Color(0xFF007FFF), // 210° Azure
                  Color(0xFF0000FF), // 240° Blue
                  Color(0xFF7F00FF), // 270° Violet
                  Color(0xFFFF00FF), // 300° Magenta
                  Color(0xFFFF007F), // 330° Rose
                  Color(0xFFFF0000), // 360° Red
                ],
              ),
            ),
            child: Stack(
              children: [
                // Indicator
                Positioned(
                  left: (theme.primaryHue / 360) * constraints.maxWidth - 10,
                  top: -4,
                  child: Container(
                    width: 20,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PresetColors extends StatelessWidget {
  final ThemeProvider theme;
  const _PresetColors({required this.theme});

  @override
  Widget build(BuildContext context) {
    final h = context.hermosa;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Glass(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Presets', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: h.textSecondary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ThemeProvider.presetHues.map((color) {
                final isSelected = _isColorMatch(color, theme.primary);
                return GestureDetector(
                  onTap: () {
                    final hsl = HSLColor.fromColor(color);
                    theme.setPrimaryHSL(hue: hsl.hue, saturation: hsl.saturation, lightness: hsl.lightness);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  bool _isColorMatch(Color a, Color b) {
    final hslA = HSLColor.fromColor(a);
    final hslB = HSLColor.fromColor(b);
    return (hslA.hue - hslB.hue).abs() < 5 &&
        (hslA.saturation - hslB.saturation).abs() < 0.05 &&
        (hslA.lightness - hslB.lightness).abs() < 0.05;
  }
}

class _SurfacePresetPicker extends StatelessWidget {
  final ThemeProvider theme;
  const _SurfacePresetPicker({required this.theme});

  @override
  Widget build(BuildContext context) {
    final h = context.hermosa;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Glass(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(ThemeProvider.surfacePresetNames.length, (i) {
            final name = ThemeProvider.surfacePresetNames[i];
            final isSelected = theme.surfacePreset == i;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _presetColor(i),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? h.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
              trailing: isSelected ? Icon(Icons.check_circle_rounded, color: h.primary) : null,
              onTap: () => theme.setSurfacePreset(i),
            );
          }),
        ),
      ),
    );
  }

  Color _presetColor(int i) {
    const colors = [
      Color(0xFF030305),
      Color(0xFF07070C),
      Color(0xFF0C0C14),
      Color(0xFF000000),
    ];
    return colors[i];
  }
}

class _FontScaleSlider extends StatelessWidget {
  final ThemeProvider theme;
  const _FontScaleSlider({required this.theme});

  @override
  Widget build(BuildContext context) {
    final h = context.hermosa;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Glass(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Font Size', style: Theme.of(context).textTheme.titleMedium),
                Text('${(theme.fontScale * 100).round()}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: h.primary)),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: theme.fontScale,
              min: 0.8,
              max: 1.4,
              divisions: 12,
              activeColor: h.primary,
              onChanged: (v) => theme.setFontScale(v),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Small', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: h.textSecondary)),
                Text('Large', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: h.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DensityPicker extends StatelessWidget {
  final ThemeProvider theme;
  const _DensityPicker({required this.theme});

  @override
  Widget build(BuildContext context) {
    final h = context.hermosa;
    final presets = ThemeProvider.densityPresets.entries.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Glass(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: presets.map((entry) {
            final name = entry.key;
            final value = entry.value;
            final isSelected = (theme.densityScale - value).abs() < 0.01;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              title: Text(name),
              subtitle: Text('${(value * 100).round()}% density', style: TextStyle(color: h.textSecondary, fontSize: 12)),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: h.primary)
                  : Icon(Icons.radio_button_unchecked_rounded, color: h.textSecondary),
              onTap: () => theme.setDensityScale(value),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DynamicColorToggle extends StatelessWidget {
  final ThemeProvider theme;
  const _DynamicColorToggle({required this.theme});

  @override
  Widget build(BuildContext context) {
    final h = context.hermosa;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Glass(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Enable Dynamic Color'),
              subtitle: Text(
                'Extract accent from album art (Material You)',
                style: TextStyle(color: h.textSecondary, fontSize: 12),
              ),
              value: theme.dynamicColor,
              activeThumbColor: h.primary,
              onChanged: (v) => theme.setDynamicColor(v),
            ),
            if (theme.dynamicColor) ...[
              const Divider(height: 20),
              ListTile(
                leading: Icon(Icons.palette_rounded, color: h.primary),
                title: const Text('Pick seed color'),
                subtitle: Text(
                  'Tap to choose a color for dynamic theming',
                  style: TextStyle(color: h.textSecondary, fontSize: 12),
                ),
                onTap: () => _showSeedPicker(context, theme),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSeedPicker(BuildContext context, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Glass(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        tint: const Color(0xD912121C),
        blur: 28,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pick Seed Color', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: ThemeProvider.presetHues.map((color) {
                return GestureDetector(
                  onTap: () {
                    theme.setDynamicColor(true, seed: color);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}