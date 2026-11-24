import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'art_colors.dart';
import 'layout.dart';

/// Scaffold for album / artist / playlist pages: art-tinted header with a big
/// cover and primary actions, followed by [slivers].
class DetailPage extends StatelessWidget {
  const DetailPage({
    super.key,
    required this.coverId,
    required this.cover,
    this.kicker,
    required this.title,
    this.subtitle,
    this.meta,
    required this.onPlay,
    this.onShuffle,
    this.actions = const [],
    required this.slivers,
  });

  final String? coverId;
  final Widget cover;

  /// Small all-caps label above the title (the artist page's "ARTIST").
  final String? kicker;
  final String title;
  final Widget? subtitle;
  final String? meta;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;
  final List<Widget> actions;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = isWide(context);
    final pad = pagePadding(context);

    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: wide ? WrapAlignment.start : WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: onPlay,
          style: FilledButton.styleFrom(minimumSize: const Size(120, 48), shape: const StadiumBorder()),
          icon: const Icon(Icons.play_arrow_rounded, size: 26),
          label: const Text('Play', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
        if (subtitle != null) ...[const SizedBox(height: 6), subtitle!],
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
      body: ArtTinted(
        coverId: coverId,
        builder: (context, art) => CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Color.alphaBlend(
                (art?.primaryContainer ?? theme.colorScheme.surface).withValues(alpha: 0.35),
                theme.colorScheme.surface,
              ),
            ),
            SliverToBoxAdapter(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (art?.primaryContainer ?? theme.colorScheme.surface).withValues(alpha: 0.35),
                      theme.colorScheme.surface.withValues(alpha: 0),
                    ],
                  ),
                ),
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 28),
                child: header,
              ),
            ),
            ...slivers,
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
