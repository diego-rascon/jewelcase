import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/favorites.dart';
import '../../state/session.dart';
import '../actions.dart';
import '../format.dart';
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
                Icon(Icons.album_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
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
      title: album.name,
      subtitle: album.artist == null
          ? null
          : InkWell(
              onTap: album.artistId == null ? null : () => openArtist(context, album.artistId!),
              child: Text(
                album.artist!,
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
      meta: joinDot([album.year, album.genre, plural(songs.length, 'song'), formatLongDuration(totalDuration)]),
      onPlay: songs.isEmpty ? null : () => player.playSongs(songs),
      onShuffle: songs.isEmpty ? null : () => player.playSongs(songs, shuffle: true),
      actions: [
        FavoriteButton(id: album.id, kind: FavoriteKind.album, size: 26),
        MoreButton(actions: () => albumActions(context, album, includePlay: false)),
      ],
      slivers: [
        SongListScope(
          child: PagedSliver(sliver: SliverList.list(children: rows)),
        ),
      ],
    );
  }
}
