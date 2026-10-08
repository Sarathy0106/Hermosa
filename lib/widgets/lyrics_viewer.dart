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
  final String? title;
  final String? artist;
  final Duration totalDuration;
  final Duration position;

  const LyricsViewer({
    super.key,
    required this.songId,
    this.title,
    this.artist,
    required this.totalDuration,
    required this.position,
  });

  @override
  State<LyricsViewer> createState() => _LyricsViewerState();
}

class _LyricsViewerState extends State<LyricsViewer> {
  List<_LyricLine> _lines = [];
  bool _hasTimestamps = false;
  bool _loading = true;
  String? _error;
  final _scrollController = ScrollController();
  int _lastActiveIndex = -1;

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
      _hasTimestamps = false;
      _lastActiveIndex = -1;
    });
    try {
      final api = context.read<SaavnApi>();
      final raw = await api.fetchLyrics(
        widget.songId,
        title: widget.title,
        artist: widget.artist,
        duration: widget.totalDuration.inSeconds,
      );
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
    final tagPattern = RegExp(r'\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?\]');
    final stripPattern = RegExp(r'\[\d{1,2}:\d{2}(?:[\.:]\d{1,3})?\]');
    final metadataPattern = RegExp(r'^\[(ti|ar|al|au|by|offset|length|re|ve):.*\]', caseSensitive: false);

    final rawLines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final parsed = <_LyricLine>[];
    var hasTimestamps = false;

    for (final line in rawLines) {
      if (metadataPattern.hasMatch(line)) continue;

      final matches = tagPattern.allMatches(line);
      final cleanText = line.replaceAll(stripPattern, '').trim();

      if (matches.isNotEmpty) {
        hasTimestamps = true;
        final displayText = cleanText.isNotEmpty ? cleanText : '♪';
        for (final match in matches) {
          final mins = int.parse(match.group(1)!);
          final secs = int.parse(match.group(2)!);
          final msRaw = match.group(3);
          var ms = 0;
          if (msRaw != null) {
            if (msRaw.length == 1) {
              ms = int.parse(msRaw) * 100;
            } else if (msRaw.length == 2) {
              ms = int.parse(msRaw) * 10;
            } else {
              ms = int.parse(msRaw.substring(0, 3));
            }
          }
          final time = Duration(milliseconds: mins * 60000 + secs * 1000 + ms);
          parsed.add(_LyricLine(time, displayText));
        }
      } else if (cleanText.isNotEmpty) {
        parsed.add(_LyricLine(null, cleanText));
      }
    }

    if (hasTimestamps) {
      parsed.sort((a, b) => (a.timestamp ?? Duration.zero).compareTo(b.timestamp ?? Duration.zero));
    }

    setState(() {
      _lines = parsed;
      _hasTimestamps = hasTimestamps;
      _loading = false;
    });
  }

  int get _currentLineIndex {
    if (_lines.isEmpty || !_hasTimestamps) return 0;
    final pos = widget.position.inMilliseconds;
    var active = 0;
    for (var i = 0; i < _lines.length; i++) {
      final ts = _lines[i].timestamp;
      if (ts != null) {
        if (pos >= ts.inMilliseconds) {
          active = i;
        } else {
          break;
        }
      }
    }
    return active;
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients || index < 0 || index >= _lines.length || !_hasTimestamps) return;
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (index * 48.0) - (viewportHeight * 0.35);
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
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

    if (_hasTimestamps && currentIndex != _lastActiveIndex) {
      _lastActiveIndex = currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToIndex(currentIndex);
      });
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _lines.length,
      itemBuilder: (context, i) {
        final line = _lines[i];
        final isCurrent = _hasTimestamps && i == currentIndex;
        final isPast = _hasTimestamps && i < currentIndex;

        return AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: _hasTimestamps ? (isCurrent ? 20 : (isPast ? 16 : 16)) : 17,
            fontWeight: _hasTimestamps
                ? (isCurrent ? FontWeight.w700 : FontWeight.w400)
                : FontWeight.w400,
            color: _hasTimestamps
                ? (isCurrent
                    ? h.primary
                    : (isPast ? h.textSecondary.withValues(alpha: 0.5) : h.textPrimary))
                : h.textPrimary,
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
void showLyricsOverlay(
  BuildContext context,
  String songId,
  Duration totalDuration, {
  String? title,
  String? artist,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => _LyricsOverlay(
        songId: songId,
        title: title,
        artist: artist,
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
  final String? title;
  final String? artist;
  final Duration totalDuration;

  const _LyricsOverlay({
    required this.songId,
    this.title,
    this.artist,
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
                      title: title,
                      artist: artist,
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
