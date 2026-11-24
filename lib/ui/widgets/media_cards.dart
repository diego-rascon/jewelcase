import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/session.dart';
import '../actions.dart';
import '../format.dart';
import 'cover_art.dart';

/// Shared card chrome: artwork with a hover lift and optional play button,
/// then a title and subtitle.
class _MediaCard extends StatefulWidget {
  const _MediaCard({
    required this.art,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.actions,
    this.onPlay,
    this.centered = false,
  });

  final Widget art;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final List<MenuAction> Function() actions;
  final bool centered;

  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = widget.centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = widget.centered ? TextAlign.center : TextAlign.start;
    return ContextMenuRegion(
      actions: widget.actions,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: align,
            children: [
              AnimatedScale(
                scale: _hover ? 1.03 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: Stack(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.centered ? 999 : 10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: _hover ? 0.35 : 0.18),
                            blurRadius: _hover ? 22 : 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: widget.art,
                    ),
                    if (widget.onPlay != null)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: AnimatedOpacity(
                          opacity: _hover ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: IgnorePointer(
                            ignoring: !_hover,
                            child: FloatingActionButton.small(
                              heroTag: null,
                              elevation: 2,
                              shape: const CircleBorder(),
                              onPressed: widget.onPlay,
                              child: const Icon(Icons.play_arrow_rounded),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: theme.textTheme.titleSmall,
              ),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: textAlign,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, this.showYear = false});

  final Album album;
  final bool showYear;

  @override
  Widget build(BuildContext context) => _MediaCard(
    art: CoverArt(id: album.coverArt, seed: album.id, radius: 10),
    title: album.name,
    subtitle: showYear ? (album.year?.toString() ?? '') : album.artist,
    onTap: () => openAlbum(context, album.id),
    onPlay: () => guarded(context, () async {
      final full = await context.read<SessionController>().client.getAlbum(album.id);
      if (context.mounted) await context.read<PlayerController>().playSongs(full.songs);
    }),
    actions: () => albumActions(context, album),
  );
}

class ArtistCard extends StatelessWidget {
  const ArtistCard({super.key, required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) => _MediaCard(
    art: CoverArt(id: artist.coverArt, seed: artist.id, circle: true, icon: Icons.person_rounded),
    title: artist.name,
    subtitle: artist.albumCount > 0 ? plural(artist.albumCount, 'album') : null,
    centered: true,
    onTap: () => openArtist(context, artist.id),
    actions: () => artistActions(context, artist),
  );
}

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({super.key, required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) => _MediaCard(
    art: CoverArt(id: playlist.coverArt, seed: playlist.id, radius: 10, icon: Icons.queue_music_rounded),
    title: playlist.name,
    subtitle: plural(playlist.songCount, 'song'),
    onTap: () => openPlaylist(context, playlist),
    onPlay: () => guarded(context, () async {
      final full = await context.read<SessionController>().client.getPlaylist(playlist.id);
      if (context.mounted) await context.read<PlayerController>().playSongs(full.songs);
    }),
    actions: () => [MenuAction('Open', Icons.queue_music_rounded, () => openPlaylist(context, playlist))],
  );
}
