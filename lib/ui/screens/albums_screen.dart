import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/models.dart';
import '../../state/favorites.dart';
import '../../state/session.dart';
import '../widgets/async_view.dart';
import '../widgets/layout.dart';
import '../widgets/media_cards.dart';

/// All albums, sortable, loaded page by page as you scroll. The favorites
/// filter loads every starred album at once and sorts them locally, since
/// the server can't sort starred albums.
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  static const _pageSize = 60;
  static const _sorts = [
    AlbumSort.alphabeticalByArtist,
    AlbumSort.alphabeticalByName,
    AlbumSort.byYear,
    AlbumSort.recent,
    AlbumSort.newest,
  ];

  static const _sortKey = 'jewelcase.albumSort';

  AlbumSort _sort = AlbumSort.alphabeticalByArtist;

  /// The last sort the user picked; the first load waits for it.
  late final Future<void> _restored = _restoreSort();
  bool _favoritesOnly = false;
  final _albums = <Album>[];
  bool _loading = false;
  bool _done = false;
  Object? _error;
  bool _started = false;
  String? _libraryId;

  /// Bumped on every reset, so pages requested for an older sort or library
  /// are dropped when they arrive.
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lib = context.watch<SessionController>().libraryId;
    if (!_started || lib != _libraryId) {
      _started = true;
      _libraryId = lib;
      _reset();
    }
  }

  Future<void> _restoreSort() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_sortKey);
      _sort = _sorts.firstWhere((s) => s.apiValue == saved, orElse: () => _sort);
    } on Exception catch (e) {
      debugPrint('Could not read the album sort: $e');
    }
  }

  static Future<void> _saveSort(AlbumSort sort) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_sortKey, sort.apiValue);
    } on Exception catch (e) {
      debugPrint('Could not save the album sort: $e');
    }
  }

  void _reset() {
    _generation++;
    _albums.clear();
    _loading = false;
    _done = false;
    _error = null;
    // Deferred: _reset can run from didChangeDependencies, mid-build.
    unawaited(Future.microtask(_loadMore));
  }

  void _retry() {
    setState(() => _error = null);
    unawaited(_loadMore());
  }

  // Stops on error until the user retries, instead of re-requesting on
  // every scroll event.
  Future<void> _loadMore() async {
    if (!mounted || _loading || _done || _error != null) return;
    final generation = _generation;
    final client = context.read<SessionController>().client;
    setState(() => _loading = true);
    try {
      await _restored;
      if (!mounted || generation != _generation) return;
      if (_favoritesOnly) {
        final starred = await client.getStarred(musicFolderId: _libraryId);
        if (!mounted || generation != _generation) return;
        setState(() {
          _albums.addAll(sortAlbums(starred.albums, _sort));
          _done = true;
        });
        return;
      }
      final page = await client.getAlbumList(_sort, size: _pageSize, offset: _albums.length, musicFolderId: _libraryId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _albums.addAll(page);
        _done = page.length < _pageSize;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  void _setSort(AlbumSort sort) {
    if (sort == _sort) return;
    unawaited(_saveSort(sort));
    setState(() {
      _sort = sort;
      _reset();
    });
  }

  void _setFavoritesOnly(bool value) => setState(() {
    _favoritesOnly = value;
    _reset();
  });

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    final theme = Theme.of(context);
    // Hide albums un-hearted since the favorites were loaded.
    final favorites = _favoritesOnly ? context.watch<FavoritesController>() : null;
    final albums = favorites == null ? _albums : _albums.where((a) => favorites.isFavorite(a.id)).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 800) unawaited(_loadMore());
            return false;
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, widget.showTitle ? 24 : 12, pad, 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showTitle) ...[
                        Text('Albums', style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 16),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          MenuAnchor(
                            alignmentOffset: const Offset(0, 6),
                            menuChildren: [
                              for (final s in _sorts)
                                MenuItemButton(
                                  leadingIcon: SizedBox.square(
                                    dimension: 20,
                                    child: s == _sort
                                        ? Icon(Icons.check_rounded, size: 20, color: theme.colorScheme.primary)
                                        : null,
                                  ),
                                  onPressed: () => _setSort(s),
                                  child: Text(s.label),
                                ),
                            ],
                            builder: (context, menu, _) => ActionChip(
                              tooltip: 'Sort by',
                              avatar: const Icon(Icons.sort_rounded),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [Text(_sort.label), const Icon(Icons.arrow_drop_down_rounded, size: 20)],
                              ),
                              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                            ),
                          ),
                          FavoritesFilterChip(selected: _favoritesOnly, onSelected: _setFavoritesOnly),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null && _albums.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(message: '$_error', onRetry: _retry),
                )
              else if (albums.isEmpty && _done)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _favoritesOnly
                      ? const EmptyState(
                          icon: Icons.favorite_border_rounded,
                          title: 'No favorite albums',
                          message: 'Use “Add to favorites” on any album to see it here.',
                        )
                      : const EmptyState(icon: Icons.album_outlined, title: 'No albums found'),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  sliver: SliverLayoutBuilder(
                    builder: (context, c) => SliverGrid.builder(
                      gridDelegate: cardGrid(c.crossAxisExtent),
                      itemCount: albums.length,
                      itemBuilder: (context, i) => AlbumCard(album: albums[i]),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator(strokeCap: StrokeCap.round)
                        : _error != null && _albums.isNotEmpty
                        ? FilledButton.tonal(onPressed: _retry, child: const Text('Couldn’t load more · Retry'))
                        : null,
                  ),
                ),
              ),
              const BottomInset(),
            ],
          ),
        ),
      ),
    );
  }
}
