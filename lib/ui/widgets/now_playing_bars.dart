import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/favorites.dart';
import '../actions.dart';
import '../screens/now_playing_screen.dart';
import 'cover_art.dart';
import 'player_controls.dart';
import 'song_tile.dart';

/// Desktop: lays [child] (the content area) out with the [PlayerBar]
/// floating over its bottom edge. The content's `MediaQuery` bottom padding
/// grows by the bar's footprint, so scroll views can end clear of it (see
/// `BottomInset`) and menus avoid opening underneath it.
class PlayerBarHost extends StatelessWidget {
  const PlayerBarHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasSong = context.select<PlayerController, bool>((p) => p.current != null);
    final mq = MediaQuery.of(context);
    final footprint = hasSong ? PlayerBar.height + PlayerBar.margin * 2 : 0.0;
    return Stack(
      children: [
        MediaQuery(
          data: mq.copyWith(padding: mq.padding.copyWith(bottom: mq.padding.bottom + footprint)),
          child: child,
        ),
        Positioned(
          left: PlayerBar.margin,
          right: PlayerBar.margin,
          bottom: PlayerBar.margin + mq.padding.bottom,
          child: const PlayerBar(),
        ),
      ],
    );
  }
}

/// Desktop: a floating, frosted bar over the bottom of the content area:
/// transport · track panel · queue and volume. Placed by [PlayerBarHost].
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  static const height = 64.0;
  static const margin = 16.0;

  @override
  Widget build(BuildContext context) {
    final song = context.select<PlayerController, Song?>((p) => p.current);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: song == null
          ? const SizedBox(width: double.infinity)
          : _FloatingCard(
              key: const ValueKey('bar'),
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: LayoutBuilder(builder: (context, constraints) => _barRow(context, song, constraints)),
            ),
    );
  }

  Widget _barRow(BuildContext context, Song song, BoxConstraints constraints) {
    // Shuffle/repeat and the volume slider only show when there's room; the
    // track panel takes what's left.
    final showModes = constraints.maxWidth >= 640;
    final showSlider = constraints.maxWidth >= 960;
    return Row(
      children: [
        TransportControls(size: 0.8, showModes: showModes),
        const SizedBox(width: 8),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _TrackPanel(
                song: song,
                artSize: 44,
                padding: const EdgeInsets.symmetric(vertical: 6),
                desktop: true,
                trailing: [
                  FavoriteButton(id: song.id, kind: FavoriteKind.song, size: 20),
                  MoreButton(actions: () => songActions(context, song)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Queue',
          onPressed: () => openNowPlaying(context, showQueue: true),
          icon: const Icon(Icons.queue_music_rounded),
        ),
        VolumeControl(width: showSlider ? 100 : null),
        IconButton(
          tooltip: 'Now playing',
          onPressed: () => openNowPlaying(context),
          icon: const Icon(Icons.open_in_full_rounded, size: 20),
        ),
      ],
    );
  }
}

/// Phone: floating card above the tab bar. Tap or swipe up to expand.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    final (song, playing) = context.select<PlayerController, (Song?, bool)>((p) => (p.current, p.playing));
    if (song == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: GestureDetector(
        onTap: () => openNowPlaying(context),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -200) openNowPlaying(context);
        },
        child: _FloatingCard(
          height: 62,
          child: _TrackPanel(
            song: song,
            artSize: 46,
            padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
            // A square cover would poke out of the card's rounded end.
            roundArt: true,
            trailing: [
              IconButton(
                onPressed: p.togglePlay,
                icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
              ),
              IconButton(onPressed: p.next, icon: const Icon(Icons.skip_next_rounded, size: 28)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The frosted, shadowed, fully rounded card both [PlayerBar] and
/// [MiniPlayer] float in.
class _FloatingCard extends StatelessWidget {
  const _FloatingCard({super.key, required this.height, required this.child, this.padding = EdgeInsets.zero});

  final double height;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              // The sidebar's color and edge, so the chrome reads as one
              // material. Slightly see-through for the frosted look; over
              // plain content it comes out the same as the sidebar.
              color: scheme.surfaceContainerLow.withValues(alpha: 0.9),
              borderRadius: radius,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Cover, title, "artist — album" and a thin progress line for the current
/// song, then [trailing]. Shared by [PlayerBar] and [MiniPlayer].
///
/// On [desktop] the cover opens Now Playing, the title and album link to the
/// album, the artist links to the artist, and the progress line can be
/// clicked or dragged to seek. On phones the whole card is the tap target, so
/// none of that applies.
class _TrackPanel extends StatelessWidget {
  const _TrackPanel({
    required this.song,
    required this.artSize,
    required this.padding,
    this.desktop = false,
    this.roundArt = false,
    this.trailing = const [],
  });

  final Song song;
  final double artSize;
  final EdgeInsets padding;
  final bool desktop;
  final bool roundArt;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget art = Hero(
      tag: nowPlayingHeroTag,
      child: SizedBox(
        width: artSize,
        child: CoverArt(id: song.coverArt, seed: song.albumId, radius: 6, circle: roundArt),
      ),
    );
    if (desktop) {
      art = GestureDetector(
        onTap: () => openNowPlaying(context),
        child: MouseRegion(cursor: SystemMouseCursors.click, child: art),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        children: [
          art,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Link(
                  text: song.title,
                  style: theme.textTheme.titleSmall,
                  onTap: desktop && song.albumId != null ? () => openAlbum(context, song.albumId!) : null,
                ),
                _Subtitle(song: song, links: desktop),
                _ThinProgress(seekable: desktop),
              ],
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// Single-line text that underlines on hover when it has an [onTap].
class _Link extends StatefulWidget {
  const _Link({required this.text, this.style, this.onTap});

  final String text;
  final TextStyle? style;
  final VoidCallback? onTap;

  @override
  State<_Link> createState() => _LinkState();
}

class _LinkState extends State<_Link> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      widget.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style?.copyWith(decoration: _hover ? TextDecoration.underline : null),
    );
    if (widget.onTap == null) return text;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.onTap, child: text),
    );
  }
}

/// "Artist — Album" as one line that ellipsizes at its end. With [links],
/// each part opens its page and underlines on hover.
class _Subtitle extends StatefulWidget {
  const _Subtitle({required this.song, required this.links});

  final Song song;
  final bool links;

  @override
  State<_Subtitle> createState() => _SubtitleState();
}

class _SubtitleState extends State<_Subtitle> {
  final _artistTap = TapGestureRecognizer();
  final _albumTap = TapGestureRecognizer();
  TapGestureRecognizer? _hovered;

  @override
  void dispose() {
    _artistTap.dispose();
    _albumTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final theme = Theme.of(context);
    _artistTap.onTap = widget.links && song.artistId != null ? () => openArtist(context, song.artistId!) : null;
    _albumTap.onTap = widget.links && song.albumId != null ? () => openAlbum(context, song.albumId!) : null;

    TextSpan part(String text, TapGestureRecognizer tap) {
      if (tap.onTap == null) return TextSpan(text: text);
      return TextSpan(
        text: text,
        recognizer: tap,
        mouseCursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = tap),
        onExit: (_) => setState(() => _hovered = null),
        style: _hovered == tap ? const TextStyle(decoration: TextDecoration.underline) : null,
      );
    }

    final artist = song.artist;
    final album = song.album;
    return Text.rich(
      TextSpan(
        children: [
          if (artist != null) part(artist, _artistTap),
          if (artist != null && album != null) const TextSpan(text: ' — '),
          if (album != null) part(album, _albumTap),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// A thin, round-ended progress line under the track's text. When
/// [seekable], it thickens on hover and a click or horizontal drag seeks; the
/// drag position is held locally while scrubbing.
class _ThinProgress extends StatefulWidget {
  const _ThinProgress({required this.seekable});

  final bool seekable;

  @override
  State<_ThinProgress> createState() => _ThinProgressState();
}

class _ThinProgressState extends State<_ThinProgress> {
  bool _hover = false;

  /// Fraction of the track while scrubbing.
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    final color = Theme.of(context).colorScheme.primary;

    final bar = RepaintBoundary(
      child: StreamBuilder<Duration>(
        stream: p.position,
        builder: (context, snap) {
          final total = p.duration.inMilliseconds;
          final v = _drag ?? (total == 0 ? 0.0 : ((snap.data?.inMilliseconds ?? 0) / total).clamp(0.0, 1.0));
          return LinearProgressIndicator(
            value: v,
            minHeight: _hover || _drag != null ? 4 : 2,
            borderRadius: BorderRadius.circular(2),
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          );
        },
      ),
    );
    // Phones: a fixed gap above the line. Desktop: a taller hit area than the
    // line itself, so it's easy to grab.
    if (!widget.seekable) {
      return Padding(padding: const EdgeInsets.only(top: 4), child: bar);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double fraction(Offset local) => (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
        void seek(double f) => unawaited(guarded(context, () => p.seek(p.duration * f)));
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => seek(fraction(d.localPosition)),
            onHorizontalDragStart: (d) => setState(() => _drag = fraction(d.localPosition)),
            onHorizontalDragUpdate: (d) => setState(() => _drag = fraction(d.localPosition)),
            onHorizontalDragEnd: (_) {
              final f = _drag;
              if (f != null) seek(f);
              setState(() => _drag = null);
            },
            onHorizontalDragCancel: () => setState(() => _drag = null),
            child: SizedBox(height: 12, child: Center(child: bar)),
          ),
        );
      },
    );
  }
}
