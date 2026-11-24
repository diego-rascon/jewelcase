import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/session.dart';
import '../widgets/async_view.dart';
import '../widgets/layout.dart';
import '../widgets/song_tile.dart';

/// Every song in the library, loaded page by page as you scroll.
class SongsScreen extends StatefulWidget {
  const SongsScreen({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  static const _pageSize = 100;

  final _songs = <Song>[];
  bool _loading = false;
  bool _done = false;
  Object? _error;
  bool _started = false;
  String? _libraryId;

  /// Bumped on every reset, so pages requested for an older library are
  /// dropped when they arrive.
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lib = context.watch<SessionController>().libraryId;
    if (!_started || lib != _libraryId) {
      _started = true;
      _libraryId = lib;
      _generation++;
      _songs.clear();
      _loading = false;
      _done = false;
      _error = null;
      // Deferred: this runs mid-build.
      unawaited(Future.microtask(_loadMore));
    }
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
      final page = await context.read<SessionController>().client.getSongs(
        size: _pageSize,
        offset: _songs.length,
        musicFolderId: _libraryId,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _songs.addAll(page);
        _done = page.length < _pageSize;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
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
                padding: EdgeInsets.fromLTRB(pad, widget.showTitle ? 24 : 12, pad, widget.showTitle ? 16 : 4),
                sliver: SliverToBoxAdapter(
                  child: widget.showTitle ? Text('Songs', style: theme.textTheme.headlineMedium) : null,
                ),
              ),
              if (_error != null && _songs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(message: '$_error', onRetry: _retry),
                )
              else if (_songs.isEmpty && _done)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(icon: Icons.music_note_outlined, title: 'No songs found'),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: pad - 10),
                  sliver: SliverList.builder(
                    itemCount: _songs.length,
                    itemBuilder: (context, i) => SongTile(
                      song: _songs[i],
                      onTap: () => player.playSongs(List.of(_songs), index: i),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator(strokeCap: StrokeCap.round)
                        : _error != null && _songs.isNotEmpty
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
