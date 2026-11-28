import 'dart:async';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../audio/player_controller.dart';
import '../actions.dart';
import '../theme.dart';
import 'art_colors.dart';
import 'filled_icon.dart';
import 'layout.dart';
import 'player_controls.dart';

/// Scaffold for album / artist / playlist pages: a header with a big cover
/// and primary actions, followed by [slivers].
///
/// The header scrolls away with its art-tinted gradient. The top bar stays
/// clear over it and fades to the page background, with a bottom border, as
/// the content below the header reaches it.
class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.cover,
    this.tintCoverId,
    this.kicker,
    required this.title,
    this.subtitle,
    this.meta,
    required this.onPlay,
    this.actions = const [],
    this.menu,
    required this.slivers,
  });

  final Widget cover;

  /// Cover art whose colors tint the page: a gradient down the header
  /// ([ArtPalette.glow], so even colorless art casts one), plus
  /// the Play and Shuffle buttons, [actions] and [subtitle], which get the
  /// art's accent as their theme's `primary` (so a favorited star or a
  /// downloaded album shows it). Without it, the page stays neutral.
  final String? tintCoverId;

  /// Small all-caps label above the title (the artist page's "ARTIST").
  final String? kicker;
  final String title;
  final Widget? subtitle;

  /// A line of details under the subtitle, usually a `Text` of [joinDot]
  /// parts, set in muted body text.
  final Widget? meta;

  /// Starts playback; `shuffle` is the player's shuffle mode, which the
  /// Shuffle toggle next to Play sets. `null` disables Play.
  final Future<void> Function(bool shuffle)? onPlay;

  /// Icon buttons such as favorite and download: on the left of the button
  /// row on phones, after Play and Shuffle in the wide layout.
  final List<Widget> actions;

  /// The page's "more" button: in the top bar on phones, at the end of the
  /// button row in the wide layout.
  final Widget? menu;
  final List<Widget> slivers;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  static const _tintDuration = Duration(milliseconds: 400);

  /// The glow's strength at the top of the header, fading out below.
  static const _glowAlpha = 0.5;

  /// How far the page scrolls while the top bar fades in.
  static const _fadeDistance = 32.0;

  final _headerKey = GlobalKey();

  /// The top bar's opacity: 0 over the header, 1 once the content below it
  /// reaches the bar.
  final _barShade = ValueNotifier<double>(0);

  @override
  void dispose() {
    _barShade.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final header = _headerKey.currentContext?.size?.height;
    if (header == null) return false;
    final bar = MediaQuery.paddingOf(context).top + kToolbarHeight;
    // The header's bottom edge meets the bar's at `header - bar`.
    final start = header - bar - _fadeDistance;
    _barShade.value = ((n.metrics.pixels - start) / _fadeDistance).clamp(0.0, 1.0);
    return false;
  }

  void _play() {
    final shuffle = context.read<PlayerController>().shuffle;
    unawaited(guarded(context, () => widget.onPlay!(shuffle)));
  }

  @override
  Widget build(BuildContext context) => ArtTinted(coverId: widget.tintCoverId, builder: _build);

  Widget _build(BuildContext context, ArtPalette? art) {
    final theme = Theme.of(context);
    final wide = isWide(context);
    final pad = pagePadding(context);
    final barHeight = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final play = widget.onPlay == null ? null : _play;

    final neutral = theme.colorScheme;
    final accented = theme.copyWith(
      colorScheme: neutral.copyWith(
        primary: art?.accent?.primary ?? neutral.primary,
        onPrimary: art?.accent?.onPrimary ?? neutral.onPrimary,
      ),
    );
    Widget tinted(Widget child) => AnimatedTheme(data: accented, duration: _tintDuration, child: child);
    final glow = art?.glow ?? Colors.transparent;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.kicker != null) ...[
          Text(
            widget.kicker!.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.6, color: neutral.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          widget.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: wide ? theme.textTheme.displaySmall : theme.textTheme.headlineSmall,
        ),
        if (widget.subtitle != null) ...[const SizedBox(height: 6), tinted(widget.subtitle!)],
        if (widget.meta != null) ...[
          const SizedBox(height: 6),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium?.copyWith(color: neutral.onSurfaceVariant),
            child: widget.meta!,
          ),
        ],
      ],
    );

    final Widget header;
    if (wide) {
      header = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: 232, child: _shadowed(widget.cover)),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                info,
                const SizedBox(height: 20),
                IconButtonTheme(
                  data: smallIconButtons,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      tinted(
                        FilledButton.icon(
                          onPressed: play,
                          style: FilledButton.styleFrom(minimumSize: const Size(120, 48), shape: const StadiumBorder()),
                          icon: const FilledIcon(FilledIcons.play, size: IconSizes.medium),
                          label: const Text('Play', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      tinted(const _ShuffleToggle()),
                      ...widget.actions.map(tinted),
                      if (widget.menu != null) widget.menu!,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      final coverSize = ((MediaQuery.sizeOf(context).width - 2 * pad) * 0.8).clamp(0.0, 340.0);
      header = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: SizedBox(width: coverSize, child: _shadowed(widget.cover)),
          ),
          const SizedBox(height: 24),
          info,
          const SizedBox(height: 12),
          IconButtonTheme(
            data: smallIconButtons,
            child: Row(
              children: [
                ...widget.actions.map(tinted),
                const Spacer(),
                tinted(const _ShuffleToggle()),
                const SizedBox(width: 8),
                tinted(
                  IconButton.filled(
                    tooltip: 'Play',
                    onPressed: play,
                    iconSize: IconSizes.large,
                    style: IconButton.styleFrom(fixedSize: const Size.square(48)),
                    icon: const FilledIcon(FilledIcons.play),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<double>(
          valueListenable: _barShade,
          builder: (context, shade, _) => AppBar(
            backgroundColor: neutral.surface.withValues(alpha: shade),
            shape: Border(
              bottom: BorderSide(color: neutral.outlineVariant.withValues(alpha: shade)),
            ),
            actions: [
              if (!wide && widget.menu != null) ...[widget.menu!, const SizedBox(width: 4)],
            ],
          ),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          slivers: [
            // The gradient belongs to the header and scrolls away with it;
            // it starts under the clear top bar.
            SliverToBoxAdapter(
              child: AnimatedContainer(
                key: _headerKey,
                duration: _tintDuration,
                padding: EdgeInsets.fromLTRB(pad, barHeight + 8, pad, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.55, 1],
                    colors: [
                      glow.withValues(alpha: glow.a * _glowAlpha),
                      glow.withValues(alpha: glow.a * _glowAlpha * 0.35),
                      glow.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: header,
              ),
            ),
            ...widget.slivers,
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
            const BottomInset(),
          ],
        ),
      ),
    );
  }

  static Widget _shadowed(Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 32, offset: Offset(0, 12))],
    ),
    child: child,
  );
}

/// Toggles the player's shuffle mode, which Play then uses.
class _ShuffleToggle extends StatelessWidget {
  const _ShuffleToggle();

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final on = context.select<PlayerController, bool>((p) => p.shuffle);
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: on ? 'Shuffle on' : 'Shuffle off',
      isSelected: on,
      color: on ? scheme.primary : scheme.onSurfaceVariant,
      onPressed: () => unawaited(guarded(context, player.toggleShuffle)),
      icon: ModeIcon(icon: LucideIcons.shuffle, on: on, color: scheme.primary),
    );
  }
}

/// Download button for album and playlist pages, in the theme's `primary`
/// once downloaded, like a favorited star. Downloads aren't built yet, so
/// for now it does nothing and nothing is ever [downloaded].
class DownloadButton extends StatelessWidget {
  const DownloadButton({super.key, this.downloaded = false});

  final bool downloaded;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: downloaded ? 'Downloaded' : 'Download',
    color: downloaded ? Theme.of(context).colorScheme.primary : null,
    onPressed: () {},
    icon: Icon(downloaded ? LucideIcons.circleCheck : LucideIcons.download),
  );
}

/// Pads a sliver list to the page gutters.
class PagedSliver extends StatelessWidget {
  const PagedSliver({super.key, required this.sliver, this.top = 0});

  final Widget sliver;
  final double top;

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    return SliverPadding(padding: EdgeInsets.fromLTRB(pad - 10, top, pad - 10, 0), sliver: sliver);
  }
}
