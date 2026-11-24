import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../state/favorites.dart';
import '../../state/session.dart';
import '../actions.dart';
import '../format.dart';
import '../widgets/async_view.dart';
import '../widgets/cover_art.dart';
import '../widgets/layout.dart';

/// Alphabetical artist list with a favorites filter.
class ArtistsScreen extends StatelessWidget {
  const ArtistsScreen({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: AsyncView<List<Artist>>(
          deps: [session.libraryId],
          load: () => session.client.getArtists(musicFolderId: session.libraryId),
          builder: (context, artists, reload) => _ArtistList(artists: artists, showTitle: showTitle),
        ),
      ),
    );
  }
}

class _ArtistList extends StatefulWidget {
  const _ArtistList({required this.artists, required this.showTitle});

  final List<Artist> artists;
  final bool showTitle;

  @override
  State<_ArtistList> createState() => _ArtistListState();
}

class _ArtistListState extends State<_ArtistList> {
  static const _rowHeight = 68.0;
  final _scroll = ScrollController();
  late List<Artist> _sorted;
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _sort();
  }

  @override
  void didUpdateWidget(_ArtistList old) {
    super.didUpdateWidget(old);
    if (old.artists != widget.artists) _sort();
  }

  void _sort() {
    _sorted = [...widget.artists]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = pagePadding(context);
    // Only the filtered view depends on what is starred.
    final favorites = _favoritesOnly ? context.watch<FavoritesController>() : null;
    final visible = favorites == null ? _sorted : _sorted.where((a) => favorites.isFavorite(a.id)).toList();
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, widget.showTitle ? 24 : 12, pad, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showTitle) ...[
                  Text('Artists', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 16),
                ],
                FavoritesFilterChip(
                  selected: _favoritesOnly,
                  onSelected: (v) => setState(() {
                    _favoritesOnly = v;
                    if (_scroll.hasClients) _scroll.jumpTo(0);
                  }),
                ),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _favoritesOnly
                ? const EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'No favorite artists',
                    message: 'Use “Add to favorites” on any artist to see them here.',
                  )
                : const EmptyState(icon: Icons.person_outline_rounded, title: 'No artists found'),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad - 10, 0, pad - 10, 32),
            sliver: SliverFixedExtentList.builder(
              itemExtent: _rowHeight,
              itemCount: visible.length,
              itemBuilder: (context, i) => _ArtistRow(artist: visible[i]),
            ),
          ),
      ],
    );
  }
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ContextMenuRegion(
      actions: () => artistActions(context, artist),
      child: ListTile(
        onTap: () => openArtist(context, artist.id),
        leading: SizedBox(
          width: 48,
          child: CoverArt(id: artist.coverArt, seed: artist.id, circle: true, icon: Icons.person_rounded),
        ),
        title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
        subtitle: artist.albumCount > 0 ? Text(plural(artist.albumCount, 'album')) : null,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
