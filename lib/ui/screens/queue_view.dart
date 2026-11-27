import 'dart:async';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../actions.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/layout.dart';
import '../widgets/song_tile.dart';

/// The play queue: what's on now and what's up next. Drag to reorder, swipe
/// or ✕ to remove, tap to jump.
class QueueView extends StatelessWidget {
  const QueueView({super.key, this.foreground, this.controller, this.header, this.onClose});

  final Color? foreground;

  /// Side panels: puts a "Queue" title with a close button at the top.
  final VoidCallback? onClose;

  /// Scrolls along above the list, such as a sheet's drag handle.
  final Widget? header;

  /// The scroll controller, such as the one a [DraggableScrollableSheet] hands out.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    // `upNext` is cached by the controller, so a new list means the queue changed.
    final (current, upNext) = context.select<PlayerController, (Song?, List<(int, Song)>)>(
      (p) => (p.current, p.upNext),
    );
    final theme = Theme.of(context);
    final fg = foreground ?? theme.colorScheme.onSurface;
    final heading = theme.textTheme.titleMedium?.copyWith(color: fg);

    if (current == null) {
      return Center(
        child: Text('Nothing in the queue', style: theme.textTheme.bodyLarge?.copyWith(color: fg)),
      );
    }

    return CustomScrollView(
      controller: controller,
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        if (onClose != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Queue',
                      style: theme.textTheme.titleLarge?.copyWith(color: fg, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close queue',
                    color: fg.withValues(alpha: 0.7),
                    onPressed: onClose,
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverToBoxAdapter(child: Text('Now playing', style: heading)),
        ),
        SliverToBoxAdapter(
          child: _QueueRow(song: current, fg: fg, highlighted: true),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(child: Text('Up next', style: heading)),
                if (upNext.isNotEmpty)
                  Text(
                    plural(upNext.length, 'song'),
                    style: theme.textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.6)),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        if (upNext.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'End of queue',
                style: theme.textTheme.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.6)),
              ),
            ),
          )
        else
          SliverReorderableList(
            itemCount: upNext.length,
            onReorderItem: (from, to) {
              if (from == to) return;
              unawaited(guarded(context, () => p.move(upNext[from].$1, upNext[to].$1)));
            },
            itemBuilder: (context, i) {
              final (index, song) = upNext[i];
              return Dismissible(
                key: ValueKey('q$index-${song.id}'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => p.removeAt(index),
                background: Container(
                  alignment: Alignment.centerRight,
                  margin: const EdgeInsets.symmetric(horizontal: _QueueRow.inset),
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.trash2, color: theme.colorScheme.onErrorContainer),
                ),
                child: _QueueRow(
                  song: song,
                  fg: fg,
                  onTap: () => p.jumpTo(index),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Remove',
                        iconSize: IconSizes.small,
                        color: fg.withValues(alpha: 0.6),
                        onPressed: () => p.removeAt(index),
                        icon: const Icon(LucideIcons.x),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(LucideIcons.gripVertical, color: fg.withValues(alpha: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        SliverToBoxAdapter(child: SizedBox(height: 24 + bottomInset(context))),
      ],
    );
  }
}

class _QueueRow extends StatefulWidget {
  const _QueueRow({required this.song, required this.fg, this.onTap, this.trailing, this.highlighted = false});

  /// Keeps the rounded hover shape off the panel's edges. With the tile's own
  /// left padding, covers line up with the headings.
  static const inset = 8.0;

  final Song song;
  final Color fg;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool highlighted;

  @override
  State<_QueueRow> createState() => _QueueRowState();
}

class _QueueRowState extends State<_QueueRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final _QueueRow(:song, :fg, :onTap) = widget;
    final muted = TextStyle(color: fg.withValues(alpha: 0.65));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _QueueRow.inset),
      child: Material(
        type: MaterialType.transparency,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: ListTile(
            onTap: onTap,
            contentPadding: const EdgeInsets.only(left: 16 - _QueueRow.inset),
            leading: SongCover(song: song, hovered: _hover && onTap != null),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: fg,
                fontWeight: widget.highlighted ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            subtitle: Text(song.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
            trailing:
                widget.trailing ??
                // The up-next buttons carry their own padding; a bare duration
                // needs the same to line up with them.
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(formatDuration(song.duration), style: muted),
                ),
          ),
        ),
      ),
    );
  }
}
