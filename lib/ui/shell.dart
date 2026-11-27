import 'dart:async';

import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../audio/player_controller.dart';
import '../state/playlists.dart';
import '../state/session.dart';
import 'actions.dart';
import 'navigation.dart';
import 'screens/albums_screen.dart';
import 'screens/artists_screen.dart';
import 'screens/favorite_songs_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/playlist_detail_screen.dart';
import 'screens/playlists_screen.dart';
import 'screens/queue_view.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/songs_screen.dart';
import 'theme.dart';
import 'widgets/async_view.dart';
import 'widgets/cover_art.dart';
import 'widgets/disc_logo.dart';
import 'widgets/frosted.dart';
import 'widgets/now_playing_bars.dart';
import 'widgets/side_panel.dart';

/// Adaptive app frame: sidebar + player bar (+ queue sidebar) on
/// desktop/tablet, bottom tabs + mini player on phones.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final wide = isWide(context);
    final hasSong = context.select<PlayerController, bool>((p) => p.current != null);

    final content = NavigatorPopHandler(
      onPopWithResult: (_) => nav.pop(),
      child: _Sections(current: nav.current),
    );

    return wide
        ? Scaffold(
            body: Row(
              children: [
                const _Sidebar(),
                Expanded(
                  child: ClipRect(child: PlayerBarHost(child: content)),
                ),
                SidePanel(
                  open: nav.queueOpen && hasSong && fitsQueueSidebar(context),
                  width: queueSidebarWidth,
                  child: const _QueueSidebar(),
                ),
              ],
            ),
          )
        // The mini player and the tab bar float over the content, which
        // scrolls under them so their blur has something to show. With
        // `extendBody`, the content's `MediaQuery` bottom padding covers both
        // (see `BottomInset`). The gaps around the mini player card don't
        // take hits, so taps there reach the content.
        : Scaffold(
            extendBody: true,
            body: content,
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                Frosted(
                  borderRadius: BorderRadius.zero,
                  edge: FrostedEdge.top,
                  child: NavigationBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    selectedIndex: Destination.tabs.indexOf(nav.current).clamp(0, Destination.tabs.length - 1),
                    onDestinationSelected: (i) => nav.select(Destination.tabs[i]),
                    destinations: [
                      for (final d in Destination.tabs) NavigationDestination(icon: Icon(d.icon), label: d.label),
                    ],
                  ),
                ),
              ],
            ),
          );
  }
}

/// Keeps one navigator per section alive (built on first visit) so switching
/// sections preserves scroll position and history.
class _Sections extends StatefulWidget {
  const _Sections({required this.current});

  final Destination current;

  @override
  State<_Sections> createState() => _SectionsState();
}

class _SectionsState extends State<_Sections> {
  final _visited = <Destination>{};

  static Widget _rootFor(Destination d) => switch (d) {
    Destination.home => const HomeScreen(),
    Destination.search => const SearchScreen(),
    Destination.albums => const AlbumsScreen(),
    Destination.artists => const ArtistsScreen(),
    Destination.songs => const SongsScreen(),
    Destination.playlists => const PlaylistsScreen(),
    Destination.library => const LibraryScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavController>();
    _visited.add(widget.current);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final d in Destination.values)
          if (_visited.contains(d))
            Offstage(
              offstage: d != widget.current,
              child: TickerMode(
                enabled: d == widget.current,
                child: HeroControllerScope.none(
                  child: Navigator(
                    key: nav.keyFor(d),
                    observers: [nav.observerFor(d)],
                    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _rootFor(d)),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final multipleLibraries = context.select<SessionController, bool>((s) => s.libraries.length > 1);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget item(Destination d) {
      final selected = nav.current == d;
      return _SidebarItem(selected: selected, onTap: () => nav.select(d), leading: Icon(d.icon), label: d.label);
    }

    // A Material (not a plain colored box) so the items can paint their ink.
    // One step lighter than the content, with a hairline edge between them.
    return Material(
      color: scheme.surfaceContainerLow,
      shape: Border(right: BorderSide(color: scheme.outlineVariant)),
      child: SizedBox(
        width: 232,
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
                child: Row(
                  children: [
                    const DiscLogo(size: 26),
                    const SizedBox(width: 10),
                    Text('Jewelcase', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              item(Destination.home),
              item(Destination.search),
              const _SidebarHeading('Library'),
              item(Destination.albums),
              item(Destination.artists),
              item(Destination.songs),
              _SidebarHeading(
                'Playlists',
                trailing: IconButton(
                  tooltip: 'New playlist',
                  visualDensity: VisualDensity.compact,
                  iconSize: IconSizes.small,
                  color: scheme.onSurfaceVariant,
                  onPressed: () => createPlaylist(context),
                  icon: const Icon(LucideIcons.plus),
                ),
              ),
              const Expanded(child: _SidebarPlaylists()),
              if (multipleLibraries)
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: LibraryPicker(dense: true)),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SidebarItem(
                  selected: false,
                  onTap: () => nav.push(const SettingsScreen()),
                  leading: const Icon(LucideIcons.settings),
                  label: 'Settings',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarHeading extends StatelessWidget {
  const _SidebarHeading(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 16, trailing == null ? 22 : 12, 4),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.selected, required this.onTap, required this.leading, required this.label});

  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String label;

  static const _radius = BorderRadius.all(Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: selected ? scheme.onSurface.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: _radius,
        child: InkWell(
          borderRadius: _radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                // Icons pick up the item's color and size; covers fill the box.
                IconTheme.merge(
                  data: IconThemeData(
                    size: IconSizes.small,
                    color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                  child: SizedBox.square(
                    dimension: IconSizes.medium,
                    child: Center(child: leading),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.82),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

/// Favorite songs followed by every playlist, each opening in the Playlists
/// section.
class _SidebarPlaylists extends StatelessWidget {
  const _SidebarPlaylists();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final client = context.read<SessionController>().client;
    // Refetch whenever a playlist is created, edited or deleted anywhere.
    final revision = context.select<PlaylistsController, int>((p) => p.revision);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final open = nav.current == Destination.playlists ? nav.topRouteName : null;
    final favorites = _SidebarItem(
      selected: open == favoriteSongsRouteName,
      onTap: () => nav.openIn(Destination.playlists, const FavoriteSongsScreen(), name: favoriteSongsRouteName),
      leading: FavoriteSongsScreen.cover(radius: 4),
      label: FavoriteSongsScreen.title,
    );
    return AsyncView<List<Playlist>>(
      deps: [revision],
      load: client.getPlaylists,
      // Too cramped for the full-page loading and error states; the
      // Playlists screen still reports errors.
      frame: (_) => Align(alignment: Alignment.topLeft, child: favorites),
      builder: (context, lists, _) => ListView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: lists.length + 1 + (lists.isEmpty ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == 0) return favorites;
          if (lists.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Text('No playlists yet', style: muted),
            );
          }
          final p = lists[i - 1];
          final name = playlistRouteName(p.id);
          return _SidebarItem(
            selected: open == name,
            onTap: () => nav.openIn(Destination.playlists, PlaylistDetailScreen(playlist: p), name: name),
            leading: CoverArt(id: p.coverArt, seed: p.id, radius: 4, icon: LucideIcons.listMusic),
            label: p.name,
          );
        },
      ),
    );
  }
}

/// Desktop: the queue along the right edge, toggled from the [PlayerBar].
/// The same material as [_Sidebar], mirrored.
class _QueueSidebar extends StatelessWidget {
  const _QueueSidebar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: Border(left: BorderSide(color: scheme.outlineVariant)),
      child: SafeArea(left: false, child: QueueView(onClose: context.read<NavController>().toggleQueue)),
    );
  }
}

/// Space = play/pause, Ctrl/⌘ + ←/→ = previous/next, plus hardware media
/// keys. Ignored while typing in a text field. Sits above the app navigator
/// so it also works on full-screen routes like Now Playing.
class PlaybackShortcuts extends StatelessWidget {
  const PlaybackShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused != null &&
            (focused.widget is EditableText || focused.findAncestorWidgetOfExactType<EditableText>() != null)) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        final mod = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
        if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.mediaPlayPause) {
          unawaited(guarded(context, player.togglePlay));
        } else if (key == LogicalKeyboardKey.mediaTrackNext || (mod && key == LogicalKeyboardKey.arrowRight)) {
          unawaited(guarded(context, player.next));
        } else if (key == LogicalKeyboardKey.mediaTrackPrevious || (mod && key == LogicalKeyboardKey.arrowLeft)) {
          unawaited(guarded(context, player.previous));
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
