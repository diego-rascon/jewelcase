import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/favorites.dart';
import '../actions.dart';
import '../theme.dart';
import '../widgets/art_colors.dart';
import '../widgets/cover_art.dart';
import '../widgets/layout.dart';
import '../widgets/player_controls.dart';
import '../widgets/side_panel.dart';
import '../widgets/song_tile.dart';
import 'queue_view.dart';

const nowPlayingHeroTag = 'now-playing-art';

const _queuePanelWidth = 380.0;

void openNowPlaying(BuildContext context, {bool showQueue = false}) {
  unawaited(Navigator.of(context, rootNavigator: true).push(_NowPlayingRoute(showQueue: showQueue)));
}

/// Slides Now Playing up over the app. A drag can drive the slide directly
/// (see [_SlideDrag]), so the player follows the finger.
///
/// Opened from the mini player ([origin] and [collapsed] given), it grows out
/// of the mini player on phones instead (see [_RiseFromMiniPlayer]).
class _NowPlayingRoute extends PageRoute<void> {
  _NowPlayingRoute({required this.showQueue, this.origin, this.collapsed});

  final bool showQueue;

  /// Where the mini player sits on screen, and the mini player itself.
  final Rect? origin;
  final Widget? collapsed;

  /// The slide's position: 0 is closed, 1 is fully up.
  AnimationController get slide => controller!;

  /// Settles the slide with a curve; a drag moves it linearly instead.
  CurvedAnimation? _curved;

  bool _risesFromMiniPlayer(BuildContext context) => origin != null && collapsed != null && !isWide(context);

  /// How far the page's top edge travels between closed and open, so a drag
  /// can move it 1:1 with the finger.
  double travel(BuildContext context) =>
      _risesFromMiniPlayer(context) ? origin!.top : MediaQuery.sizeOf(context).height;

  /// The hero controller puts a new page offstage for its first frame, to
  /// measure where its heroes land. Rising from the mini player has no hero,
  /// and the mini player hides while the page covers it, so that frame would
  /// blink the mini player away.
  @override
  set offstage(bool value) => super.offstage = value && origin == null;

  @override
  void dispose() {
    _curved?.dispose();
    super.dispose();
  }

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      NowPlayingScreen(initiallyShowQueue: showQueue);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // A drag moves the page 1:1 with the finger, and settles it with its own curve.
    final progress = navigator!.userGestureInProgress
        ? animation
        : _curved ??= CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    if (_risesFromMiniPlayer(context)) {
      return _RiseFromMiniPlayer(progress: progress, origin: origin!, collapsed: collapsed!, child: child);
    }
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(progress),
      child: child,
    );
  }
}

/// Phones: Now Playing grows out of the mini player. The page rises from the
/// mini player's top edge, carrying a copy of the mini player, and widens from
/// its width to the screen's. The copy fades out as the player fades in, and
/// the app behind dims.
class _RiseFromMiniPlayer extends StatelessWidget {
  const _RiseFromMiniPlayer({
    required this.progress,
    required this.origin,
    required this.collapsed,
    required this.child,
  });

  final Animation<double> progress;
  final Rect origin;
  final Widget collapsed;
  final Widget child;

  static const _pageFade = Interval(0, 0.35);
  static const _miniPlayerFade = Interval(0.05, 0.3);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final miniPlayer = IgnorePointer(child: ExcludeSemantics(child: collapsed));
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, page) {
        final t = progress.value;
        final top = origin.top * (1 - t);
        final left = origin.left * (1 - t);
        final right = size.width - (size.width - origin.right) * (1 - t);
        final radius = Radius.circular(_cardRadius * (1 - t));
        final miniPlayerOpacity = 1 - _miniPlayerFade.transform(t);
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.5 * t)),
            ),
            // The page keeps its full size, so it never lays out again; the
            // clip narrows it to the mini player's width.
            Transform.translate(
              offset: Offset(0, top),
              child: ClipRRect(
                clipper: _RRectClipper(
                  RRect.fromLTRBAndCorners(left, 0, right, size.height, topLeft: radius, topRight: radius),
                ),
                clipBehavior: t < 1 ? Clip.antiAlias : Clip.none,
                child: Opacity(opacity: _pageFade.transform(t), child: page),
              ),
            ),
            if (miniPlayerOpacity > 0)
              Positioned(
                left: left,
                top: top,
                width: right - left,
                height: origin.height,
                child: Opacity(opacity: miniPlayerOpacity, child: miniPlayer),
              ),
          ],
        );
      },
    );
  }
}

/// The mini player card's corner radius, which the rising page starts with.
const _cardRadius = 14.0;

class _RRectClipper extends CustomClipper<RRect> {
  const _RRectClipper(this.rrect);

  final RRect rrect;

  @override
  RRect getClip(Size size) => rrect;

  @override
  bool shouldReclip(_RRectClipper oldClipper) => oldClipper.rrect != rrect;
}

/// A vertical drag that moves Now Playing's slide with the finger, then
/// settles it fully open or closed (popping the route) on release.
class _SlideDrag {
  _SlideDrag._(this._route, this._height) : _navigator = _route.navigator! {
    _navigator.didStartUserGesture();
  }

  /// Pushes Now Playing at its closed position, for a drag up from the mini
  /// player.
  factory _SlideDrag.open(BuildContext context, _NowPlayingRoute route) {
    unawaited(Navigator.of(context, rootNavigator: true).push(route));
    // Take over from the push animation, which started on push.
    route.slide.value = _minSlide;
    return _SlideDrag._(route, route.travel(context));
  }

  /// Takes hold of the open Now Playing page that [context] is in, if any.
  static _SlideDrag? close(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route is! _NowPlayingRoute || !route.isCurrent) return null;
    return _SlideDrag._(route, route.travel(context));
  }

  /// The lowest a drag takes the slide. Never exactly 0: popping a route
  /// that's already dismissed changes no status, so it would never be removed.
  static const _minSlide = 0.001;

  final _NowPlayingRoute _route;
  final NavigatorState _navigator;
  final double _height;

  void update(DragUpdateDetails d) =>
      _route.slide.value = (_route.slide.value - d.primaryDelta! / _height).clamp(_minSlide, 1.0);

  /// Settles open on a fling up or past halfway, closed otherwise.
  void end(double velocity) {
    final slide = _route.slide;
    final open = velocity.abs() > 500 ? velocity < 0 : slide.value > 0.5;
    final duration = Duration(milliseconds: (350 * (open ? 1 - slide.value : slide.value)).round());
    if (!open && _route.isCurrent) _navigator.pop();
    final settle = open
        ? slide.animateTo(1, duration: duration, curve: Curves.easeOutCubic)
        : slide.animateBack(0, duration: duration, curve: Curves.easeOutCubic);
    // Ending the gesture once settled lets hero flights finish where they landed.
    settle.whenCompleteOrCancel(_navigator.didStopUserGesture);
  }
}

/// The mini player: opens Now Playing when [child] is tapped, or follows a
/// drag up so the player grows out of it under the finger.
///
/// The player draws its own copy of [child] while it rises, so [child] hides
/// until the player has closed again, and must stay current by itself (it's
/// built once more inside the player, from the same widget).
class NowPlayingOpener extends StatefulWidget {
  const NowPlayingOpener({super.key, required this.child});

  final Widget child;

  @override
  State<NowPlayingOpener> createState() => _NowPlayingOpenerState();
}

class _NowPlayingOpenerState extends State<NowPlayingOpener> {
  _SlideDrag? _drag;

  /// The player this opened, until it has closed again.
  _NowPlayingRoute? _route;

  @override
  void dispose() {
    _route?.slide.removeStatusListener(_onSlide);
    super.dispose();
  }

  _NowPlayingRoute _newRoute() {
    final box = context.findRenderObject()! as RenderBox;
    final route = _NowPlayingRoute(
      showQueue: false,
      origin: box.localToGlobal(Offset.zero) & box.size,
      collapsed: widget.child,
    );
    _route?.slide.removeStatusListener(_onSlide);
    setState(() => _route = route);
    return route;
  }

  void _open() {
    final route = _newRoute();
    unawaited(Navigator.of(context, rootNavigator: true).push(route));
    route.slide.addStatusListener(_onSlide);
  }

  void _startDrag() {
    final route = _newRoute();
    _drag = _SlideDrag.open(context, route);
    route.slide.addStatusListener(_onSlide);
  }

  void _onSlide(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    _route?.slide.removeStatusListener(_onSlide);
    if (mounted) setState(() => _route = null);
  }

  void _end(double velocity) {
    _drag?.end(velocity);
    _drag = null;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _open,
    onVerticalDragUpdate: (d) {
      // Only a drag up opens the player; one that starts downwards is ignored.
      if (_drag == null && d.primaryDelta! < 0) _startDrag();
      _drag?.update(d);
    },
    onVerticalDragEnd: (d) => _end(d.primaryVelocity ?? 0),
    onVerticalDragCancel: () => _end(0),
    child: Opacity(opacity: _route == null ? 1 : 0, child: widget.child),
  );
}

/// Full-screen player over a blurred, darkened copy of the album art, with
/// the queue sheet and accents tinted from the art's colors.
///
/// Both layouts stack the art, the title (with the favorite button), the
/// controls and a row of buttons (lyrics, queue, more) in one centered column. The queue button opens a
/// floating side panel in the wide layout, and a sheet on phones, which can
/// also be dragged up from that row.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key, this.initiallyShowQueue = false});

  final bool initiallyShowQueue;

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  /// Whether the queue is open: the side panel (wide) or the sheet (phones).
  /// On phones it follows the sheet, so it's true while the sheet is partly up.
  late bool _showQueue = widget.initiallyShowQueue;

  final _sheet = DraggableScrollableController();

  /// Phones: a drag down that's sliding the whole player away.
  _SlideDrag? _closeDrag;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_onSheetMoved);
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _onSheetMoved() {
    final open = _sheet.size > 0.001;
    if (open != _showQueue) setState(() => _showQueue = open);
  }

  void _setQueue(bool show) {
    if (isWide(context)) {
      setState(() => _showQueue = show);
    } else if (_sheet.isAttached) {
      unawaited(_sheet.animateTo(show ? 1 : 0, duration: SidePanel.duration, curve: Curves.easeOutCubic));
    }
  }

  /// Drags the sheet by the handle at the bottom of the player.
  void _dragSheet(DragUpdateDetails d, double height) {
    if (_sheet.isAttached) _sheet.jumpTo((_sheet.size - d.primaryDelta! / height).clamp(0.0, 1.0));
  }

  void _settleSheet(DragEndDetails d) {
    if (!_sheet.isAttached) return;
    final v = d.primaryVelocity ?? 0;
    _setQueue(v.abs() > 300 ? v < 0 : _sheet.size > 0.4);
  }

  @override
  Widget build(BuildContext context) {
    final song = context.select<PlayerController, Song?>((p) => p.current);
    if (song == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold();
    }
    final wide = isWide(context);

    return PopScope(
      // Back closes the queue sheet before the player.
      canPop: wide || !_showQueue,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setQueue(false);
      },
      child: ArtTinted(
        coverId: song.coverArt,
        builder: (context, art) {
          final accent = art?.accent;
          final base = accent?.primaryContainer ?? const Color(0xFF2C2C2E);

          return Theme(
            data: Theme.of(context).copyWith(
              // Art without real color keeps to grays, with white accents.
              colorScheme:
                  accent ??
                  ColorScheme.fromSeed(
                    seedColor: base,
                    brightness: Brightness.dark,
                    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
                  ),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  // The artwork, blurred to fill the screen, cross-fading
                  // between songs. Its own layer, so the expensive blur is only
                  // painted when the art changes. Clamped edges keep the blur
                  // from fading to black at the sides.
                  RepaintBoundary(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.clamp),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 600),
                        layoutBuilder: (current, previous) =>
                            Stack(fit: StackFit.expand, children: [...previous, ?current]),
                        child: CoverArt(
                          key: ValueKey(song.coverArt ?? song.albumId),
                          id: song.coverArt,
                          seed: song.albumId,
                          size: 150,
                          radius: 0,
                        ),
                      ),
                    ),
                  ),
                  // Darkens the art so white text and controls stay legible,
                  // a little more towards the controls at the bottom.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x66000000), Color(0x99000000)],
                      ),
                    ),
                  ),
                  // Phones: the handle and the queue sheet reach the bottom
                  // edge and pad for the home indicator themselves.
                  SafeArea(
                    bottom: wide,
                    child: wide
                        ? _buildWide(song)
                        : _buildNarrow(song, sheetColor: Color.lerp(base, Colors.black, 0.6)!),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWide(Song song) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Close',
                  iconSize: IconSizes.large,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.chevronDown),
                ),
              ),
            ),
            Expanded(
              child: _PlayerPanel(song: song, wide: true, actions: _actions(song)),
            ),
          ],
        ),
      ),
      SidePanel(
        open: _showQueue,
        width: _queuePanelWidth,
        child: _QueuePanel(onClose: () => _setQueue(false)),
      ),
    ],
  );

  /// The buttons under the controls.
  Widget _actions(Song song) =>
      _ActionRow(song: song, queueShown: _showQueue, onToggleQueue: () => _setQueue(!_showQueue));

  void _endCloseDrag(double velocity) {
    _closeDrag?.end(velocity);
    _closeDrag = null;
  }

  // Dragging down anywhere outside the queue sheet (which takes its own drags)
  // slides the player away with the finger.
  Widget _buildNarrow(Song song, {required Color sheetColor}) => GestureDetector(
    onVerticalDragStart: (_) => _closeDrag = _SlideDrag.close(context),
    onVerticalDragUpdate: (d) => _closeDrag?.update(d),
    onVerticalDragEnd: (d) => _endCloseDrag(d.primaryVelocity ?? 0),
    onVerticalDragCancel: () => _endCloseDrag(0),
    child: _buildNarrowBody(song, sheetColor: sheetColor),
  );

  Widget _buildNarrowBody(Song song, {required Color sheetColor}) => Column(
    children: [
      // Takes no drags of its own, so dragging it down slides the player away.
      _Grabber(label: 'Close', height: 40, onTap: () => Navigator.of(context).pop()),
      Expanded(
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  // The sheet covers the art, so it mustn't fly from there on close.
                  Expanded(
                    child: HeroMode(
                      enabled: !_showQueue,
                      child: _PlayerPanel(
                        song: song,
                        wide: false,
                        // Dragging the button row up pulls the queue sheet
                        // with it; its buttons still take taps.
                        actions: GestureDetector(
                          onVerticalDragUpdate: (d) => _dragSheet(d, c.maxHeight),
                          onVerticalDragEnd: _settleSheet,
                          child: _actions(song),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: bottomInset(context)),
                ],
              ),
              DraggableScrollableSheet(
                controller: _sheet,
                // Only read when the sheet is first built; it keeps its size after.
                initialChildSize: _showQueue ? 1 : 0,
                minChildSize: 0,
                snap: true,
                builder: (context, scroll) => Material(
                  color: sheetColor,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  clipBehavior: Clip.antiAlias,
                  // Dragging the list down from its top closes the sheet.
                  child: QueueView(
                    foreground: Colors.white,
                    controller: scroll,
                    header: _Grabber(label: 'Hide queue', onTap: () => _setQueue(false)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Lyrics · queue · more, spread under the controls so the outer buttons line
/// up with shuffle and repeat.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.song, required this.queueShown, required this.onToggleQueue});

  final Song song;
  final bool queueShown;
  final VoidCallback onToggleQueue;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Lyrics aren't built yet, so for now it does nothing.
      IconButton(
        tooltip: 'Lyrics',
        iconSize: IconSizes.large,
        color: Colors.white70,
        onPressed: () {},
        icon: const Icon(LucideIcons.micVocal),
      ),
      IconButton(
        tooltip: queueShown ? 'Hide queue' : 'Show queue',
        isSelected: queueShown,
        iconSize: IconSizes.large,
        color: Colors.white70,
        onPressed: onToggleQueue,
        icon: const Icon(LucideIcons.listMusic),
        selectedIcon: const Icon(LucideIcons.listMusic, color: Colors.white),
        style: IconButton.styleFrom(backgroundColor: queueShown ? Colors.white24 : null),
      ),
      MoreButton(size: IconSizes.large, color: Colors.white70, actions: () => songActions(context, song)),
    ],
  );
}

/// The wide layout's queue: a floating card along the right edge.
class _QueuePanel extends StatelessWidget {
  const _QueuePanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white10),
    ),
    clipBehavior: Clip.antiAlias,
    child: QueueView(foreground: Colors.white, onClose: onClose),
  );
}

/// A full-width handle with a pill: closes the player or the queue sheet.
class _Grabber extends StatelessWidget {
  const _Grabber({required this.label, required this.onTap, this.height = 32});

  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: const Center(child: _Pill()),
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill();

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 5,
    decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(3)),
  );
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.song, required this.wide, required this.actions});

  final Song song;
  final bool wide;

  /// The row of buttons under the controls.
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Phones and tablets have hardware volume buttons.
    final showVolume = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => false,
      TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => true,
    };

    return LayoutBuilder(
      builder: (context, c) {
        // Art takes what's left after the controls below it, capped for taste.
        final controlsHeight = showVolume ? 402 : 334;
        final artSize = (c.maxHeight - controlsHeight)
            .clamp(160.0, wide ? 520.0 : 440.0)
            .clamp(0.0, c.maxWidth - 48)
            .toDouble();
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: artSize < 360 ? 360 : artSize),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: nowPlayingHeroTag,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(song.coverArt ?? song.id),
                        width: artSize,
                        height: artSize,
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
                      // Lines up with repeat below it.
                      FavoriteButton(
                        id: song.id,
                        kind: FavoriteKind.song,
                        size: IconSizes.large,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SeekBar(color: Colors.white),
                  const SizedBox(height: 16),
                  const TransportControls(color: Colors.white, spread: true),
                  if (showVolume) ...[const SizedBox(height: 20), const VolumeBar(color: Colors.white)],
                  const SizedBox(height: 24),
                  actions,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
