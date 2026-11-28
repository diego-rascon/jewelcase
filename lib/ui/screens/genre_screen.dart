import 'dart:async';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../state/paged_list.dart';
import '../../state/session.dart';
import '../widgets/async_view.dart';
import '../widgets/layout.dart';
import '../widgets/media_cards.dart';
import '../widgets/paged.dart';

/// The albums tagged [genre] in the selected library, loaded page by page as
/// you scroll.
class GenreScreen extends StatefulWidget {
  const GenreScreen({super.key, required this.genre});

  final String genre;

  @override
  State<GenreScreen> createState() => _GenreScreenState();
}

class _GenreScreenState extends State<GenreScreen> {
  static const _pageSize = 60;

  late final _session = context.read<SessionController>();
  late final _albums = PagedList<Album>((offset) async {
    final page = await _session.client.getAlbumsByGenre(
      widget.genre,
      size: _pageSize,
      offset: offset,
      musicFolderId: _libraryId,
    );
    return (items: page, last: page.length < _pageSize);
  });

  bool _started = false;
  String? _libraryId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lib = context.watch<SessionController>().libraryId;
    if (!_started || lib != _libraryId) {
      _started = true;
      _libraryId = lib;
      // Deferred: this runs mid-build, and reset notifies listeners.
      unawaited(Future.microtask(_reload));
    }
  }

  /// Starts over, e.g. for a newly selected library. Never throws.
  Future<void> _reload() async {
    if (!mounted) return;
    _albums.reset();
    await _albums.loadMore();
  }

  @override
  void dispose() {
    _albums.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      // The genre's name sits in the bar, right after the back chevron.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(widget.genre, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _albums,
          builder: (context, _) {
            final albums = _albums.items;
            return LoadMoreOnScroll(
              list: _albums,
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  if (_albums.error != null && albums.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorState(message: '${_albums.error}', onRetry: _albums.retry),
                    )
                  else if (albums.isEmpty && _albums.isDone)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(icon: LucideIcons.disc3, title: 'No albums in this genre'),
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
                  PagedFooter(list: _albums),
                  const BottomInset(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
