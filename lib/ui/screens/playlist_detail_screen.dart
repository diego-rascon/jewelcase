import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/playlists.dart';
import '../../state/session.dart';
import '../actions.dart';
import '../format.dart';
import '../widgets/async_view.dart';
import '../widgets/cover_art.dart';
import '../widgets/detail_header.dart';
import '../widgets/song_tile.dart';

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlist});

  final Playlist playlist;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  /// Set while a removal is applied and the list reloaded: the server removes
  /// by position, so positions from a stale list would hit the wrong song.
  bool _editing = false;

  Future<void> _remove(String playlistId, int index, Future<void> Function() reload) async {
    final playlists = context.read<PlaylistsController>();
    setState(() => _editing = true);
    try {
      await guarded(context, () => playlists.removeSong(playlistId, index));
      if (mounted) await reload();
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = context.read<SessionController>().client;
    final playlists = context.read<PlaylistsController>();
    final player = context.read<PlayerController>();
    final theme = Theme.of(context);

    return AsyncView<Playlist>(
      frame: AsyncView.page,
      load: () => client.getPlaylist(widget.playlist.id),
      builder: (context, p, reload) {
        final songs = p.songs;

        Future<void> delete() async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Delete “${p.name}”?'),
              content: const Text('This removes the playlist from your server. Songs are not affected.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
              ],
            ),
          );
          if (ok != true || !context.mounted) return;
          final nav = Navigator.of(context);
          await guarded(context, () async {
            await playlists.delete(p.id);
            nav.pop();
          });
        }

        return DetailPage(
          coverId: p.coverArt,
          cover: CoverArt(id: p.coverArt, seed: p.id, radius: 12, icon: Icons.queue_music_rounded),
          kicker: 'Playlist',
          title: p.name,
          subtitle: p.comment == null || p.comment!.isEmpty
              ? null
              : Text(p.comment!, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          meta: joinDot([p.owner, plural(songs.length, 'song'), formatLongDuration(p.duration)]),
          onPlay: songs.isEmpty ? null : () => player.playSongs(songs),
          onShuffle: songs.isEmpty ? null : () => player.playSongs(songs, shuffle: true),
          actions: [
            MoreButton(
              actions: () => [
                MenuAction(
                  'Add to queue',
                  Icons.add_to_queue_rounded,
                  () => guarded(context, () => player.addToQueue(songs), success: 'Added to queue'),
                ),
                MenuAction('Delete playlist', Icons.delete_outline_rounded, delete),
              ],
            ),
          ],
          slivers: [
            if (songs.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.music_note_outlined,
                  title: 'This playlist is empty',
                  message: 'Use “Add to playlist…” on any song or album.',
                ),
              ),
            PagedSliver(
              sliver: SliverList.builder(
                itemCount: songs.length,
                itemBuilder: (context, i) => SongTile(
                  song: songs[i],
                  onTap: () => player.playSongs(songs, index: i),
                  extraActions: [
                    if (!_editing)
                      MenuAction(
                        'Remove from playlist',
                        Icons.remove_circle_outline_rounded,
                        () => _remove(p.id, i, reload),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
