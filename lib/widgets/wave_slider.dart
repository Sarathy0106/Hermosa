import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Podcast-style waveform seek bar.
///
/// Real amplitude data isn't available for remote streams, so bar heights
/// are generated deterministically from [seed] (the song id) — every song
/// gets its own consistent waveform. The played portion is drawn with the
/// brand gradient, the rest stays dim.
class WaveformSeekBar extends StatefulWidget {
  final String seed;
  final Duration position;
  final Duration buffered;
  final Duration total;
  final ValueChanged<Duration> onSeek;
  final double height;

  const WaveformSeekBar({
    super.key,
    required this.seed,
    required this.position,
    required this.buffered,
    required this.total,
    required this.onSeek,
    this.height = 56,
  });

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  double? _dragValue; // 0..1 while dragging

  double get _value {
    if (_dragValue != null) return _dragValue!;
    final totalMs = widget.total.inMilliseconds;
    if (totalMs == 0) return 0;
    return (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  double get _bufferedValue {
    final totalMs = widget.total.inMilliseconds;
    if (totalMs == 0) return 0;
    return (widget.buffered.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  void _seekTo(double dx, double width) {
    setState(() => _dragValue = (dx / width).clamp(0.0, 1.0));
  }

  void _commit() {
    final v = _dragValue;
    if (v != null) {
      widget.onSeek(
          Duration(milliseconds: (widget.total.inMilliseconds * v).round()));
    }
    setState(() => _dragValue = null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _seekTo(d.localPosition.dx, w),
          onTapUp: (_) => _commit(),
          onHorizontalDragStart: (d) => _seekTo(d.localPosition.dx, w),
          onHorizontalDragUpdate: (d) => _seekTo(d.localPosition.dx, w),
          onHorizontalDragEnd: (_) => _commit(),
          child: SizedBox(
            height: widget.height,
            child: CustomPaint(
              painter: _WaveformPainter(
                seed: widget.seed,
                value: _value,
                buffered: _bufferedValue,
                dragging: _dragValue != null,
              ),
              size: Size(w, widget.height),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final String seed;
  final double value;
  final double buffered;
  final bool dragging;

  _WaveformPainter({
    required this.seed,
    required this.value,
    required this.buffered,
    required this.dragging,
  });

  /// Deterministic, wave-like bar heights in 0.16..1.0.
  static List<double> _heights(String seed, int count) {
    final rnd = math.Random(seed.hashCode);
    // Sum of a few sine waves with random phase → organic waveform shape,
    // plus per-bar jitter so adjacent bars differ like real audio.
    final p1 = rnd.nextDouble() * math.pi * 2;
    final p2 = rnd.nextDouble() * math.pi * 2;
    final p3 = rnd.nextDouble() * math.pi * 2;
    return List.generate(count, (i) {
      final t = i / count;
      var v = .52 +
          .26 * math.sin(t * math.pi * 5 + p1) +
          .16 * math.sin(t * math.pi * 11 + p2) +
          .10 * math.sin(t * math.pi * 23 + p3);
      v += (rnd.nextDouble() - .5) * .38;
      return v.clamp(.16, 1.0);
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    const barW = 3.0;
    const gap = 3.5;
    final count = math.max(1, (size.width / (barW + gap)).floor());
    final heights = _heights(seed, count);
    final cy = size.height / 2;
    final maxHalf = size.height / 2 - 1;

    final gradientShader = const LinearGradient(
      colors: [AppColors.primary, AppColors.accent],
    ).createShader(Rect.fromLTWH(0, 0, size.width, 0));

    final played = Paint()
      ..shader = gradientShader
      ..strokeWidth = barW
      ..strokeCap = StrokeCap.round;
    final upcoming = Paint()
      ..color = Colors.white.withValues(alpha: .20)
      ..strokeWidth = barW
      ..strokeCap = StrokeCap.round;
    final buffed = Paint()
      ..color = Colors.white.withValues(alpha: .32)
      ..strokeWidth = barW
      ..strokeCap = StrokeCap.round;

    final playedX = size.width * value;
    final bufferedX = size.width * buffered;

    for (var i = 0; i < count; i++) {
      final x = i * (barW + gap) + barW / 2;
      var half = heights[i] * maxHalf;
      // Slight lift near the playhead while dragging for tactile feedback.
      if (dragging) {
        final d = (x - playedX).abs();
        if (d < 30) half = math.min(maxHalf, half + (30 - d) / 30 * 4);
      }
      final paint =
          x <= playedX ? played : (x <= bufferedX ? buffed : upcoming);
      canvas.drawLine(Offset(x, cy - half), Offset(x, cy + half), paint);
    }

    // Playhead line
    final head = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final hx = playedX.clamp(1.5, size.width - 1.5);
    canvas.drawLine(Offset(hx, cy - maxHalf), Offset(hx, cy + maxHalf), head);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.value != value ||
      old.buffered != buffered ||
      old.dragging != dragging ||
      old.seed != seed;
}
