import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/favorites.dart';
import '../../state/session.dart';
import '../actions.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/cover_art.dart';
import '../widgets/detail_header.dart';
import '../widgets/song_tile.dart';

class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({super.key, required this.albumId});

  final String albumId;

  @override
  Widget build(BuildContext context) {
    final client = context.read<SessionController>().client;
    return AsyncView<Album>(
      frame: AsyncView.page,
      load: () => client.getAlbum(albumId),
      builder: (context, album, _) => _AlbumView(album: album),
    );
  }
}

class _AlbumView extends StatelessWidget {
  const _AlbumView({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final theme = Theme.of(context);
    final songs = album.songs;
    final multiDisc = songs.map((s) => s.discNumber ?? 1).toSet().length > 1;
    final totalDuration = songs.fold(Duration.zero, (sum, s) => sum + s.duration);

    final rows = <Widget>[];
    int? disc;
    for (final (i, s) in songs.indexed) {
      final startsDisc = multiDisc && s.discNumber != disc;
      if (startsDisc) {
        disc = s.discNumber;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 18, 10, 6),
            child: Row(
              children: [
                Icon(LucideIcons.disc3, size: IconSizes.small, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Disc ${disc ?? 1}', style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        );
      }
      rows.add(
        SongTile(
          song: s,
          // Indexed by row, so a disc header breaks adjacency between discs.
          index: rows.length,
          startsSection: startsDisc,
          showCover: false,
          showAlbum: false,
          showArtist: s.artist != album.artist,
          onTap: () => player.playSongs(songs, index: i),
        ),
      );
    }

    return DetailPage(
      cover: CoverArt(id: album.coverArt, seed: album.id, radius: 12),
      tintCoverId: album.coverArt,
      title: album.name,
      subtitle: album.artist == null ? null : _ArtistLink(album: album),
      meta: _AlbumMeta(album: album, songCount: songs.length, duration: totalDuration),
      onPlay: songs.isEmpty ? null : (shuffle) => player.playSongs(songs, shuffle: shuffle),
      actions: [
        FavoriteButton(id: album.id, kind: FavoriteKind.album),
        const DownloadButton(),
      ],
      menu: MoreButton(actions: () => albumActions(context, album, includePlay: false)),
      slivers: [
        SongListScope(
          child: PagedSliver(sliver: SliverList.list(children: rows)),
        ),
      ],
    );
  }
}

/// Year, genres, song count and length, with each genre opening its page.
class _AlbumMeta extends StatelessWidget {
  const _AlbumMeta({required this.album, required this.songCount, required this.duration});

  final Album album;
  final int songCount;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final parts = <InlineSpan>[
      if (album.year != null) TextSpan(text: '${album.year}'),
      for (final g in album.genres)
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _GenreLink(genre: g),
        ),
      TextSpan(text: plural(songCount, 'song')),
      TextSpan(text: formatLongDuration(duration)),
    ];
    return Text.rich(
      TextSpan(
        children: [
          for (final (i, part) in parts.indexed) ...[if (i > 0) const TextSpan(text: dotSeparator), part],
        ],
      ),
    );
  }
}

/// A genre name that opens the genre's albums, underlined on hover.
class _GenreLink extends StatefulWidget {
  const _GenreLink({required this.genre});

  final String genre;

  @override
  State<_GenreLink> createState() => _GenreLinkState();
}

class _GenreLinkState extends State<_GenreLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => openGenre(context, widget.genre),
        // Brighter than the rest of the line, so it reads as a link on
        // touch screens too.
        child: Text(
          widget.genre,
          style: TextStyle(
            color: scheme.onSurface,
            decoration: _hover ? TextDecoration.underline : null,
            decorationColor: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// The album's artist, in the page's art-tinted primary color.
class _ArtistLink extends StatelessWidget {
  const _ArtistLink({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: album.artistId == null ? null : () => openArtist(context, album.artistId!),
      child: Text(album.artist!, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}
