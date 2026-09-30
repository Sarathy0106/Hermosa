import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Material 3 / Android 13+ Expressive Squiggly Wave Seek Bar.
///
/// Draws a smooth, continuous sinusoidal wave on the played portion of the track,
/// with an animated flowing phase while [isPlaying] is true, a rounded thumb knob,
/// and a clean straight unplayed track line.
class M3WavySlider extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool isPlaying;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final double height;
  final double waveAmplitude;
  final double waveLength;
  final double trackThickness;
  final double thumbRadius;

  const M3WavySlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.isPlaying = false,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.height = 36.0,
    this.waveAmplitude = 4.5,
    this.waveLength = 26.0,
    this.trackThickness = 3.5,
    this.thumbRadius = 7.0,
  });

  @override
  State<M3WavySlider> createState() => _M3WavySliderState();
}

class _M3WavySliderState extends State<M3WavySlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  double? _dragValue;
  bool _isDragging = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.isPlaying) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(M3WavySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_animController.isAnimating) _animController.repeat();
      } else {
        _animController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  double get _effectiveValue {
    if (_dragValue != null) return _dragValue!.clamp(0.0, 1.0);
    return widget.value.clamp(0.0, 1.0);
  }

  void _handleSeek(double dx, double width) {
    final v = (dx / width).clamp(0.0, 1.0);
    setState(() => _dragValue = v);
    widget.onChanged(v);
  }

  void _handleCommit() {
    final v = _dragValue;
    if (v != null && widget.onChangeEnd != null) {
      widget.onChangeEnd!(v);
    }
    setState(() {
      _dragValue = null;
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.activeColor ?? theme.colorScheme.primary;
    final inactive = widget.inactiveColor ??
        Colors.white.withValues(alpha: 0.18);
    final thumb = widget.thumbColor ?? active;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              setState(() => _isDragging = true);
              _handleSeek(details.localPosition.dx, width);
            },
            onTapUp: (_) => _handleCommit(),
            onTapCancel: () {
              setState(() {
                _dragValue = null;
                _isDragging = false;
              });
            },
            onHorizontalDragStart: (details) {
              setState(() => _isDragging = true);
              _handleSeek(details.localPosition.dx, width);
            },
            onHorizontalDragUpdate: (details) {
              _handleSeek(details.localPosition.dx, width);
            },
            onHorizontalDragEnd: (_) => _handleCommit(),
            onHorizontalDragCancel: () {
              setState(() {
                _dragValue = null;
                _isDragging = false;
              });
            },
            child: SizedBox(
              width: width,
              height: widget.height,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(width, widget.height),
                    painter: _M3WavySliderPainter(
                      value: _effectiveValue,
                      phase: _animController.value * 2 * math.pi,
                      activeColor: active,
                      inactiveColor: inactive,
                      thumbColor: thumb,
                      waveAmplitude: widget.waveAmplitude,
                      waveLength: widget.waveLength,
                      trackThickness: widget.trackThickness,
                      thumbRadius: _isDragging || _isHovered
                          ? widget.thumbRadius + 2.0
                          : widget.thumbRadius,
                      isDragging: _isDragging,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _M3WavySliderPainter extends CustomPainter {
  final double value;
  final double phase;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;
  final double waveAmplitude;
  final double waveLength;
  final double trackThickness;
  final double thumbRadius;
  final bool isDragging;

  _M3WavySliderPainter({
    required this.value,
    required this.phase,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
    required this.waveAmplitude,
    required this.waveLength,
    required this.trackThickness,
    required this.thumbRadius,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerY = h / 2;

    if (w <= 0) return;

    final playedWidth = (w * value).clamp(0.0, w);

    // 1. Draw Inactive / Unplayed Track (Straight line from thumb to end)
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = trackThickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final startInactiveX = (playedWidth + thumbRadius * 0.5).clamp(0.0, w);
    if (startInactiveX < w) {
      canvas.drawLine(
        Offset(startInactiveX, centerY),
        Offset(w - trackThickness / 2, centerY),
        inactivePaint,
      );
    }

    // 2. Draw Played Track (Smooth Squiggly Sine Wave)
    if (playedWidth > 0.5) {
      final activePaint = Paint()
        ..color = activeColor
        ..strokeWidth = trackThickness
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final wavePath = Path();
      wavePath.moveTo(0, centerY);

      // If played width is very short (< 8px), draw a straight line
      if (playedWidth < 8.0) {
        wavePath.lineTo(playedWidth, centerY);
      } else {
        const step = 1.5;
        const rampZone = 14.0; // Distance over which amplitude ramps up and down smoothly

        for (double x = 0; x <= playedWidth; x += step) {
          // Smooth damping at beginning and before the thumb so it meets the center cleanly
          final rampIn = (x / rampZone).clamp(0.0, 1.0);
          final rampOut = ((playedWidth - x) / rampZone).clamp(0.0, 1.0);
          final damping = math.sin(rampIn * math.pi / 2) * math.sin(rampOut * math.pi / 2);

          final waveY = centerY +
              (waveAmplitude * damping) *
                  math.sin((x / waveLength) * 2 * math.pi - phase);

          wavePath.lineTo(x, waveY);
        }
        wavePath.lineTo(playedWidth, centerY);
      }

      canvas.drawPath(wavePath, activePaint);
    }

    // 3. Draw Thumb
    final thumbCenter = Offset(playedWidth.clamp(thumbRadius, w - thumbRadius), centerY);

    // Subtle drop shadow / glow behind thumb
    if (isDragging) {
      final glowPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(thumbCenter, thumbRadius + 4, glowPaint);
    }

    final thumbPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(thumbCenter, thumbRadius, thumbPaint);
  }

  @override
  bool shouldRepaint(_M3WavySliderPainter old) {
    return old.value != value ||
        old.phase != phase ||
        old.activeColor != activeColor ||
        old.inactiveColor != inactiveColor ||
        old.thumbColor != thumbColor ||
        old.thumbRadius != thumbRadius ||
        old.isDragging != isDragging;
  }
}

/// Backward compatibility alias if needed
typedef WaveformSeekBar = M3WavySlider;
