import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../state/session.dart';
import '../widgets/async_view.dart';
import '../widgets/layout.dart';
import '../widgets/media_cards.dart';

/// All albums, sortable, loaded page by page as you scroll.
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  static const _pageSize = 60;
  static const _sorts = [
    AlbumSort.newest,
    AlbumSort.alphabeticalByName,
    AlbumSort.alphabeticalByArtist,
    AlbumSort.recent,
    AlbumSort.frequent,
    AlbumSort.random,
  ];

  AlbumSort _sort = AlbumSort.newest;
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
    setState(() => _loading = true);
    try {
      final page = await context.read<SessionController>().client.getAlbumList(
        _sort,
        size: _pageSize,
        offset: _albums.length,
        musicFolderId: _libraryId,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _albums.addAll(page);
        _done = page.length < _pageSize || _sort == AlbumSort.random;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    final theme = Theme.of(context);
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
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final s in _sorts)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(s.label),
                                  selected: s == _sort,
                                  showCheckmark: false,
                                  onSelected: (_) {
                                    if (s == _sort && s != AlbumSort.random) return;
                                    setState(() {
                                      _sort = s;
                                      _reset();
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
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
              else if (_albums.isEmpty && _done)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(icon: Icons.album_outlined, title: 'No albums found'),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  sliver: SliverLayoutBuilder(
                    builder: (context, c) => SliverGrid.builder(
                      gridDelegate: cardGrid(c.crossAxisExtent),
                      itemCount: _albums.length,
                      itemBuilder: (context, i) => AlbumCard(album: _albums[i]),
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
            ],
          ),
        ),
      ),
    );
  }
}
