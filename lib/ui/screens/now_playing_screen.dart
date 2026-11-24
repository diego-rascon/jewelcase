import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/favorites.dart';
import '../actions.dart';
import '../widgets/art_colors.dart';
import '../widgets/cover_art.dart';
import '../widgets/player_controls.dart';
import '../widgets/song_tile.dart';
import 'queue_view.dart';

const nowPlayingHeroTag = 'now-playing-art';

void openNowPlaying(BuildContext context, {bool showQueue = false}) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => NowPlayingScreen(initiallyShowQueue: showQueue),
      transitionsBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
        child: child,
      ),
    ),
  );
}

/// Full-screen player tinted with colors pulled from the album art.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key, this.initiallyShowQueue = false});

  final bool initiallyShowQueue;

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  late bool _showQueue = widget.initiallyShowQueue;

  @override
  Widget build(BuildContext context) {
    final song = context.select<PlayerController, Song?>((p) => p.current);
    if (song == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold();
    }

    return ArtTinted(
      coverId: song.coverArt,
      builder: (context, art) {
        final base = art?.primaryContainer ?? const Color(0xFF2A2A32);
        final deep = Color.lerp(base, Colors.black, 0.72)!;
        const fg = Colors.white;
        final wide = MediaQuery.sizeOf(context).width >= 900;

        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: art ?? ColorScheme.fromSeed(seedColor: base, brightness: Brightness.dark),
            iconTheme: const IconThemeData(color: fg),
          ),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // Blurred artwork wash behind a gradient for depth. Its own
                // layer, so the expensive blur is only painted when the art changes.
                RepaintBoundary(
                  child: Opacity(
                    opacity: 0.45,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80, tileMode: TileMode.decal),
                      child: CoverArt(id: song.coverArt, seed: song.albumId, size: 150, radius: 0),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [base.withValues(alpha: 0.75), deep.withValues(alpha: 0.95)],
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      _TopBar(
                        showQueue: _showQueue,
                        onToggleQueue: () => setState(() => _showQueue = !_showQueue),
                        song: song,
                      ),
                      Expanded(
                        child: wide
                            ? Row(
                                children: [
                                  Expanded(child: _PlayerPanel(song: song, wide: true)),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                    child: _showQueue
                                        ? Container(
                                            width: 400,
                                            margin: const EdgeInsets.fromLTRB(0, 8, 24, 24),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.25),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: const Padding(
                                              padding: EdgeInsets.only(top: 12),
                                              child: QueueView(foreground: fg),
                                            ),
                                          )
                                        : const SizedBox(height: double.infinity),
                                  ),
                                ],
                              )
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: _showQueue
                                    ? const QueueView(key: ValueKey('queue'), foreground: fg)
                                    : _PlayerPanel(key: const ValueKey('player'), song: song, wide: false),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.showQueue, required this.onToggleQueue, required this.song});

  final bool showQueue;
  final VoidCallback onToggleQueue;
  final Song song;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Close',
          iconSize: 30,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        Expanded(
          child: Text(
            'NOW PLAYING',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white70, letterSpacing: 2),
          ),
        ),
        IconButton(
          tooltip: showQueue ? 'Hide queue' : 'Show queue',
          isSelected: showQueue,
          onPressed: onToggleQueue,
          icon: const Icon(Icons.queue_music_rounded),
          selectedIcon: const Icon(Icons.queue_music_rounded, color: Colors.white),
          style: IconButton.styleFrom(backgroundColor: showQueue ? Colors.white24 : null),
        ),
        MoreButton(icon: Icons.more_vert_rounded, actions: () => songActions(context, song)),
      ],
    ),
  );
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({super.key, required this.song, required this.wide});

  final Song song;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktopLike = MediaQuery.sizeOf(context).width >= 600;

    return LayoutBuilder(
      builder: (context, c) {
        // Art takes what's left after the controls (~250px), capped for taste.
        final artSize = (c.maxHeight - 260).clamp(160.0, wide ? 520.0 : 440.0).clamp(0.0, c.maxWidth - 48);
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: artSize < 360 ? 360 : artSize.toDouble()),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: nowPlayingHeroTag,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(song.coverArt ?? song.id),
                        width: artSize.toDouble(),
                        height: artSize.toDouble(),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 48, offset: Offset(0, 20))],
                        ),
                        child: CoverArt(id: song.coverArt, seed: song.albumId, radius: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: song.albumId == null ? null : () => openAlbum(context, song.albumId!),
                              child: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 2),
                            GestureDetector(
                              onTap: song.artistId == null ? null : () => openArtist(context, song.artistId!),
                              child: Text(
                                song.artist ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      FavoriteButton(id: song.id, kind: FavoriteKind.song, size: 28, color: Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SeekBar(color: Colors.white),
                  const SizedBox(height: 8),
                  const TransportControls(size: 1.4, color: Colors.white),
                  if (isDesktopLike) ...[const SizedBox(height: 12), const VolumeControl(width: 180)],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
