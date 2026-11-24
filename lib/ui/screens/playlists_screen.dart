import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../state/playlists.dart';
import '../../state/session.dart';
import '../actions.dart';
import '../widgets/async_view.dart';
import '../widgets/layout.dart';
import '../widgets/media_cards.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  Future<void> _create() => createPlaylist(context);

  @override
  Widget build(BuildContext context) {
    final client = context.read<SessionController>().client;
    // Refetch whenever a playlist is created, edited or deleted anywhere.
    final revision = context.select<PlaylistsController, int>((p) => p.revision);
    final theme = Theme.of(context);
    final pad = pagePadding(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.showTitle
          ? null
          : FloatingActionButton(onPressed: _create, tooltip: 'New playlist', child: const Icon(Icons.add_rounded)),
      body: SafeArea(
        bottom: false,
        child: AsyncView<List<Playlist>>(
          deps: [revision],
          load: client.getPlaylists,
          builder: (context, lists, reload) => RefreshIndicator(
            onRefresh: reload,
            child: CustomScrollView(
              slivers: [
                if (widget.showTitle)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 24, pad, 20),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(child: Text('Playlists', style: theme.textTheme.headlineMedium)),
                          FilledButton.tonalIcon(
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('New playlist'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                // Favorite songs always comes first, so the grid is never empty.
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 32),
                  sliver: SliverLayoutBuilder(
                    builder: (context, c) => SliverGrid.builder(
                      gridDelegate: cardGrid(c.crossAxisExtent),
                      itemCount: lists.length + 1,
                      itemBuilder: (context, i) =>
                          i == 0 ? const FavoriteSongsCard() : PlaylistCard(playlist: lists[i - 1]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
