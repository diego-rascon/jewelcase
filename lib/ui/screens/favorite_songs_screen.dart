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

/// Automatic playlist of every starred song in the selected library.
class FavoriteSongsScreen extends StatefulWidget {
  const FavoriteSongsScreen({super.key});

  static const title = 'Favorite songs';

  /// Placeholder art shared with the playlist card and sidebar entry.
  static Widget cover({double radius = 12}) =>
      CoverArt(id: null, seed: 'favorites', radius: radius, icon: Icons.favorite_rounded);

  @override
  State<FavoriteSongsScreen> createState() => _FavoriteSongsScreenState();
}

class _FavoriteSongsScreenState extends State<FavoriteSongsScreen> {
  SongSort? _sort;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final favorites = context.read<FavoritesController>();
    final player = context.read<PlayerController>();

    return AsyncView<List<Song>>(
      frame: AsyncView.page,
      deps: [session.libraryId],
      load: () async {
        // The heart state covers all libraries; the list only the selected
        // one, which needs its own request.
        final all = favorites.refresh();
        final id = session.libraryId;
        if (id == null) return (await all).songs;
        final (_, starred) = await (all, session.client.getStarred(musicFolderId: id)).wait;
        return starred.songs;
      },
      builder: (context, songs, reload) {
        // Hide songs un-hearted since the list was loaded.
        final favs = context.watch<FavoritesController>();
        final starred = songs.where((s) => favs.isFavorite(s.id)).toList();
        // Phones show no column header, so they keep the playlist's order.
        final wide = isWide(context);
        final visible = [for (final (_, s) in sortSongs(starred, wide ? _sort : null)) s];
        final total = visible.fold(Duration.zero, (sum, s) => sum + s.duration);

        return DetailPage(
          coverId: null,
          cover: FavoriteSongsScreen.cover(),
          title: FavoriteSongsScreen.title,
          meta: joinDot([plural(visible.length, 'song'), formatLongDuration(total)]),
          onPlay: visible.isEmpty ? null : () => player.playSongs(visible),
          onShuffle: visible.isEmpty ? null : () => player.playSongs(visible, shuffle: true),
          actions: [
            MoreButton(
              actions: () => [
                MenuAction(
                  'Add to queue',
                  Icons.add_to_queue_rounded,
                  () => guarded(context, () => player.addToQueue(visible), success: 'Added to queue'),
                ),
                MenuAction('Refresh', Icons.refresh_rounded, () => guarded(context, reload)),
              ],
            ),
          ],
          slivers: [
            if (visible.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'No favorite songs yet',
                  message: 'Tap the heart on any song to save it here.',
                ),
              )
            else if (wide)
              PagedSliver(
                sliver: SliverToBoxAdapter(
                  child: SongListHeader(sort: _sort, onSort: (s) => setState(() => _sort = s)),
                ),
              ),
            // Built lazily: favorites can run into the thousands.
            SongListScope(
              child: PagedSliver(
                sliver: SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, i) => SongTile(
                    song: visible[i],
                    index: i,
                    artistColumn: true,
                    onTap: () => player.playSongs(visible, index: i),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
