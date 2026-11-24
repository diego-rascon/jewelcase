import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'art_colors.dart';
import 'layout.dart';

/// Scaffold for album / artist / playlist pages: a header with a big cover
/// and primary actions, followed by [slivers].
class DetailPage extends StatelessWidget {
  const DetailPage({
    super.key,
    required this.cover,
    this.tintCoverId,
    this.kicker,
    required this.title,
    this.subtitle,
    this.meta,
    required this.onPlay,
    this.onShuffle,
    this.actions = const [],
    required this.slivers,
  });

  final Widget cover;

  /// Cover art whose colors tint the page: a gradient behind the header, plus
  /// the Play button and [subtitle], which get the art's color as their
  /// theme's `primary`. Without it, the page stays neutral.
  final String? tintCoverId;

  /// Small all-caps label above the title (the artist page's "ARTIST").
  final String? kicker;
  final String title;
  final Widget? subtitle;
  final String? meta;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;
  final List<Widget> actions;
  final List<Widget> slivers;

  static const _tintDuration = Duration(milliseconds: 400);

  @override
  Widget build(BuildContext context) => ArtTinted(coverId: tintCoverId, builder: _build);

  Widget _build(BuildContext context, ColorScheme? art) {
    final theme = Theme.of(context);
    final wide = isWide(context);
    final pad = pagePadding(context);

    final neutral = theme.colorScheme;
    final accented = theme.copyWith(
      colorScheme: neutral.copyWith(
        primary: art?.primary ?? neutral.primary,
        onPrimary: art?.onPrimary ?? neutral.onPrimary,
      ),
    );
    Widget tinted(Widget child) => AnimatedTheme(data: accented, duration: _tintDuration, child: child);
    final glow = art?.primaryContainer.withValues(alpha: 0.7) ?? Colors.transparent;

    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: wide ? WrapAlignment.start : WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        tinted(
          FilledButton.icon(
            onPressed: onPlay,
            style: FilledButton.styleFrom(minimumSize: const Size(120, 48), shape: const StadiumBorder()),
            icon: const Icon(Icons.play_arrow_rounded, size: 26),
            label: const Text('Play', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        if (onShuffle != null)
          FilledButton.tonalIcon(
            onPressed: onShuffle,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48), shape: const StadiumBorder()),
            icon: const Icon(Icons.shuffle_rounded),
            label: const Text('Shuffle'),
          ),
        ...actions,
      ],
    );

    final text = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kicker != null) ...[
          Text(
            kicker!.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.6, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          title,
          textAlign: wide ? TextAlign.start : TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: (wide ? theme.textTheme.displaySmall : theme.textTheme.headlineMedium),
        ),
        if (subtitle != null) ...[const SizedBox(height: 6), tinted(subtitle!)],
        if (meta != null) ...[
          const SizedBox(height: 6),
          Text(meta!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 20),
        buttons,
      ],
    );

    final header = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(width: 232, child: _shadowed(cover)),
              const SizedBox(width: 32),
              Expanded(child: text),
            ],
          )
        : Column(
            children: [
              SizedBox(width: 240, child: _shadowed(cover)),
              const SizedBox(height: 24),
              text,
            ],
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // The gradient stays put while the page scrolls over it.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: wide ? 440 : 600,
            child: AnimatedContainer(
              duration: _tintDuration,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.5, 1],
                  colors: [
                    glow,
                    glow.withValues(alpha: glow.a * 0.35),
                    glow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                // Clear over the gradient; once content scrolls under it, the
                // gradient's top color, made opaque.
                backgroundColor: WidgetStateColor.resolveWith(
                  (states) => states.contains(WidgetState.scrolledUnder)
                      ? Color.alphaBlend(glow, neutral.surface)
                      : Colors.transparent,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 28),
                sliver: SliverToBoxAdapter(child: header),
              ),
              ...slivers,
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              const BottomInset(),
            ],
          ),
        ],
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
