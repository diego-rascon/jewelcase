import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import '../widgets/layout.dart';
import '../widgets/media_cards.dart';
import '../widgets/song_tile.dart';

typedef _ArtistData = ({Artist artist, ArtistInfo info, List<Song> topSongs});

class ArtistDetailScreen extends StatelessWidget {
  const ArtistDetailScreen({super.key, required this.artistId});

  final String artistId;

  Future<_ArtistData> _load(SessionController session) async {
    final c = session.client;
    final artist = await c.getArtist(artistId);
    // Info and top songs come from Last.fm via Navidrome; tolerate failures.
    final (info, top) = await (
      c.getArtistInfo(artistId).catchError((_) => const ArtistInfo()),
      c.getTopSongs(artist.name).catchError((_) => <Song>[]),
    ).wait;
    return (artist: artist, info: info, topSongs: top);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    return AsyncView<_ArtistData>(
      frame: AsyncView.page,
      load: () => _load(session),
      builder: (context, d, _) => _ArtistView(data: d),
    );
  }
}

class _ArtistView extends StatefulWidget {
  const _ArtistView({required this.data});

  final _ArtistData data;

  @override
  State<_ArtistView> createState() => _ArtistViewState();
}

class _ArtistViewState extends State<_ArtistView> {
  bool _bioExpanded = false;
  bool _showAllTop = false;
  bool _fetchingSongs = false;

  /// Runs [play] with every song by the artist; the play buttons are disabled
  /// while the albums are fetched.
  Future<void> _playAll(List<Album> albums, Future<void> Function(List<Song> songs) play) async {
    final client = context.read<SessionController>().client;
    setState(() => _fetchingSongs = true);
    try {
      await guarded(context, () async => play(await client.getSongsOfAlbums([for (final a in albums) a.id])));
    } finally {
      if (mounted) setState(() => _fetchingSongs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (:artist, :info, :topSongs) = widget.data;
    final player = context.read<PlayerController>();
    final theme = Theme.of(context);
    final pad = pagePadding(context);
    final albums = [...artist.albums]..sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));

    final visibleTop = _showAllTop ? topSongs : topSongs.take(5).toList();

    // Play starts with the top songs; with shuffle on, it mixes the whole
    // discography.
    Future<void> play(bool shuffle) => topSongs.isNotEmpty && (!shuffle || albums.isEmpty)
        ? player.playSongs(topSongs, shuffle: shuffle)
        : _playAll(albums, (songs) => player.playSongs(songs, shuffle: shuffle));

    return DetailPage(
      cover: CoverArt(id: artist.coverArt, seed: artist.id, circle: true, icon: LucideIcons.user),
      kicker: 'Artist',
      title: artist.name,
      meta: Text(joinDot([plural(albums.length, 'album'), if (topSongs.isNotEmpty) 'Top songs available'])),
      onPlay: _fetchingSongs || (topSongs.isEmpty && albums.isEmpty) ? null : play,
      actions: [FavoriteButton(id: artist.id, kind: FavoriteKind.artist)],
      slivers: [
        if (info.biography != null)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 28),
            sliver: SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _bioExpanded = !_bioExpanded),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    alignment: Alignment.topLeft,
                    child: Text(
                      info.biography!,
                      maxLines: _bioExpanded ? null : 3,
                      overflow: _bioExpanded ? null : TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (topSongs.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                'Popular',
                trailing: topSongs.length > 5
                    ? TextButton(
                        onPressed: () => setState(() => _showAllTop = !_showAllTop),
                        child: Text(_showAllTop ? 'Show less' : 'Show all'),
                      )
                    : null,
              ),
            ),
          ),
          SongListScope(
            child: PagedSliver(
              sliver: SliverList.list(
                children: [
                  for (final (i, s) in visibleTop.indexed)
                    SongTile(
                      song: s,
                      index: i,
                      showArtist: false,
                      onTap: () => player.playSongs(topSongs, index: i),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          sliver: const SliverToBoxAdapter(child: SectionHeader('Discography')),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          sliver: SliverLayoutBuilder(
            builder: (context, c) => SliverGrid.builder(
              gridDelegate: cardGrid(c.crossAxisExtent),
              itemCount: albums.length,
              itemBuilder: (context, i) => AlbumCard(album: albums[i], showYear: true),
            ),
          ),
        ),
        if (info.similar.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.only(top: 32),
            sliver: SliverToBoxAdapter(
              child: Shelf(
                title: 'Fans also like',
                height: 210,
                itemWidth: 150,
                itemCount: info.similar.length,
                itemBuilder: (context, i) => ArtistCard(artist: info.similar[i]),
              ),
            ),
          ),
      ],
    );
  }
}
