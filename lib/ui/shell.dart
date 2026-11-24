import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../audio/player_controller.dart';
import '../state/session.dart';
import 'navigation.dart';
import 'screens/albums_screen.dart';
import 'screens/artists_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/playlists_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';
import 'widgets/disc_logo.dart';
import 'widgets/now_playing_bars.dart';

/// Adaptive app frame: sidebar + player bar on desktop/tablet, bottom tabs +
/// mini player on phones.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final wide = isWide(context);

    final content = NavigatorPopHandler(
      onPopWithResult: (_) => nav.pop(),
      child: _Sections(current: nav.current),
    );

    return wide
        ? Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const _Sidebar(),
                      Expanded(child: ClipRect(child: content)),
                    ],
                  ),
                ),
                const PlayerBar(),
              ],
            ),
          )
        : Scaffold(
            body: Column(
              children: [
                Expanded(child: content),
                const MiniPlayer(),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: Destination.tabs.indexOf(nav.current).clamp(0, Destination.tabs.length - 1),
              onDestinationSelected: (i) => nav.select(Destination.tabs[i]),
              destinations: [
                for (final d in Destination.tabs)
                  NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
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
    Destination.playlists => const PlaylistsScreen(),
    Destination.favorites => const FavoritesScreen(),
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
    final session = context.watch<SessionController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget item(Destination d) {
      final selected = nav.current == d;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: selected ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => nav.select(d),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(
                    selected ? d.selectedIcon : d.icon,
                    size: 22,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    d.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 6),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.4, color: scheme.onSurfaceVariant),
      ),
    );

    // A Material (not a plain colored box) so list tiles can paint their ink.
    return Material(
      color: scheme.surfaceContainerLowest,
      child: SizedBox(
        width: 232,
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  children: [
                    const DiscLogo(size: 32),
                    const SizedBox(width: 12),
                    Text('Jewelcase', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              item(Destination.home),
              item(Destination.search),
              label('Your music'),
              item(Destination.albums),
              item(Destination.artists),
              item(Destination.playlists),
              item(Destination.favorites),
              const Spacer(),
              if (session.libraries.length > 1)
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: LibraryPicker(dense: true)),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  onTap: () => nav.push(const SettingsScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
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
          unawaited(player.togglePlay());
        } else if (key == LogicalKeyboardKey.mediaTrackNext || (mod && key == LogicalKeyboardKey.arrowRight)) {
          unawaited(player.next());
        } else if (key == LogicalKeyboardKey.mediaTrackPrevious || (mod && key == LogicalKeyboardKey.arrowLeft)) {
          unawaited(player.previous());
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
