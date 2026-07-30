import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import '../services/saavn_api.dart';
import '../services/theme_provider.dart';
import 'glass.dart';

/// Parsed LRC line with optional timestamp.
class _LyricLine {
  final Duration? timestamp;
  final String text;

  _LyricLine(this.timestamp, this.text);
}

/// Synced or static lyrics viewer with karaoke-style highlighting.
class LyricsViewer extends StatefulWidget {
  final String songId;
  final Duration totalDuration;
  final Duration position;

  const LyricsViewer({
    super.key,
    required this.songId,
    required this.totalDuration,
    required this.position,
  });

  @override
  State<LyricsViewer> createState() => _LyricsViewerState();
}

class _LyricsViewerState extends State<LyricsViewer> {
  List<_LyricLine> _lines = [];
  bool _loading = true;
  String? _error;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  @override
  void didUpdateWidget(LyricsViewer old) {
    super.didUpdateWidget(old);
    if (old.songId != widget.songId) {
      _fetchLyrics();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLyrics() async {
    setState(() {
      _loading = true;
      _error = null;
      _lines = [];
    });
    try {
      final api = context.read<SaavnApi>();
      final raw = await api.fetchLyrics(widget.songId);
      if (!mounted) return;
      if (raw == null || raw.trim().isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No lyrics available';
        });
        return;
      }
      _parseLyrics(raw);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load lyrics';
        });
      }
    }
  }

  void _parseLyrics(String raw) {
    final lines = raw.split('\n').map((line) => line.trim()).where((l) => l.isNotEmpty).toList();
    final parsed = <_LyricLine>[];
    var hasTimestamps = false;

    for (final line in lines) {
      // Try to parse LRC timestamp: [mm:ss.xx] or [mm:ss]
      final lrcMatch = RegExp(r'^\[(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?\](.*)').firstMatch(line);
      if (lrcMatch != null) {
        final mins = int.parse(lrcMatch.group(1)!);
        final secs = int.parse(lrcMatch.group(2)!);
        final millis = lrcMatch.group(3) != null
            ? int.parse(lrcMatch.group(3)!.padRight(3, '0'))
            : 0;
        parsed.add(_LyricLine(
          Duration(milliseconds: mins * 60000 + secs * 1000 + millis),
          lrcMatch.group(4)!.trim(),
        ));
        hasTimestamps = true;
      } else {
        parsed.add(_LyricLine(null, line));
      }
    }

    // If no timestamps, distribute lines evenly across song duration
    if (!hasTimestamps && widget.totalDuration.inMilliseconds > 0) {
      final segment = widget.totalDuration.inMilliseconds / parsed.length;
      for (var i = 0; i < parsed.length; i++) {
        parsed[i] = _LyricLine(
          Duration(milliseconds: (segment * i).round()),
          parsed[i].text,
        );
      }
    }

    setState(() {
      _lines = parsed;
      _loading = false;
    });
  }

  int get _currentLineIndex {
    if (_lines.isEmpty) return 0;
    final pos = widget.position.inMilliseconds;
    var active = 0;
    for (var i = 0; i < _lines.length; i++) {
      final ts = _lines[i].timestamp;
      if (ts != null && pos >= ts.inMilliseconds) {
        active = i;
      }
    }
    return active;
  }

  @override
  Widget build(BuildContext context) {
    final h = context.hermosa;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: h.textSecondary)),
      );
    }
    if (_lines.isEmpty) {
      return Center(
        child: Text('No lyrics', style: TextStyle(color: h.textSecondary)),
      );
    }

    final currentIndex = _currentLineIndex;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _lines.length,
      itemBuilder: (context, i) {
        final line = _lines[i];
        final isCurrent = i == currentIndex;
        final isPast = i < currentIndex;

        return AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: isCurrent ? 20 : (isPast ? 16 : 16),
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
            color: isCurrent
                ? h.primary
                : (isPast ? h.textSecondary.withValues(alpha: 0.5) : h.textPrimary),
            height: 1.8,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              line.text,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

/// Opens full-screen lyrics overlay on the player screen.
void showLyricsOverlay(BuildContext context, String songId, Duration totalDuration) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => _LyricsOverlay(
        songId: songId,
        totalDuration: totalDuration,
      ),
      transitionsBuilder: (context, anim, secondaryAnim, child) => FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 200),
      opaque: false,
    ),
  );
}

class _LyricsOverlay extends StatelessWidget {
  final String songId;
  final Duration totalDuration;

  const _LyricsOverlay({
    required this.songId,
    required this.totalDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<Duration>(
        stream: context.read<PlayerService>().player.positionStream,
        builder: (context, snap) {
          final pos = snap.data ?? Duration.zero;
          return Glass(
            borderRadius: BorderRadius.circular(0),
            tint: const Color(0xF207070C),
            blur: 30,
            child: SafeArea(
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: const Text('Lyrics'),
                    centerTitle: true,
                  ),
                  Expanded(
                    child: LyricsViewer(
                      songId: songId,
                      totalDuration: totalDuration,
                      position: pos,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
