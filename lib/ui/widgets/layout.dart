import 'dart:async';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'filled_icon.dart';

double pagePadding(BuildContext context) => isWide(context) ? 32 : 16;

/// Ends a scroll view with room for what floats over the bottom of the
/// content (the desktop player bar, or the phone mini player and tab bar,
/// passed down as `MediaQuery` padding), so
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
  const SectionHeader(this.title, {super.key, this.trailing, this.subtitle, this.onOpen});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Makes the title a link ("Albums ›") to the section's full page.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Text(title, style: theme.textTheme.headlineSmall);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onOpen == null)
                  heading
                else
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: onOpen,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        heading,
                        const SizedBox(width: 2),
                        Icon(
                          LucideIcons.chevronRight,
                          size: IconSizes.medium,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
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

/// Horizontally scrolling row of cards (or of any items: a column of song
/// rows, a stack of tiles) with arrow buttons on desktop.
class Shelf extends StatefulWidget {
  const Shelf({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.itemWidth = 170,
    this.height = 230,
    this.spacing = 18,
    this.itemInset = 0,
    this.trailing,
    this.onOpen,
  });

  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double itemWidth;

  /// `null` sizes the shelf to its tallest item. It then builds every item up
  /// front, so keep such shelves short.
  final double? height;
  final double spacing;

  /// Space the items leave at their own edges (song rows pad themselves by
  /// 10), taken off the shelf's padding so their content lines up with the title.
  final double itemInset;
  final Widget? trailing;

  /// See [SectionHeader.onOpen].
  final VoidCallback? onOpen;

  @override
  State<Shelf> createState() => _ShelfState();
}

/// Where a scroll heading for [projected] should settle so it lines up with
/// an item: the nearest multiple of [extent] (an item and its gap), within
/// [min]..[max]. The end stays reachable even when it isn't on a multiple.
double snapOffset(double projected, double extent, double min, double max) =>
    ((projected / extent).round() * extent).clamp(min, max);

/// Ends every fling or drag of a [Shelf] lined up with an item instead of
/// partway through one. A fling still travels as far as it would freely,
/// then eases into the nearest item.
class SnapToItemPhysics extends ScrollPhysics {
  const SnapToItemPhysics({required this.extent, super.parent});

  /// The distance from one item's start to the next one's.
  final double extent;

  @override
  SnapToItemPhysics applyTo(ScrollPhysics? ancestor) =>
      SnapToItemPhysics(extent: extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // Overscrolled (bouncing platforms): let the parent spring back first.
    if (position.outOfRange || extent <= 0) return super.createBallisticSimulation(position, velocity);
    final tolerance = toleranceFor(position);
    // Where the platform's own fling would stop.
    final free = super.createBallisticSimulation(position, velocity);
    final projected = free == null ? position.pixels : free.x(double.maxFinite);
    final target = snapOffset(projected, extent, position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: tolerance);
  }
}

class _ShelfState extends State<Shelf> {
  final _scroll = ScrollController();

  double get _extent => widget.itemWidth + widget.spacing;

  /// The desktop arrows: about a screenful, landing on an item.
  void _page(int dir) {
    final position = _scroll.position;
    final target = snapOffset(
      position.pixels + dir * position.viewportDimension * 0.8,
      _extent,
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    unawaited(_scroll.animateTo(target, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    final height = widget.height;
    final padding = EdgeInsets.symmetric(horizontal: pad - widget.itemInset);
    final physics = SnapToItemPhysics(extent: _extent);
    Widget item(BuildContext context, int i) =>
        SizedBox(width: widget.itemWidth, child: widget.itemBuilder(context, i));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: SectionHeader(
            widget.title,
            onOpen: widget.onOpen,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?widget.trailing,
                if (isWide(context)) ...[
                  IconButton(onPressed: () => _page(-1), icon: const Icon(LucideIcons.chevronLeft)),
                  IconButton(onPressed: () => _page(1), icon: const Icon(LucideIcons.chevronRight)),
                ],
              ],
            ),
          ),
        ),
        if (height == null)
          SingleChildScrollView(
            controller: _scroll,
            physics: physics,
            scrollDirection: Axis.horizontal,
            padding: padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < widget.itemCount; i++) ...[
                  if (i > 0) SizedBox(width: widget.spacing),
                  item(context, i),
                ],
              ],
            ),
          )
        else
          SizedBox(
            height: height,
            child: ListView.separated(
              controller: _scroll,
              physics: physics,
              scrollDirection: Axis.horizontal,
              padding: padding,
              itemCount: widget.itemCount,
              separatorBuilder: (_, _) => SizedBox(width: widget.spacing),
              itemBuilder: item,
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
      // The label's glyphs sit below the center of its line box, so the star
      // drops 1px to line up with the text optically.
      avatar: Transform.translate(
        offset: const Offset(0, 1),
        child: FilledIcon(FilledIcons.star, filled: selected, color: selected ? scheme.onPrimary : scheme.primary),
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
