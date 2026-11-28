import 'dart:async';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'theme.dart';

enum Destination {
  home('Home', LucideIcons.house),
  search('Search', LucideIcons.search),
  albums('Albums', LucideIcons.disc3),
  artists('Artists', LucideIcons.user),
  songs('Songs', LucideIcons.music),
  genres('Genres', LucideIcons.tags),
  playlists('Playlists', LucideIcons.listMusic),

  /// Phone-only tab combining albums, artists, songs and playlists.
  library('Library', LucideIcons.libraryBig);

  const Destination(this.label, this.icon);

  final String label;
  final IconData icon;

  static const tabs = [home, search, library];

  /// The phone library view's tabs, in order.
  static const libraryTabs = [albums, artists, songs, playlists];
}

/// Each destination keeps its own navigation stack so detail pages open
/// inside the content area, keeping the sidebar and player visible.
class NavController extends ChangeNotifier {
  final rootKey = GlobalKey<NavigatorState>();
  final _keys = {for (final d in Destination.values) d: GlobalKey<NavigatorState>()};
  late final _observers = {for (final d in Destination.values) d: _TopRouteObserver(_topChanged)};

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
    if (!wide && Destination.libraryTabs.contains(_selected)) return Destination.library;
    if (wide && _selected == Destination.library) return Destination.albums;
    return _selected;
  }

  /// Which tab the phone library view should open on.
  int get libraryTab => Destination.libraryTabs.indexOf(_selected).clamp(0, Destination.libraryTabs.length - 1);

  GlobalKey<NavigatorState> keyFor(Destination d) => _keys[d]!;

  NavigatorObserver observerFor(Destination d) => _observers[d]!;

  /// Route name of the page on top of the visible section, if it was pushed
  /// with one (see [push]).
  String? get topRouteName => _observers[current]!.name;

  bool _notifyScheduled = false;

  // Observers fire in the middle of a navigator update, so notify afterwards.
  void _topChanged() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  bool _queueOpen = false;

  /// Desktop: whether the queue sidebar is open (see `AppShell`).
  bool get queueOpen => _queueOpen;

  void toggleQueue() {
    _queueOpen = !_queueOpen;
    notifyListeners();
  }

  int _selections = 0;

  /// Counts picks from the sidebar or tabs ([select]), so a screen can tell
  /// it was just picked, even when its section was already showing.
  int get selections => _selections;

  void select(Destination d) {
    _selections++;
    if (d == current) {
      keyFor(d).currentState?.popUntil((r) => r.isFirst);
    }
    _selected = d;
    notifyListeners();
  }

  /// Opens a page in the current section, closing full-screen overlays such as
  /// Now Playing first. [name] identifies the page for [topRouteName].
  void push(Widget page, {String? name}) {
    rootKey.currentState?.popUntil((r) => r.isFirst);
    keyFor(current).currentState?.push(_route(page, name));
  }

  /// Switches to section [d] and shows [page] directly on top of its root
  /// screen, unless [name] is already on top there.
  void openIn(Destination d, Widget page, {required String name}) {
    rootKey.currentState?.popUntil((r) => r.isFirst);
    final alreadyOpen = d == current && topRouteName == name;
    _selected = d;
    notifyListeners();
    if (alreadyOpen) return;
    void show() {
      final nav = keyFor(d).currentState;
      if (nav == null) return;
      nav.popUntil((r) => r.isFirst);
      unawaited(nav.push(_route(page, name)));
    }

    // A section's navigator is only built on its first visit.
    if (keyFor(d).currentState != null) {
      show();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => show());
    }
  }

  static Route<void> _route(Widget page, String? name) => MaterialPageRoute<void>(
    settings: RouteSettings(name: name),
    builder: (_) => page,
  );

  /// Handles the system back gesture for the visible section.
  bool pop() {
    final nav = keyFor(current).currentState;
    if (nav == null || !nav.canPop()) return false;
    nav.pop();
    return true;
  }
}

/// Remembers the name of a navigator's top route.
class _TopRouteObserver extends NavigatorObserver {
  _TopRouteObserver(this._onChange);

  final VoidCallback _onChange;
  String? name;

  void _set(Route<dynamic>? top) {
    if (top?.settings.name == name) return;
    name = top?.settings.name;
    _onChange();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute?.isCurrent ?? false) _set(newRoute);
  }
}
