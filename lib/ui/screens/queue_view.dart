import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../format.dart';
import '../widgets/cover_art.dart';

/// The play queue: what's on now and what's up next. Drag to reorder (when
/// not shuffling), swipe or ✕ to remove, tap to jump.
class QueueView extends StatelessWidget {
  const QueueView({super.key, this.foreground});

  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    // `upNext` is cached by the controller, so a new list means the queue changed.
    final (current, upNext, shuffle) = context.select<PlayerController, (Song?, List<(int, Song)>, bool)>(
      (p) => (p.current, p.upNext, p.shuffle),
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
      slivers: [
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
              unawaited(p.move(upNext[from].$1, upNext[to].$1));
            },
            itemBuilder: (context, i) {
              final (index, song) = upNext[i];
              return Dismissible(
                key: ValueKey('q$index-${song.id}'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => p.removeAt(index),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  color: theme.colorScheme.errorContainer,
                  child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onErrorContainer),
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
                        iconSize: 18,
                        color: fg.withValues(alpha: 0.6),
                        onPressed: () => p.removeAt(index),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      if (!shuffle)
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.drag_indicator_rounded, color: fg.withValues(alpha: 0.5)),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.song, required this.fg, this.onTap, this.trailing, this.highlighted = false});

  final Song song;
  final Color fg;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        leading: SizedBox(
          width: 44,
          child: CoverArt(id: song.coverArt, seed: song.albumId, radius: 6),
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: fg,
            fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          song.artist ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: fg.withValues(alpha: 0.65)),
        ),
        trailing: trailing ?? Text(formatDuration(song.duration), style: TextStyle(color: fg.withValues(alpha: 0.65))),
      ),
    );
  }
}
