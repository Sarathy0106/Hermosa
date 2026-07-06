import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/player_service.dart';
import '../services/saavn_api.dart';
import '../theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_tile.dart';

/// Generic detail screen for an API playlist / album / artist song list.
class CollectionScreen extends StatefulWidget {
  final String title;
  final String imageUrl;
  final Future<List<Song>> Function(SaavnApi api) loader;

  const CollectionScreen({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.loader,
  });

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  List<Song>? _songs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final songs = await widget.loader(context.read<SaavnApi>());
      if (mounted) setState(() => _songs = songs);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load songs.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.bg,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              title: Text(widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.imageUrl.isNotEmpty)
                    CoverImage(
                        url: widget.imageUrl,
                        size: double.infinity,
                        radius: 0),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.bg],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (songs == null && _error == null)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                  child: Text(_error!,
                      style:
                          const TextStyle(color: AppColors.textSecondary))),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text('${songs!.length} songs',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black),
                      onPressed: songs.isEmpty
                          ? null
                          : () =>
                              context.read<PlayerService>().playAll(songs),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play all'),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: songs.isEmpty
                          ? null
                          : () async {
                              final p = context.read<PlayerService>();
                              await p.playAll(songs);
                              if (!p.player.shuffleModeEnabled) {
                                await p.toggleShuffle();
                              }
                            },
                      icon: const Icon(Icons.shuffle_rounded,
                          color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ),
            SliverList.builder(
              itemCount: songs.length,
              itemBuilder: (context, i) => SongTile(
                song: songs[i],
                onTap: () => context
                    .read<PlayerService>()
                    .playAll(songs, startIndex: i),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        ],
      ),
    );
  }
}
