import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// One page of a [PagedList]: its items, and whether it is the last one.
typedef Page<T> = ({List<T> items, bool last});

/// Fetches the page of a [PagedList] that starts at [offset].
typedef PageFetcher<T> = Future<Page<T>> Function(int offset);

/// A list loaded a page at a time, e.g. as the user scrolls.
///
/// [reset] starts over, for instance after the sort or library changed:
/// pages requested before it are dropped when they arrive. After an error the
/// list stops until [retry], rather than re-requesting on every scroll event.
class PagedList<T> extends ChangeNotifier {
  PagedList(this._fetch);

  final PageFetcher<T> _fetch;
  final _items = <T>[];
  late final List<T> items = UnmodifiableListView(_items);

  bool _loading = false;
  bool _done = false;
  bool _loadsAll = false;
  bool _disposed = false;
  Object? _error;

  /// The page being loaded, so concurrent [loadMore] calls share it.
  Future<void>? _pending;

  /// Bumped by [reset] and [dispose], so responses to older requests are
  /// dropped.
  int _generation = 0;

  bool get isLoading => _loading;
  bool get isDone => _done;
  Object? get error => _error;

  /// Whether to keep loading pages until the end, for a view that can only
  /// show the list once it has all of it (such as one sorted locally).
  bool get loadsAll => _loadsAll;

  set loadsAll(bool value) {
    if (value == _loadsAll) return;
    _loadsAll = value;
    if (value) unawaited(loadMore());
  }

  /// Empties the list. Call [loadMore] to load it again.
  void reset() {
    _generation++;
    _items.clear();
    _pending = null;
    _loading = false;
    _done = false;
    _error = null;
    notifyListeners();
  }

  /// Loads the next page, unless the list is complete or stopped on an error.
  /// Never throws: a failure is kept in [error].
  Future<void> loadMore() {
    if (_disposed || _done || _error != null) return Future.value();
    return _pending ??= _loadPage();
  }

  /// Clears the error and loads the next page.
  void retry() {
    _error = null;
    unawaited(loadMore());
  }

  Future<void> _loadPage() async {
    final generation = _generation;
    _loading = true;
    notifyListeners();
    Page<T>? page;
    Object? error;
    try {
      page = await _fetch(_items.length);
    } catch (e) {
      error = e;
    }
    if (generation != _generation) return;
    _pending = null;
    _loading = false;
    if (page != null) {
      _items.addAll(page.items);
      _done = page.last;
    } else {
      _error = error;
    }
    notifyListeners();
    if (_loadsAll) await loadMore();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
