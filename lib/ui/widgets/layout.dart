import 'package:material_ui/material_ui.dart';

import '../theme.dart';

double pagePadding(BuildContext context) => isWide(context) ? 32 : 16;

/// Ends a scroll view with room for what floats over the bottom of the
/// content (the desktop player bar, passed down as `MediaQuery` padding), so
/// the last items can scroll clear of it. Use [bottomInset] for a box list's
/// own padding.
class BottomInset extends StatelessWidget {
  const BottomInset({super.key});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(child: SizedBox(height: bottomInset(context)));
}

double bottomInset(BuildContext context) => MediaQuery.paddingOf(context).bottom;

/// Grid that fits cards of roughly [targetWidth] (smaller on narrow screens)
/// and leaves room for two lines of text under the square artwork.
SliverGridDelegate cardGrid(double crossAxisExtent, {double? targetWidth, double textHeight = 52}) {
  const spacing = 20.0;
  targetWidth ??= crossAxisExtent < 500 ? 150 : 190;
  final count = ((crossAxisExtent + spacing) / (targetWidth + spacing)).floor().clamp(2, 12);
  final cell = (crossAxisExtent - spacing * (count - 1)) / count;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: count,
    crossAxisSpacing: spacing,
    mainAxisSpacing: 24,
    mainAxisExtent: cell + textHeight,
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Horizontally scrolling row of cards with arrow buttons on desktop.
class Shelf extends StatefulWidget {
  const Shelf({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.itemWidth = 170,
    this.height = 230,
    this.trailing,
  });

  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double itemWidth;
  final double height;
  final Widget? trailing;

  @override
  State<Shelf> createState() => _ShelfState();
}

class _ShelfState extends State<Shelf> {
  final _scroll = ScrollController();

  void _page(int dir) {
    final target = (_scroll.offset + dir * _scroll.position.viewportDimension * 0.8).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(target, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: SectionHeader(
            widget.title,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?widget.trailing,
                if (isWide(context)) ...[
                  IconButton(onPressed: () => _page(-1), icon: const Icon(Icons.chevron_left_rounded)),
                  IconButton(onPressed: () => _page(1), icon: const Icon(Icons.chevron_right_rounded)),
                ],
              ],
            ),
          ),
        ),
        SizedBox(
          height: widget.height,
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: pad),
            itemCount: widget.itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 18),
            itemBuilder: (context, i) => SizedBox(width: widget.itemWidth, child: widget.itemBuilder(context, i)),
          ),
        ),
      ],
    );
  }
}

/// "Favorites" toggle for filtering a library list down to starred items.
class FavoritesFilterChip extends StatelessWidget {
  const FavoritesFilterChip({super.key, required this.selected, required this.onSelected});

  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The default label and icon colors are too light on the selected fill.
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return FilterChip(
      // The label's glyphs sit below the center of its line box, so the heart
      // drops 1px to line up with the text optically.
      avatar: Transform.translate(
        offset: const Offset(0, 1),
        child: Icon(
          selected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: selected ? scheme.onPrimary : scheme.primary,
        ),
      ),
      label: const Text('Favorites'),
      labelStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: fg, fontWeight: selected ? FontWeight.w700 : null),
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected,
    );
  }
}
