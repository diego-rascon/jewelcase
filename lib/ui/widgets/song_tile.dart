import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/favorites.dart';
import '../actions.dart';
import '../format.dart';
import '../theme.dart';
import 'cover_art.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.id, required this.kind, this.size = 22, this.color});

  final String id;
  final FavoriteKind kind;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isFav = context.select<FavoritesController, bool>((f) => f.isFavorite(id));
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
      iconSize: size,
      onPressed: () => guarded(context, () => context.read<FavoritesController>().toggle(id, kind)),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(isFav),
          color: isFav ? scheme.primary : color,
        ),
      ),
    );
  }
}

/// Tracks which [SongTile] in a list is hovered, so its neighbors can hide
/// the separators they share with it. Wrap each list of tiles in one and give
/// every tile its [SongTile.index].
class SongListScope extends StatefulWidget {
  const SongListScope({super.key, required this.child});

  final Widget child;

  static ValueNotifier<int?>? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SongListHover>()?.hovered;

  @override
  State<SongListScope> createState() => _SongListScopeState();
}

class _SongListScopeState extends State<SongListScope> {
  final _hovered = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SongListHover(hovered: _hovered, child: widget.child);
}

class _SongListHover extends InheritedWidget {
  const _SongListHover({required this.hovered, required super.child});

  final ValueNotifier<int?> hovered;

  @override
  bool updateShouldNotify(_SongListHover oldWidget) => hovered != oldWidget.hovered;
}

/// The column layout shared by [SongTile] and [SongListHeader], so the header
/// lines up with the rows. The artist, album, favorite and duration columns
/// only show on wide layouts.
class _SongRow extends StatelessWidget {
  const _SongRow({
    required this.wide,
    required this.leading,
    required this.title,
    this.artist,
    required this.album,
    required this.favorite,
    required this.duration,
    required this.more,
  });

  final bool wide;
  final Widget leading;
  final Widget title;
  final Widget? artist;
  final Widget? album;
  final Widget favorite;
  final Widget duration;
  final Widget more;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      leading,
      const SizedBox(width: 14),
      Expanded(flex: wide && artist != null ? 4 : 5, child: title),
      if (wide && artist != null) ...[const SizedBox(width: 16), Expanded(flex: 3, child: artist!)],
      if (wide && album != null) ...[const SizedBox(width: 16), Expanded(flex: 3, child: album!)],
      if (wide) favorite,
      if (wide) ...[SizedBox(width: 52, child: duration), const SizedBox(width: 12)],
      more,
    ],
  );
}

/// Column headings for a list of [SongTile]s. Tapping a column sorts by it:
/// ascending, then descending, then back to the list's own order.
class SongListHeader extends StatelessWidget {
  const SongListHeader({
    super.key,
    required this.sort,
    required this.onSort,
    this.showCover = true,
    this.showAlbum = true,
  });

  final SongSort? sort;
  final ValueChanged<SongSort?> onSort;

  /// Match the [SongTile]s below.
  final bool showCover;
  final bool showAlbum;

  @override
  Widget build(BuildContext context) {
    Widget column(String label, SongSortField field, {IconData? icon, bool end = false}) =>
        _SortButton(label: label, icon: icon, field: field, sort: sort, onSort: onSort, end: end);
    // Invisible stand-ins that take the same space as the rows' buttons.
    Widget placeholder(IconData icon, {double? size}) => Visibility.maintain(
      visible: false,
      child: IconButton(iconSize: size, onPressed: null, icon: Icon(icon)),
    );

    final wide = isWide(context);
    Widget start(Widget child) => Align(alignment: Alignment.centerLeft, child: child);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
      child: _SongRow(
        wide: wide,
        leading: SizedBox(width: showCover ? 44 : 32),
        // Narrow rows stack the artist under the title, so both headings share one cell.
        title: wide
            ? start(column('Title', SongSortField.title))
            : Row(
                children: [
                  column('Title', SongSortField.title),
                  const SizedBox(width: 20),
                  column('Artist', SongSortField.artist),
                ],
              ),
        artist: start(column('Artist', SongSortField.artist)),
        album: showAlbum ? start(column('Album', SongSortField.album)) : null,
        favorite: placeholder(Icons.favorite_border_rounded, size: 18),
        duration: Align(
          alignment: Alignment.centerRight,
          child: column('Duration', SongSortField.duration, icon: Icons.schedule_rounded, end: true),
        ),
        more: placeholder(Icons.more_horiz_rounded),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.field,
    required this.sort,
    required this.onSort,
    this.icon,
    this.end = false,
  });

  final String label;
  final SongSortField field;
  final SongSort? sort;
  final ValueChanged<SongSort?> onSort;

  /// Shown instead of [label], which then only appears as the tooltip.
  final IconData? icon;

  /// Right-aligned column: the arrow goes before the label.
  final bool end;

  SongSort? get _next => sort?.field != field
      ? (field: field, descending: false)
      : !sort!.descending
      ? (field: field, descending: true)
      : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = sort?.field == field;
    final color = active ? scheme.onSurface : scheme.onSurfaceVariant;
    final arrow = active
        ? Icon(sort!.descending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 14, color: color)
        : null;
    final content = icon != null
        ? Icon(icon, size: 16, color: color)
        : Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.4,
            ),
          );
    return Tooltip(
      message: 'Sort by ${label.toLowerCase()}',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onSort(_next),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (end && arrow != null) ...[arrow, const SizedBox(width: 4)],
              content,
              if (!end && arrow != null) ...[const SizedBox(width: 4), arrow],
            ],
          ),
        ),
      ),
    );
  }
}

/// One row in a track list. Shows the track number (or artwork), title,
/// artist, and on wide screens the album and duration columns.
class SongTile extends StatefulWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.index,
    this.startsSection = false,
    this.number,
    this.showCover = true,
    this.showAlbum = true,
    this.showArtist = true,
    this.artistColumn = false,
    this.extraActions = const [],
  });

  final Song song;
  final VoidCallback onTap;

  /// Position in the enclosing [SongListScope]. Rows draw a separator below
  /// themselves; the first row ([index] 0, or [startsSection]) also draws one
  /// above. Separators touching the hovered row are hidden.
  final int? index;
  final bool startsSection;
  final int? number;
  final bool showCover;
  final bool showAlbum;
  final bool showArtist;

  /// On wide layouts, show the artist in its own column instead of under the
  /// title. Set it on lists with a [SongListHeader], so the row matches the
  /// header's columns.
  final bool artistColumn;
  final List<MenuAction> extraActions;

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  bool _hover = false;
  ValueNotifier<int?>? _scope;

  void _setHover(bool hover) {
    setState(() => _hover = hover);
    final scope = _scope;
    final index = widget.index;
    if (scope == null || index == null) return;
    if (hover) {
      scope.value = index;
    } else if (scope.value == index) {
      scope.value = null;
    }
  }

  @override
  void dispose() {
    if (_hover && _scope?.value == widget.index) _scope?.value = null;
    super.dispose();
  }

  /// Paints the hairline separators around [child], aligned with the content.
  Widget _separators(Color color, Widget child) {
    final index = widget.index;
    final scope = _scope;
    Widget paint(int? hovered) {
      final selfHovered = _hover || (index != null && hovered == index);
      final drawTop = index == 0 || widget.startsSection;
      final hideBottom = selfHovered || (index != null && hovered == index + 1);
      BorderSide side(bool hidden) => BorderSide(color: hidden ? Colors.transparent : color);
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: drawTop ? side(selfHovered) : BorderSide.none, bottom: side(hideBottom)),
        ),
        child: child,
      );
    }

    if (scope == null) return paint(null);
    return ValueListenableBuilder<int?>(valueListenable: scope, builder: (context, hovered, _) => paint(hovered));
  }

  @override
  Widget build(BuildContext context) {
    _scope = SongListScope._of(context);
    final song = widget.song;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final wide = isWide(context);
    final isCurrent = context.select<PlayerController, bool>((p) => p.current?.id == song.id);
    final isFav = context.select<FavoritesController, bool>((f) => f.isFavorite(song.id));
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    List<MenuAction> actions() => songActions(context, song, extra: widget.extraActions);
    final artistColumn = wide && widget.artistColumn;
    final artist = widget.showArtist ? song.artist : null;

    Widget leading;
    if (widget.showCover) {
      leading = SizedBox(
        width: 44,
        child: Stack(
          children: [
            CoverArt(id: song.coverArt, seed: song.albumId, radius: 6),
            if (isCurrent)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.graphic_eq_rounded, color: scheme.primary),
                ),
              ),
          ],
        ),
      );
    } else {
      leading = SizedBox(
        width: 32,
        child: Center(
          child: isCurrent
              ? Icon(Icons.graphic_eq_rounded, color: scheme.primary, size: 20)
              : _hover
              ? const Icon(Icons.play_arrow_rounded, size: 20)
              : Text('${widget.number ?? song.track ?? ''}', style: muted),
        ),
      );
    }

    return ContextMenuRegion(
      actions: actions,
      child: MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: Material(
          color: _hover ? scheme.onSurface.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _separators(
                scheme.outlineVariant.withValues(alpha: 0.3),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _SongRow(
                    wide: wide,
                    leading: leading,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isCurrent ? scheme.primary : null,
                          ),
                        ),
                        if (!artistColumn && artist != null)
                          Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                      ],
                    ),
                    artist: artistColumn
                        ? Text(artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: muted)
                        : null,
                    album: widget.showAlbum
                        ? Text(song.album ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: muted)
                        : null,
                    favorite: Opacity(
                      opacity: _hover || isFav ? 1 : 0,
                      child: FavoriteButton(id: song.id, kind: FavoriteKind.song, size: 18),
                    ),
                    duration: Text(formatDuration(song.duration), style: muted, textAlign: TextAlign.right),
                    more: MoreButton(actions: actions),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
