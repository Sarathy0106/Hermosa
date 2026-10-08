import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/player_service.dart';
import '../services/saavn_api.dart';
import '../theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_tile.dart';

/// Detail screen for an API playlist / album / artist song list.
class CollectionScreen extends StatefulWidget {
  final String? title;
  final String? imageUrl;
  final PlaylistSummary? playlist;
  final Future<List<Song>> Function(SaavnApi api)? loader;

  const CollectionScreen({
    super.key,
    this.title,
    this.imageUrl,
    this.playlist,
    this.loader,
  });

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  List<Song>? _songs;
  String? _error;

  String get _displayTitle => widget.playlist?.name ?? widget.title ?? 'Collection';
  String get _displayImage => widget.playlist?.imageUrl ?? widget.imageUrl ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _songs = null;
      _error = null;
    });
    try {
      final api = context.read<SaavnApi>();
      List<Song> songs;
      if (widget.loader != null) {
        songs = await widget.loader!(api);
      } else if (widget.playlist != null) {
        final (_, _, s) = await api.playlistSongs(widget.playlist!.id);
        songs = s;
      } else {
        songs = [];
      }
      if (mounted) setState(() => _songs = songs);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load songs.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs;
    final player = context.watch<PlayerService>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Cinematic Expanded AppBar ─────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(56, 0, 20, 16),
              title: Text(
                _displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_displayImage.isNotEmpty)
                    CoverImage(
                      url: _displayImage,
                      size: double.infinity,
                      radius: 0,
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          AppColors.bg.withValues(alpha: 0.85),
                          AppColors.bg,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading or Error ──────────────────────────────────────
          if (songs == null && _error == null)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white38),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          else if (songs!.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('No songs found in this collection', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else ...[
            // ── Controls Header (Play All, Shuffle, Count) ─────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Text(
                      '${songs.length} Tracks',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF13111A),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onPressed: () => player.playAll(songs),
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () async {
                        await player.playAll(songs);
                        if (!player.player.shuffleModeEnabled) {
                          await player.toggleShuffle();
                        }
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceHigh,
                      ),
                      icon: const Icon(Icons.shuffle_rounded, color: AppColors.secondary, size: 20),
                    ),
                  ],
                ),
              ),
            ),

            // ── Songs List ──────────────────────────────────────────
            SliverList.builder(
              itemCount: songs.length,
              itemBuilder: (context, i) => SongTile(
                index: i + 1,
                song: songs[i],
                onTap: () => player.playAll(songs, startIndex: i),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ],
      ),
    );
  }
}
