import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/layout.dart';
import '../widgets/media_cards.dart';
import '../widgets/song_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  String? _libraryId;
  Future<SearchResults>? _results;

  Future<SearchResults> _search(String q) =>
      context.read<SessionController>().client.search(q, musicFolderId: _libraryId);

  // Re-run the current search when the user switches library.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lib = context.watch<SessionController>().libraryId;
    if (lib != _libraryId) {
      _libraryId = lib;
      if (_query.isNotEmpty) _results = _search(_query);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = value.trim();
      if (q == _query) return;
      setState(() {
        _query = q;
        _results = q.isEmpty ? null : _search(q);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 24, pad, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: isWide(context),
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Artists, albums, songs',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _controller.clear();
                                  _onChanged('');
                                  _focus.requestFocus();
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _results == null
                  ? const EmptyState(
                      icon: Icons.manage_search_rounded,
                      title: 'Find something to play',
                      message: 'Search for artists, albums and songs in your library.',
                    )
                  : FutureBuilder<SearchResults>(
                      future: _results,
                      builder: (context, snap) {
                        if (snap.hasError) return ErrorState(message: '${snap.error}');
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator(strokeCap: StrokeCap.round));
                        }
                        final r = snap.data!;
                        if (r.isEmpty) {
                          return EmptyState(icon: Icons.search_off_rounded, title: 'No results for “$_query”');
                        }
                        return _Results(results: r);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.results});

  final SearchResults results;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final pad = pagePadding(context);
    final songs = results.songs;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (songs.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: const SectionHeader('Songs'),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad - 10),
            child: Column(
              children: [
                for (final (i, s) in songs.take(8).indexed)
                  SongTile(
                    song: s,
                    onTap: () => player.playSongs(songs, index: i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
        if (results.artists.isNotEmpty) ...[
          Shelf(
            title: 'Artists',
            height: 210,
            itemWidth: 150,
            itemCount: results.artists.length,
            itemBuilder: (context, i) => ArtistCard(artist: results.artists[i]),
          ),
          const SizedBox(height: 28),
        ],
        if (results.albums.isNotEmpty)
          Shelf(
            title: 'Albums',
            itemCount: results.albums.length,
            itemBuilder: (context, i) => AlbumCard(album: results.albums[i]),
          ),
      ],
    );
  }
}
