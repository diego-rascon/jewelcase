import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../audio/player_controller.dart';
import '../state/favorites.dart';
import '../state/playlists.dart';
import '../state/session.dart';
import 'format.dart';
import 'navigation.dart';
import 'screens/album_detail_screen.dart';
import 'screens/artist_detail_screen.dart';
import 'screens/favorite_songs_screen.dart';
import 'screens/playlist_detail_screen.dart';
import 'theme.dart';

class MenuAction {
  const MenuAction(this.label, this.icon, this.onSelected);

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

void openAlbum(BuildContext context, String id) => context.read<NavController>().push(AlbumDetailScreen(albumId: id));

void openArtist(BuildContext context, String id) =>
    context.read<NavController>().push(ArtistDetailScreen(artistId: id));

/// Route name for a playlist's page, so the sidebar can tell which one is open.
String playlistRouteName(String id) => 'playlist/$id';

void openPlaylist(BuildContext context, Playlist p) =>
    context.read<NavController>().push(PlaylistDetailScreen(playlist: p), name: playlistRouteName(p.id));

/// Route name for the automatic Favorite songs playlist.
const favoriteSongsRouteName = 'playlist:favorites';

void openFavoriteSongs(BuildContext context) =>
    context.read<NavController>().push(const FavoriteSongsScreen(), name: favoriteSongsRouteName);

void toast(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}

/// Runs [action], reporting failures as a snackbar instead of crashing.
Future<void> guarded(BuildContext context, Future<void> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await action();
    if (success != null) messenger?.showSnackBar(SnackBar(content: Text(success)));
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('$e')));
  }
}

/// Shows [actions] as a popup menu at [globalPosition] in the wide layout, or
/// as a sheet sliding up from the bottom on phones, and runs the one picked.
Future<void> showActionMenu(BuildContext context, Offset globalPosition, List<MenuAction> actions) async {
  final selected = isWide(context)
      ? await _showPopupMenu(context, globalPosition, actions)
      : await _showActionSheet(context, actions);
  selected?.onSelected();
}

Future<MenuAction?> _showPopupMenu(BuildContext context, Offset globalPosition, List<MenuAction> actions) {
  // The menu is laid out in its navigator's overlay. Inside a section's nested
  // navigator that overlay doesn't start at the window origin (the sidebar sits
  // to its left), so the global position has to be made local to it.
  final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final local = overlay.globalToLocal(globalPosition);
  return showMenu<MenuAction>(
    context: context,
    position: RelativeRect.fromRect(local & const Size(1, 1), Offset.zero & overlay.size),
    items: [
      for (final a in actions)
        PopupMenuItem(
          value: a,
          height: 42,
          child: Row(children: [Icon(a.icon, size: 20), const SizedBox(width: 14), Text(a.label)]),
        ),
    ],
  );
}

/// On the root navigator, so the sheet covers the tab bar and mini player
/// rather than sliding up inside the current section.
Future<MenuAction?> _showActionSheet(BuildContext context, List<MenuAction> actions) =>
    showModalBottomSheet<MenuAction>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.paddingOf(context).bottom),
          children: [
            for (final a in actions)
              ListTile(leading: Icon(a.icon), title: Text(a.label), onTap: () => Navigator.pop(context, a)),
          ],
        ),
      ),
    );

/// "⋯" button that opens [actions] next to itself.
class MoreButton extends StatelessWidget {
  const MoreButton({super.key, required this.actions, this.icon = Icons.more_horiz_rounded});

  final List<MenuAction> Function() actions;
  final IconData icon;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'More',
    icon: Icon(icon),
    onPressed: () {
      final box = context.findRenderObject()! as RenderBox;
      unawaited(showActionMenu(context, box.localToGlobal(box.size.bottomLeft(Offset.zero)), actions()));
    },
  );
}

/// Adds right-click (desktop) and long-press (touch) menus to [child].
class ContextMenuRegion extends StatelessWidget {
  const ContextMenuRegion({super.key, required this.actions, required this.child});

  final List<MenuAction> Function() actions;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onSecondaryTapUp: (d) => showActionMenu(context, d.globalPosition, actions()),
    onLongPressStart: (d) => showActionMenu(context, d.globalPosition, actions()),
    child: child,
  );
}

MenuAction _favoriteAction(BuildContext context, String id, FavoriteKind kind) {
  final favs = context.read<FavoritesController>();
  final isFav = favs.isFavorite(id);
  return MenuAction(
    isFav ? 'Remove from favorites' : 'Add to favorites',
    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
    () => guarded(context, () => favs.toggle(id, kind)),
  );
}

List<MenuAction> songActions(BuildContext context, Song song, {List<MenuAction> extra = const []}) {
  final player = context.read<PlayerController>();
  return [
    MenuAction(
      'Play next',
      Icons.playlist_play_rounded,
      () => guarded(context, () => player.playNext([song]), success: 'Playing next'),
    ),
    MenuAction(
      'Add to queue',
      Icons.add_to_queue_rounded,
      () => guarded(context, () => player.addToQueue([song]), success: 'Added to queue'),
    ),
    MenuAction('Add to playlist…', Icons.playlist_add_rounded, () => showAddToPlaylist(context, [song.id])),
    _favoriteAction(context, song.id, FavoriteKind.song),
    if (song.albumId != null) MenuAction('Go to album', Icons.album_rounded, () => openAlbum(context, song.albumId!)),
    if (song.artistId != null)
      MenuAction('Go to artist', Icons.person_rounded, () => openArtist(context, song.artistId!)),
    ...extra,
  ];
}

/// [includePlay] adds Play and Shuffle, for places that don't already have
/// those as buttons.
List<MenuAction> albumActions(BuildContext context, Album album, {bool includePlay = true}) {
  final player = context.read<PlayerController>();
  final client = context.read<SessionController>().client;
  Future<List<Song>> songs() async => album.songs.isNotEmpty ? album.songs : (await client.getAlbum(album.id)).songs;
  void run(Future<void> Function(List<Song>) f, [String? done]) =>
      guarded(context, () async => f(await songs()), success: done);
  return [
    if (includePlay) ...[
      MenuAction('Play', Icons.play_arrow_rounded, () => run(player.playSongs)),
      MenuAction('Shuffle', Icons.shuffle_rounded, () => run((s) => player.playSongs(s, shuffle: true))),
    ],
    MenuAction('Play next', Icons.playlist_play_rounded, () => run(player.playNext, 'Playing next')),
    MenuAction('Add to queue', Icons.add_to_queue_rounded, () => run(player.addToQueue, 'Added to queue')),
    MenuAction(
      'Add to playlist…',
      Icons.playlist_add_rounded,
      () => guarded(context, () async {
        final list = await songs();
        if (context.mounted) await showAddToPlaylist(context, [for (final s in list) s.id]);
      }),
    ),
    _favoriteAction(context, album.id, FavoriteKind.album),
    if (album.artistId != null)
      MenuAction('Go to artist', Icons.person_rounded, () => openArtist(context, album.artistId!)),
  ];
}

List<MenuAction> artistActions(BuildContext context, Artist artist) => [
  MenuAction('Open', Icons.person_rounded, () => openArtist(context, artist.id)),
  _favoriteAction(context, artist.id, FavoriteKind.artist),
];

Future<String?> promptText(BuildContext context, {required String title, String hint = '', String action = 'Save'}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(action)),
      ],
    ),
  );
}

/// Asks for a name and creates an empty playlist.
Future<void> createPlaylist(BuildContext context) async {
  final playlists = context.read<PlaylistsController>();
  final name = await promptText(context, title: 'New playlist', hint: 'Playlist name', action: 'Create');
  if (name == null || name.isEmpty || !context.mounted) return;
  await guarded(context, () => playlists.create(name));
}

Future<void> showAddToPlaylist(BuildContext context, List<String> songIds) async {
  final client = context.read<SessionController>().client;
  final playlists = context.read<PlaylistsController>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final choice = await showModalBottomSheet<Object>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (context) => FutureBuilder(
      future: client.getPlaylists(),
      builder: (context, snap) {
        final lists = snap.data ?? const <Playlist>[];
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text('Add to playlist', style: Theme.of(context).textTheme.titleLarge),
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.add_rounded)),
                title: const Text('New playlist'),
                onTap: () => Navigator.pop(context, true),
              ),
              if (snap.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              for (final p in lists)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.queue_music_rounded)),
                  title: Text(p.name),
                  subtitle: Text(plural(p.songCount, 'song')),
                  onTap: () => Navigator.pop(context, p),
                ),
            ],
          ),
        );
      },
    ),
  );
  if (choice == null || !context.mounted) return;
  try {
    if (choice is Playlist) {
      await playlists.addSongs(choice.id, songIds);
      messenger?.showSnackBar(SnackBar(content: Text('Added to ${choice.name}')));
    } else {
      final name = await promptText(context, title: 'New playlist', hint: 'Playlist name', action: 'Create');
      if (name == null || name.isEmpty) return;
      await playlists.create(name, songIds: songIds);
      messenger?.showSnackBar(SnackBar(content: Text('Created $name')));
    }
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('$e')));
  }
}
