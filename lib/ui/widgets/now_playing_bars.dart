import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/favorites.dart';
import '../actions.dart';
import '../screens/now_playing_screen.dart';
import 'cover_art.dart';
import 'player_controls.dart';
import 'song_tile.dart';

/// Desktop: full-width bar under the content — track · transport · volume.
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final song = context.select<PlayerController, Song?>((p) => p.current);
    final theme = Theme.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: song == null
          ? const SizedBox(width: double.infinity)
          : Container(
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(flex: 3, child: _TrackInfo(song: song)),
                  const Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TransportControls(size: 0.85),
                        SizedBox(height: 22, child: SeekBar(compact: true)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Queue',
                          onPressed: () => openNowPlaying(context, showQueue: true),
                          icon: const Icon(Icons.queue_music_rounded),
                        ),
                        const VolumeControl(),
                        IconButton(
                          tooltip: 'Now playing',
                          onPressed: () => openNowPlaying(context),
                          icon: const Icon(Icons.open_in_full_rounded, size: 20),
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

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        GestureDetector(
          onTap: () => openNowPlaying(context),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SizedBox(
              width: 56,
              child: Hero(
                tag: nowPlayingHeroTag,
                child: CoverArt(id: song.coverArt, seed: song.albumId, radius: 6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Link(
                text: song.title,
                style: theme.textTheme.titleSmall,
                onTap: song.albumId == null ? null : () => openAlbum(context, song.albumId!),
              ),
              _Link(
                text: song.artist ?? '',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                onTap: song.artistId == null ? null : () => openArtist(context, song.artistId!),
              ),
            ],
          ),
        ),
        FavoriteButton(id: song.id, kind: FavoriteKind.song, size: 20),
      ],
    );
  }
}

class _Link extends StatefulWidget {
  const _Link({required this.text, this.style, this.onTap});

  final String text;
  final TextStyle? style;
  final VoidCallback? onTap;

  @override
  State<_Link> createState() => _LinkState();
}

class _LinkState extends State<_Link> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: Text(
        widget.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: widget.style?.copyWith(decoration: _hover && widget.onTap != null ? TextDecoration.underline : null),
      ),
    ),
  );
}

/// Phone: floating card above the tab bar. Tap or swipe up to expand.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    final (song, playing) = context.select<PlayerController, (Song?, bool)>((p) => (p.current, p.playing));
    final theme = Theme.of(context);
    if (song == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: GestureDetector(
        onTap: () => openNowPlaying(context),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -200) openNowPlaying(context);
        },
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          elevation: 6,
          shadowColor: Colors.black54,
          child: SizedBox(
            height: 62,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                  child: Row(
                    children: [
                      Hero(
                        tag: nowPlayingHeroTag,
                        child: SizedBox(
                          width: 46,
                          child: CoverArt(id: song.coverArt, seed: song.albumId, radius: 8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              song.artist ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: p.togglePlay,
                        icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
                      ),
                      IconButton(onPressed: p.next, icon: const Icon(Icons.skip_next_rounded, size: 28)),
                    ],
                  ),
                ),
                Positioned(left: 0, right: 0, bottom: 0, child: _ThinProgress(color: theme.colorScheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinProgress extends StatelessWidget {
  const _ThinProgress({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    return RepaintBoundary(
      child: StreamBuilder<Duration>(
        stream: p.position,
        builder: (context, snap) {
          final total = p.duration.inMilliseconds;
          final v = total == 0 ? 0.0 : ((snap.data?.inMilliseconds ?? 0) / total).clamp(0.0, 1.0);
          return LinearProgressIndicator(value: v, minHeight: 2, color: color, backgroundColor: Colors.transparent);
        },
      ),
    );
  }
}
