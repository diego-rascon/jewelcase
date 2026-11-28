import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/playlists.dart';
import '../../state/session.dart';
import '../actions.dart';
import '../format.dart';
import '../navigation.dart';
import '../widgets/async_view.dart';
import '../widgets/layout.dart';
import '../widgets/media_cards.dart';
import '../widgets/song_tile.dart';
import 'albums_screen.dart';
import 'artists_screen.dart';
import 'genres_screen.dart';
import 'playlists_screen.dart';
import 'songs_screen.dart';

typedef _Overview = ({List<Album> albums, List<Artist> artists, List<Song> songs, List<Genre> genres});

/// Phone-only: a shelf each of albums, playlists, artists, songs and genres,
/// most recently played first. Each heading opens the full list.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  static const _cardCount = 12;
  static const _songRows = 4;
  static const _songCount = _songRows * 3;
  static const _genreCount = 12;

  /// How many of the last played albums to look for the last played songs in.
  /// The n-th last played song is on one of the n last played albums, so this
  /// many gets at least that many songs right.
  static const _songAlbums = 8;

  Future<_Overview> _load(SessionController session) async {
    final client = session.client;
    final lib = session.libraryId;
    // Every album, for the artists' and genres' last plays and the genre counts.
    final r = await Future.wait<Object>([
      client.getAllAlbums(musicFolderId: lib),
      client.getArtists(musicFolderId: lib),
    ]);
    final all = r[0] as List<Album>;
    final albums = sortAlbums(all, AlbumSort.recent);
    final played = [
      for (final a in albums.take(_songAlbums))
        if (a.played != null) a.id,
    ];
    // Nothing played yet: the start of the Songs screen instead.
    final songs = played.isEmpty
        ? await client.getSongs(size: _songCount, musicFolderId: lib)
        : newestFirst(await client.getSongsOfAlbums(played), (s) => s.played);
    return (
      albums: albums.take(_cardCount).toList(),
      artists: artistsByRecentPlay(r[1] as List<Artist>, all).take(_cardCount).toList(),
      songs: songs.take(_songCount).toList(),
      genres: genresByRecentPlay(all).take(_genreCount).toList(),
    );
  }

  static void _openAll(BuildContext context, String title, Widget screen) =>
      context.read<NavController>().push(_ListPage(title: title, child: screen));

  @override
  Widget build(BuildContext context) {
    final libraryId = context.select<SessionController, String?>((s) => s.libraryId);
    final session = context.read<SessionController>();
    final player = context.read<PlayerController>();
    final pad = pagePadding(context);
    final theme = Theme.of(context);

    Widget section(Widget child) => Padding(padding: const EdgeInsets.only(bottom: 28), child: child);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: AsyncView<_Overview>(
          deps: [libraryId],
          load: () => _load(session),
          builder: (context, data, reload) {
            final songs = data.songs;
            final genres = data.genres;
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: EdgeInsets.only(bottom: 32 + bottomInset(context)),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(pad, 24, pad, 16),
                    child: Text('Library', style: theme.textTheme.headlineMedium),
                  ),
                  if (data.albums.isEmpty)
                    const EmptyState(
                      icon: LucideIcons.libraryBig,
                      title: 'Your library is empty',
                      message: 'Add music to your Navidrome server and it will show up here.',
                    )
                  else ...[
                    section(
                      Shelf(
                        title: 'Albums',
                        onOpen: () => _openAll(context, 'Albums', const AlbumsScreen(showTitle: false)),
                        itemCount: data.albums.length,
                        itemBuilder: (context, i) => AlbumCard(album: data.albums[i]),
                      ),
                    ),
                    section(const _PlaylistShelf(count: _cardCount)),
                    if (data.artists.isNotEmpty)
                      section(
                        Shelf(
                          title: 'Artists',
                          onOpen: () => _openAll(context, 'Artists', const ArtistsScreen(showTitle: false)),
                          itemCount: data.artists.length,
                          itemBuilder: (context, i) => ArtistCard(artist: data.artists[i]),
                        ),
                      ),
                    // Columns of song rows, a bit narrower than the screen so the next one peeks in.
                    if (songs.isNotEmpty)
                      section(
                        Shelf(
                          title: 'Songs',
                          onOpen: () => _openAll(context, 'Songs', const SongsScreen(showTitle: false)),
                          itemWidth: MediaQuery.sizeOf(context).width - pad - 30,
                          height: null,
                          spacing: 0,
                          itemInset: 10,
                          itemCount: (songs.length / _songRows).ceil(),
                          itemBuilder: (context, c) => SongListScope(
                            child: Column(
                              children: [
                                for (var i = c * _songRows; i < (c + 1) * _songRows && i < songs.length; i++)
                                  SongTile(
                                    song: songs[i],
                                    index: i - c * _songRows,
                                    onTap: () => guarded(context, () => player.playSongs(songs, index: i)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Genre tiles, two to a column.
                    if (genres.isNotEmpty)
                      section(
                        Shelf(
                          title: 'Genres',
                          onOpen: () => _openAll(context, 'Genres', const GenresScreen(showTitle: false)),
                          itemWidth: 180,
                          height: null,
                          spacing: 10,
                          itemCount: (genres.length / 2).ceil(),
                          itemBuilder: (context, c) => Column(
                            children: [
                              _GenreTile(genre: genres[c * 2]),
                              if (c * 2 + 1 < genres.length) ...[
                                const SizedBox(height: 10),
                                _GenreTile(genre: genres[c * 2 + 1]),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A full library list opened from the overview, under a bar with its name
/// and a back button.
class _ListPage extends StatelessWidget {
  const _ListPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(backgroundColor: Colors.transparent, centerTitle: false, titleSpacing: 0, title: Text(title)),
    body: child,
  );
}

/// Favorite songs, then the playlists, last edited first: the server doesn't
/// record when a playlist was played. Loads on its own so playlist edits
/// don't reload the whole overview.
class _PlaylistShelf extends StatelessWidget {
  const _PlaylistShelf({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final client = context.read<SessionController>().client;
    final revision = context.select<PlaylistsController, int>((p) => p.revision);
    return AsyncView<List<Playlist>>(
      deps: [revision],
      load: () async => newestFirst(await client.getPlaylists(), (p) => p.changed).take(count - 1).toList(),
      builder: (context, lists, _) => Shelf(
        title: 'Playlists',
        onOpen: () => LibraryScreen._openAll(context, 'Playlists', const PlaylistsScreen(showTitle: false)),
        itemCount: lists.length + 1,
        itemBuilder: (context, i) => i == 0 ? const FavoriteSongsCard() : PlaylistCard(playlist: lists[i - 1]),
      ),
    );
  }
}

class _GenreTile extends StatelessWidget {
  const _GenreTile({required this.genre});

  final Genre genre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => openGenre(context, genre.name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  genre.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                plural(genre.albumCount, 'album'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
