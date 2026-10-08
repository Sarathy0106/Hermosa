import 'package:flutter/material.dart';

/// Modern, sleek Material 3 seek bar with smooth track, rounded thumb,
/// hover effect, and responsive drag-seeking.
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
    this.waveAmplitude = 0.0,
    this.waveLength = 20.0,
    this.trackThickness = 4.0,
    this.thumbRadius = 6.0,
  });

  @override
  State<M3WavySlider> createState() => _M3WavySliderState();
}

class _M3WavySliderState extends State<M3WavySlider> {
  double? _dragValue;
  bool _isDragging = false;
  bool _isHovered = false;

  double get _effectiveValue {
    if (_dragValue != null) return _dragValue!.clamp(0.0, 1.0);
    return widget.value.clamp(0.0, 1.0);
  }

  void _handleSeek(double dx, double width) {
    if (width <= 0) return;
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
        Colors.white.withValues(alpha: 0.16);
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
              child: CustomPaint(
                size: Size(width, widget.height),
                painter: _ModernSliderPainter(
                  value: _effectiveValue,
                  activeColor: active,
                  inactiveColor: inactive,
                  thumbColor: thumb,
                  trackThickness: (_isDragging || _isHovered)
                      ? widget.trackThickness + 1.5
                      : widget.trackThickness,
                  thumbRadius: (_isDragging || _isHovered)
                      ? widget.thumbRadius + 2.5
                      : widget.thumbRadius,
                  isDragging: _isDragging,
                  isHovered: _isHovered,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModernSliderPainter extends CustomPainter {
  final double value;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;
  final double trackThickness;
  final double thumbRadius;
  final bool isDragging;
  final bool isHovered;

  _ModernSliderPainter({
    required this.value,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
    required this.trackThickness,
    required this.thumbRadius,
    required this.isDragging,
    required this.isHovered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerY = h / 2;

    if (w <= 0) return;

    final playedWidth = (w * value).clamp(0.0, w);

    // 1. Draw Inactive Track
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = trackThickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(trackThickness / 2, centerY),
      Offset(w - trackThickness / 2, centerY),
      inactivePaint,
    );

    // 2. Draw Active Track (Played portion)
    if (playedWidth > 0.0) {
      final activePaint = Paint()
        ..color = activeColor
        ..strokeWidth = trackThickness
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(trackThickness / 2, centerY),
        Offset(playedWidth.clamp(trackThickness / 2, w - trackThickness / 2), centerY),
        activePaint,
      );
    }

    // 3. Draw Thumb
    final thumbCenterX = playedWidth.clamp(thumbRadius, w - thumbRadius);
    final thumbCenter = Offset(thumbCenterX, centerY);

    // Glow / Halo when hovering or dragging
    if (isDragging || isHovered) {
      final haloPaint = Paint()
        ..color = activeColor.withValues(alpha: isDragging ? 0.35 : 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(thumbCenter, thumbRadius + 6, haloPaint);
    }

    // Thumb body
    final thumbPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(thumbCenter, thumbRadius, thumbPaint);

    // Inner subtle center dot if dragging
    if (isDragging) {
      final innerDot = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(thumbCenter, thumbRadius * 0.45, innerDot);
    }
  }

  @override
  bool shouldRepaint(_ModernSliderPainter old) {
    return old.value != value ||
        old.activeColor != activeColor ||
        old.inactiveColor != inactiveColor ||
        old.thumbColor != thumbColor ||
        old.trackThickness != trackThickness ||
        old.thumbRadius != thumbRadius ||
        old.isDragging != isDragging ||
        old.isHovered != isHovered;
  }
}

/// Backward compatibility alias
typedef WaveformSeekBar = M3WavySlider;
