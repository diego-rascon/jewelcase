import 'package:material_ui/material_ui.dart';

import 'theme.dart';

enum Destination {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  search('Search', Icons.search_rounded, Icons.search_rounded),
  albums('Albums', Icons.album_outlined, Icons.album_rounded),
  artists('Artists', Icons.person_outline_rounded, Icons.person_rounded),
  playlists('Playlists', Icons.queue_music_outlined, Icons.queue_music_rounded),
  favorites('Favorites', Icons.favorite_border_rounded, Icons.favorite_rounded),

  /// Phone-only tab combining albums, artists and playlists.
  library('Library', Icons.library_music_outlined, Icons.library_music_rounded);

  const Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  static const sidebar = [home, search, albums, artists, playlists, favorites];
  static const tabs = [home, search, library, favorites];
}

/// Each destination keeps its own navigation stack so detail pages open
/// inside the content area, keeping the sidebar and player visible.
class NavController extends ChangeNotifier {
  final rootKey = GlobalKey<NavigatorState>();
  final _keys = {for (final d in Destination.values) d: GlobalKey<NavigatorState>()};

  Destination _selected = Destination.home;

  /// Which layout is on screen; decides how [_selected] maps onto it. Read
  /// from the window (same breakpoint as [isWide]) so it is also correct in
  /// event handlers that have no layout context.
  bool get _wide {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    return view == null || view.physicalSize.width / view.devicePixelRatio >= wideLayoutWidth;
  }

  Destination get current {
    final wide = _wide;
    if (!wide && const [Destination.albums, Destination.artists, Destination.playlists].contains(_selected)) {
      return Destination.library;
    }
    if (wide && _selected == Destination.library) return Destination.albums;
    return _selected;
  }

  /// Which tab the phone library view should open on.
  int get libraryTab => switch (_selected) {
    Destination.artists => 1,
    Destination.playlists => 2,
    _ => 0,
  };

  GlobalKey<NavigatorState> keyFor(Destination d) => _keys[d]!;

  void select(Destination d) {
    if (d == current) {
      keyFor(d).currentState?.popUntil((r) => r.isFirst);
    }
    _selected = d;
    notifyListeners();
  }

  /// Opens a page in the current section, closing full-screen overlays such as
  /// Now Playing first.
  void push(Widget page) {
    rootKey.currentState?.popUntil((r) => r.isFirst);
    keyFor(current).currentState?.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// Handles the system back gesture for the visible section.
  bool pop() {
    final nav = keyFor(current).currentState;
    if (nav == null || !nav.canPop()) return false;
    nav.pop();
    return true;
  }
}
