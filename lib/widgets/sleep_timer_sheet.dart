import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import '../services/theme_provider.dart';
import '../widgets/glass.dart';

/// Sleep timer bottom sheet with presets and custom duration.
Future<void> showSleepTimerSheet(BuildContext context) {
  final player = context.read<PlayerService>();

  final presets = const [
    ('15 min', Duration(minutes: 15)),
    ('30 min', Duration(minutes: 30)),
    ('45 min', Duration(minutes: 45)),
    ('1 hour', Duration(hours: 1)),
    ('1.5 hours', Duration(minutes: 90)),
    ('2 hours', Duration(hours: 2)),
  ];

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Glass(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      tint: const Color(0xD912121C),
      blur: 28,
      padding: const EdgeInsets.only(bottom: 24),
      child: _SleepTimerSheet(
        player: player,
        presets: presets,
      ),
    ),
  );
}

class _SleepTimerController {
  _SleepTimerController._();
  static final instance = _SleepTimerController._();

  Timer? _timer;

  void start(Duration duration, PlayerService player) {
    cancel();
    _timer = Timer(duration, () {
      if (player.player.playing) {
        player.player.pause();
      }
      _timer = null;
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  bool get isActive => _timer != null && _timer!.isActive;
}

class _SleepTimerSheet extends StatefulWidget {
  final PlayerService player;
  final List<(String, Duration)> presets;

  const _SleepTimerSheet({
    required this.player,
    required this.presets,
  });

  @override
  State<_SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<_SleepTimerSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  void _setTimer(Duration d) {
    _SleepTimerController.instance.start(d, widget.player);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sleep timer set for ${_formatDuration(d)}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.hermosa.surfaceHigh,
      ),
    );
  }

  void _cancelTimer() {
    _SleepTimerController.instance.cancel();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sleep timer cancelled'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.hermosa.surfaceHigh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = context.hermosa;
    final isActive = _SleepTimerController.instance.isActive;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: h.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Sleep Timer', style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                if (isActive)
                  TextButton.icon(
                    onPressed: _cancelTimer,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: h.danger),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (isActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: h.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: h.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bedtime_rounded, color: h.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Timer active',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: h.primary)),
                          Text('Music will stop when timer ends',
                              style: TextStyle(color: h.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _cancelTimer,
                      icon: const Icon(Icons.stop_rounded, size: 18),
                      label: const Text('Stop'),
                      style: TextButton.styleFrom(foregroundColor: h.danger),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Presets', style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.presets.map((preset) {
                final label = preset.$1;
                final duration = preset.$2;
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 60) / 3,
                  child: FilledButton.tonal(
                    onPressed: () => _setTimer(duration),
                    style: FilledButton.styleFrom(
                      backgroundColor: h.surfaceHigh,
                      foregroundColor: h.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Custom', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Minutes',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: h.surfaceHigh,
                    ),
                    onSubmitted: (v) {
                      final mins = int.tryParse(v);
                      if (mins != null && mins > 0) {
                        _setTimer(Duration(minutes: mins));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final mins = int.tryParse(_controller.text);
                    if (mins != null && mins > 0) {
                      _setTimer(Duration(minutes: mins));
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: h.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Set'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}