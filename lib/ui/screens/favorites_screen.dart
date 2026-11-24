import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/favorites.dart';
import '../../state/session.dart';
import '../widgets/async_view.dart';
import '../widgets/layout.dart';
import '../widgets/media_cards.dart';
import '../widgets/song_tile.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final favorites = context.read<FavoritesController>();
    final theme = Theme.of(context);
    final pad = pagePadding(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 24, pad, 8),
                child: Text('Favorites', style: theme.textTheme.headlineMedium),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad - 12),
                child: const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: 'Songs'),
                    Tab(text: 'Albums'),
                    Tab(text: 'Artists'),
                  ],
                ),
              ),
              Expanded(
                child: AsyncView<SearchResults>(
                  deps: [session.libraryId],
                  load: () async {
                    // The heart state covers all libraries; the lists only
                    // the selected one, which needs its own request.
                    final all = favorites.refresh();
                    final id = session.libraryId;
                    if (id == null) return all;
                    final (_, starred) = await (all, session.client.getStarred(musicFolderId: id)).wait;
                    return starred;
                  },
                  builder: (context, starred, reload) => TabBarView(
                    children: [
                      _FavoriteSongs(songs: starred.songs, onRefresh: reload),
                      _CardGrid(
                        empty: 'No favorite albums',
                        count: starred.albums.length,
                        onRefresh: reload,
                        builder: (i) => AlbumCard(album: starred.albums[i]),
                      ),
                      _CardGrid(
                        empty: 'No favorite artists',
                        count: starred.artists.length,
                        onRefresh: reload,
                        builder: (i) => ArtistCard(artist: starred.artists[i]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteSongs extends StatelessWidget {
  const _FavoriteSongs({required this.songs, required this.onRefresh});

  final List<Song> songs;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final pad = pagePadding(context);
    // Hide songs un-hearted since the list was loaded.
    final favorites = context.watch<FavoritesController>();
    final visible = songs.where((s) => favorites.isFavorite(s.id)).toList();
    if (visible.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No favorite songs yet',
        message: 'Tap the heart on any song to save it here.',
      );
    }
    // Built lazily: favorites can run into the thousands.
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(pad - 10, 16, pad - 10, 32),
        itemCount: visible.length + 1,
        itemBuilder: (context, i) => i == 0
            ? _actions(player, visible)
            : SongTile(
                song: visible[i - 1],
                onTap: () => player.playSongs(visible, index: i - 1),
              ),
      ),
    );
  }

  Widget _actions(PlayerController player, List<Song> visible) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
    child: Wrap(
      spacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => player.playSongs(visible),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Play all'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => player.playSongs(visible, shuffle: true),
          icon: const Icon(Icons.shuffle_rounded),
          label: const Text('Shuffle'),
        ),
      ],
    ),
  );
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.empty, required this.count, required this.builder, required this.onRefresh});

  final String empty;
  final int count;
  final Widget Function(int) builder;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return EmptyState(icon: Icons.favorite_border_rounded, title: empty);
    final pad = pagePadding(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 20, pad, 32),
            sliver: SliverLayoutBuilder(
              builder: (context, c) => SliverGrid.builder(
                gridDelegate: cardGrid(c.crossAxisExtent),
                itemCount: count,
                itemBuilder: (context, i) => builder(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
