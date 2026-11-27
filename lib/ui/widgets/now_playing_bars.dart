import 'dart:async';

import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/favorites.dart';
import '../actions.dart';
import '../navigation.dart';
import '../screens/now_playing_screen.dart';
import '../theme.dart';
import 'cover_art.dart';
import 'filled_icon.dart';
import 'frosted.dart';
import 'player_controls.dart';
import 'song_tile.dart';
import 'thin_slider.dart';

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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: PlayerBar.maxWidth),
              child: const PlayerBar(),
            ),
          ),
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

  /// Wide enough for every control plus the track panel at its full 560;
  /// past this the bar stays centered instead of stretching.
  static const maxWidth = 1200.0;

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
              child: IconButtonTheme(
                data: smallIconButtons,
                child: LayoutBuilder(builder: (context, constraints) => _barRow(context, song, constraints)),
              ),
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
        TransportControls(uniform: true, showModes: showModes),
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
                  FavoriteButton(id: song.id, kind: FavoriteKind.song),
                  MoreButton(actions: () => songActions(context, song)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const _QueueButton(),
        VolumeControl(width: showSlider ? 100 : null),
        IconButton(
          tooltip: 'Now playing',
          onPressed: () => openNowPlaying(context),
          icon: const Icon(LucideIcons.maximize2),
        ),
      ],
    );
  }
}

/// Toggles the queue sidebar, or opens the queue in Now Playing when the
/// window is too narrow for the sidebar.
class _QueueButton extends StatelessWidget {
  const _QueueButton();

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavController>();
    final fits = fitsQueueSidebar(context);
    final shown = fits && context.select<NavController, bool>((n) => n.queueOpen);
    return IconButton(
      tooltip: shown ? 'Hide queue' : 'Queue',
      isSelected: shown,
      onPressed: fits ? nav.toggleQueue : () => openNowPlaying(context, showQueue: true),
      icon: const Icon(LucideIcons.listMusic),
      style: IconButton.styleFrom(
        backgroundColor: shown ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12) : null,
      ),
    );
  }
}

/// Phone: floating card above the tab bar. Tap to expand, or drag it up and
/// the player follows the finger.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    final (song, playing) = context.select<PlayerController, (Song?, bool)>((p) => (p.current, p.playing));
    if (song == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: NowPlayingOpener(
        child: _FloatingCard(
          height: 62,
          child: IconButtonTheme(
            data: smallIconButtons,
            child: _TrackPanel(
              song: song,
              artSize: 46,
              padding: const EdgeInsets.fromLTRB(_FloatingCard.artInset, 8, 10, 8),
              trailing: [
                IconButton(
                  tooltip: playing ? 'Pause' : 'Play',
                  onPressed: p.togglePlay,
                  icon: FilledIcon(playing ? FilledIcons.pause : FilledIcons.play),
                ),
                IconButton(tooltip: 'Next', onPressed: p.next, icon: const FilledIcon(FilledIcons.skipForward)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The frosted, shadowed, rounded card both [PlayerBar] and [MiniPlayer]
/// float in.
class _FloatingCard extends StatelessWidget {
  const _FloatingCard({super.key, required this.height, required this.child, this.padding = EdgeInsets.zero});

  /// The cover's corner radius, the same as the song tiles' covers.
  static const artRadius = 6.0;

  /// How far the [MiniPlayer]'s cover sits in from the card's edge.
  static const artInset = 8.0;

  /// Concentric with the cover: its radius plus the gap around it, so the
  /// cover's corners follow the card's. Matches the app's other 14px cards.
  static const radius = BorderRadius.all(Radius.circular(artRadius + artInset));

  final double height;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: radius,
      boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8))],
    ),
    child: Frosted(
      borderRadius: radius,
      child: Container(height: height, padding: padding, child: child),
    ),
  );
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
    this.trailing = const [],
  });

  final Song song;
  final double artSize;
  final EdgeInsets padding;
  final bool desktop;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget art = Hero(
      tag: nowPlayingHeroTag,
      child: SizedBox(
        width: artSize,
        child: CoverArt(id: song.coverArt, seed: song.albumId, radius: _FloatingCard.artRadius),
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

/// The song's progress as a [ThinSlider] under the track's text. When
/// [seekable], a click or horizontal drag seeks.
class _ThinProgress extends StatelessWidget {
  const _ThinProgress({required this.seekable});

  final bool seekable;

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    final bar = RepaintBoundary(
      child: StreamBuilder<Duration>(
        stream: p.position,
        builder: (context, snap) {
          final total = p.duration;
          return ThinSlider(
            value: total == Duration.zero ? 0 : (snap.data ?? Duration.zero).inMilliseconds / total.inMilliseconds,
            onChangeEnd: seekable ? (f) => unawaited(guarded(context, () => p.seek(total * f))) : null,
          );
        },
      ),
    );
    // Phones: a fixed gap above the line. Desktop: the slider's taller hit
    // area leaves room around it.
    return seekable ? bar : Padding(padding: const EdgeInsets.only(top: 4), child: bar);
  }
}
