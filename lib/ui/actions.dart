import 'dart:async';

import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import 'widgets/popup_menu.dart';

class MenuAction {
  const MenuAction(this.label, this.icon, this.onSelected);

  final String label;

  /// Leaves an empty slot in a popup menu when null, e.g. for the unchecked
  /// choices of a select.
  final IconData? icon;
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

/// Shows [message] in a snackbar, replacing the one on screen.
void toast(BuildContext context, String message) => _toast(ScaffoldMessenger.maybeOf(context), message);

// Takes the messenger rather than a context, so callers can look it up
// before an await.
void _toast(ScaffoldMessengerState? messenger, String message) => messenger
  ?..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

/// Runs [action], reporting failures as a snackbar instead of crashing.
Future<void> guarded(BuildContext context, Future<void> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await action();
    if (success != null) _toast(messenger, success);
  } catch (e) {
    _toast(messenger, '$e');
  }
}

/// Shows [actions] as a popup menu next to [anchor] (global coordinates) in
/// the wide layout, or as a sheet sliding up from the bottom on phones, and
/// runs the one picked.
Future<void> showActionMenu(BuildContext context, Rect anchor, List<MenuAction> actions) async {
  final selected = await pickMenuAction(context, anchor, actions);
  selected?.onSelected();
}

/// Shows [actions] like [showActionMenu] and returns the one picked without
/// running it. For selects, which mark the current choice with a check.
Future<MenuAction?> pickMenuAction(BuildContext context, Rect anchor, List<MenuAction> actions) =>
    isWide(context) ? showPopupMenu(context, anchor, actions) : _showActionSheet(context, actions);

/// On the root navigator, so the sheet covers the tab bar and mini player
/// rather than sliding up inside the current section.
Future<MenuAction?> _showActionSheet(BuildContext context, List<MenuAction> actions) =>
    showModalBottomSheet<MenuAction>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        // As in the popup, actions without an icon keep an empty slot when
        // others have one, so a select's labels stay aligned with its check.
        final slot = actions.any((a) => a.icon != null) ? const SizedBox(width: 24) : null;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.paddingOf(context).bottom),
            children: [
              for (final a in actions)
                ListTile(
                  leading: a.icon == null ? slot : Icon(a.icon),
                  title: Text(a.label),
                  onTap: () => Navigator.pop(context, a),
                ),
            ],
          ),
        );
      },
    );

/// "⋯" button that opens [actions] next to itself.
class MoreButton extends StatelessWidget {
  const MoreButton({super.key, required this.actions, this.icon = LucideIcons.ellipsis, this.size, this.color});

  final List<MenuAction> Function() actions;
  final IconData icon;

  /// `null` takes the ambient [IconButtonTheme]'s size.
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'More',
    iconSize: size,
    icon: Icon(icon, color: color),
    onPressed: () => unawaited(showActionMenu(context, globalRect(context), actions())),
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
    onSecondaryTapUp: (d) => showActionMenu(context, d.globalPosition & Size.zero, actions()),
    onLongPressStart: (d) => showActionMenu(context, d.globalPosition & Size.zero, actions()),
    child: child,
  );
}

MenuAction _favoriteAction(BuildContext context, String id, FavoriteKind kind) {
  final favs = context.read<FavoritesController>();
  final isFav = favs.isFavorite(id);
  return MenuAction(
    isFav ? 'Remove from favorites' : 'Add to favorites',
    isFav ? LucideIcons.starOff : LucideIcons.star,
    () => guarded(context, () => favs.toggle(id, kind)),
  );
}

List<MenuAction> songActions(BuildContext context, Song song, {List<MenuAction> extra = const []}) {
  final player = context.read<PlayerController>();
  return [
    MenuAction(
      'Play next',
      LucideIcons.listStart,
      () => guarded(context, () => player.playNext([song]), success: 'Playing next'),
    ),
    MenuAction(
      'Add to queue',
      LucideIcons.listEnd,
      () => guarded(context, () => player.addToQueue([song]), success: 'Added to queue'),
    ),
    MenuAction('Add to playlist…', LucideIcons.listPlus, () => showAddToPlaylist(context, [song.id])),
    _favoriteAction(context, song.id, FavoriteKind.song),
    if (song.albumId != null) MenuAction('Go to album', LucideIcons.disc3, () => openAlbum(context, song.albumId!)),
    if (song.artistId != null) MenuAction('Go to artist', LucideIcons.user, () => openArtist(context, song.artistId!)),
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
      MenuAction('Play', LucideIcons.play, () => run(player.playSongs)),
      MenuAction('Shuffle', LucideIcons.shuffle, () => run((s) => player.playSongs(s, shuffle: true))),
    ],
    MenuAction('Play next', LucideIcons.listStart, () => run(player.playNext, 'Playing next')),
    MenuAction('Add to queue', LucideIcons.listEnd, () => run(player.addToQueue, 'Added to queue')),
    MenuAction(
      'Add to playlist…',
      LucideIcons.listPlus,
      () => guarded(context, () async {
        final list = await songs();
        if (context.mounted) await showAddToPlaylist(context, [for (final s in list) s.id]);
      }),
    ),
    _favoriteAction(context, album.id, FavoriteKind.album),
    if (album.artistId != null)
      MenuAction('Go to artist', LucideIcons.user, () => openArtist(context, album.artistId!)),
  ];
}

List<MenuAction> artistActions(BuildContext context, Artist artist) => [
  MenuAction('Open', LucideIcons.user, () => openArtist(context, artist.id)),
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
  // Requested once: the sheet's builder reruns on resizes and keyboard changes.
  final request = client.getPlaylists();
  final choice = await showModalBottomSheet<Object>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (context) => FutureBuilder(
      future: request,
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
                leading: const CircleAvatar(child: Icon(LucideIcons.plus)),
                title: const Text('New playlist'),
                onTap: () => Navigator.pop(context, true),
              ),
              if (snap.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snap.hasError)
                ListTile(
                  leading: Icon(LucideIcons.cloudOff, color: Theme.of(context).colorScheme.error),
                  title: const Text('Couldn’t load your playlists'),
                  subtitle: Text('${snap.error}'),
                ),
              for (final p in lists)
                ListTile(
                  leading: const CircleAvatar(child: Icon(LucideIcons.listMusic)),
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
      _toast(messenger, 'Added to ${choice.name}');
    } else {
      final name = await promptText(context, title: 'New playlist', hint: 'Playlist name', action: 'Create');
      if (name == null || name.isEmpty) return;
      await playlists.create(name, songIds: songIds);
      _toast(messenger, 'Created $name');
    }
  } catch (e) {
    _toast(messenger, '$e');
  }
}
