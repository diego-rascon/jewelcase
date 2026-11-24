import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/session.dart';
import '../actions.dart';
import '../widgets/async_view.dart';
import '../widgets/layout.dart';
import '../widgets/media_cards.dart';
import 'settings_screen.dart';

typedef _HomeData = ({
  List<Album> recent,
  List<Album> newest,
  List<Album> frequent,
  List<Album> random,
  List<Album> starred,
});

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Future<_HomeData> _load(SessionController session) async {
    final c = session.client;
    Future<List<Album>> shelf(AlbumSort sort) => c.getAlbumList(sort, size: 20, musicFolderId: session.libraryId);
    final r = await Future.wait([
      shelf(AlbumSort.recent),
      shelf(AlbumSort.newest),
      shelf(AlbumSort.frequent),
      shelf(AlbumSort.random),
      shelf(AlbumSort.starred),
    ]);
    return (recent: r[0], newest: r[1], frequent: r[2], random: r[3], starred: r[4]);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final theme = Theme.of(context);
    final pad = pagePadding(context);
    final player = context.read<PlayerController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: AsyncView<_HomeData>(
          deps: [session.libraryId],
          load: () => _load(session),
          builder: (context, data, reload) => RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: EdgeInsets.only(bottom: 32 + bottomInset(context)),
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 24, pad, 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(_greeting(), style: theme.textTheme.headlineMedium)),
                      IconButton(
                        tooltip: 'Settings',
                        onPressed: () =>
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 8, pad, 28),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _QuickAction(
                        icon: Icons.shuffle_rounded,
                        label: 'Shuffle library',
                        onTap: () => guarded(context, () async {
                          final songs = await session.client.getRandomSongs(
                            size: 200,
                            musicFolderId: session.libraryId,
                          );
                          await player.playSongs(songs);
                        }),
                      ),
                      _QuickAction(
                        icon: Icons.favorite_rounded,
                        label: 'Shuffle favorites',
                        onTap: () => guarded(context, () async {
                          final starred = await session.client.getStarred(musicFolderId: session.libraryId);
                          if (starred.songs.isEmpty) {
                            if (context.mounted) {
                              toast(context, 'No favorite songs yet — tap the heart on a song to add one.');
                            }
                            return;
                          }
                          await player.playSongs(starred.songs, shuffle: true);
                        }),
                      ),
                    ],
                  ),
                ),
                if (data.recent.isNotEmpty) _albumShelf('Recently played', data.recent),
                if (data.newest.isNotEmpty) _albumShelf('Recently added', data.newest),
                if (data.starred.isNotEmpty) _albumShelf('Favorite albums', data.starred),
                if (data.frequent.isNotEmpty) _albumShelf('Most played', data.frequent),
                if (data.random.isNotEmpty) _albumShelf('Rediscover', data.random),
                if (data.newest.isEmpty)
                  const EmptyState(
                    icon: Icons.library_music_outlined,
                    title: 'Your library is empty',
                    message: 'Add music to your Navidrome server and it will show up here.',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _albumShelf(String title, List<Album> albums) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Shelf(
      title: title,
      itemCount: albums.length,
      itemBuilder: (context, i) => AlbumCard(album: albums[i]),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
