import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/session.dart';
import '../actions.dart';
import '../format.dart';
import '../theme.dart';
import '../screens/favorite_songs_screen.dart';
import 'cover_art.dart';
import 'filled_icon.dart';
import 'frosted.dart';

/// Shared card chrome: artwork, then a title and subtitle. Cards with [onPlay]
/// show a play button (bottom left) and a "⋯" menu (bottom right) on hover.
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

  /// A round button on the floating player's frosted material.
  Widget _frosted(Widget button) => Frosted(
    edge: FrostedEdge.none,
    child: IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          fixedSize: const Size.square(32),
          minimumSize: const Size.square(32),
          padding: EdgeInsets.zero,
          iconSize: IconSizes.small,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      child: button,
    ),
  );

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
              Stack(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.centered ? 999 : 10),
                      boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 12, offset: Offset(0, 6))],
                    ),
                    child: widget.art,
                  ),
                  if (widget.onPlay != null)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: AnimatedOpacity(
                        opacity: _hover ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: IgnorePointer(
                          ignoring: !_hover,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _frosted(
                                IconButton(
                                  tooltip: 'Play',
                                  icon: const FilledIcon(FilledIcons.play),
                                  onPressed: widget.onPlay,
                                ),
                              ),
                              _frosted(MoreButton(actions: widget.actions)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
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
    art: CoverArt(id: artist.coverArt, seed: artist.id, circle: true, icon: LucideIcons.user),
    title: artist.name,
    subtitle: artist.albumCount > 0 ? plural(artist.albumCount, 'album') : null,
    centered: true,
    onTap: () => openArtist(context, artist.id),
    actions: () => artistActions(context, artist),
  );
}

/// A genre, on a placeholder tile seeded by its name (genres have no art).
class GenreCard extends StatelessWidget {
  const GenreCard({super.key, required this.genre});

  final Genre genre;

  @override
  Widget build(BuildContext context) => _MediaCard(
    art: CoverArt(id: null, seed: genre.name, radius: 10, icon: LucideIcons.tag),
    title: genre.name,
    subtitle: plural(genre.albumCount, 'album'),
    onTap: () => openGenre(context, genre.name),
    actions: () => [MenuAction('Open', LucideIcons.tag, () => openGenre(context, genre.name))],
  );
}

/// The automatic Favorite songs playlist, listed before the real ones.
class FavoriteSongsCard extends StatelessWidget {
  const FavoriteSongsCard({super.key});

  @override
  Widget build(BuildContext context) => _MediaCard(
    art: FavoriteSongsScreen.cover(radius: 10),
    title: FavoriteSongsScreen.title,
    subtitle: 'Automatic playlist',
    onTap: () => openFavoriteSongs(context),
    onPlay: () => guarded(context, () async {
      final session = context.read<SessionController>();
      final starred = await session.client.getStarred(musicFolderId: session.libraryId);
      if (context.mounted) await context.read<PlayerController>().playSongs(starred.songs);
    }),
    actions: () => [MenuAction('Open', LucideIcons.star, () => openFavoriteSongs(context))],
  );
}

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({super.key, required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) => _MediaCard(
    art: CoverArt(id: playlist.coverArt, seed: playlist.id, radius: 10, icon: LucideIcons.listMusic),
    title: playlist.name,
    subtitle: plural(playlist.songCount, 'song'),
    onTap: () => openPlaylist(context, playlist),
    onPlay: () => guarded(context, () async {
      final full = await context.read<SessionController>().client.getPlaylist(playlist.id);
      if (context.mounted) await context.read<PlayerController>().playSongs(full.songs);
    }),
    actions: () => [MenuAction('Open', LucideIcons.listMusic, () => openPlaylist(context, playlist))],
  );
}
