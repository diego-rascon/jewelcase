import 'package:flutter/foundation.dart';

import '../api/subsonic_client.dart';

/// Playlist changes go through here so every view showing playlists can
/// refetch: watch [revision] (e.g. as an `AsyncView` dependency).
class PlaylistsController extends ChangeNotifier {
  SubsonicClient? _client;
  int _revision = 0;

  int get revision => _revision;

  void attach(SubsonicClient? client) => _client = client;

  Future<void> create(String name, {List<String> songIds = const []}) =>
      _change((c) => c.createPlaylist(name, songIds: songIds));

  Future<void> addSongs(String playlistId, List<String> songIds) =>
      _change((c) => c.addToPlaylist(playlistId, songIds));

  Future<void> removeSong(String playlistId, int index) => _change((c) => c.removeFromPlaylist(playlistId, index));

  Future<void> delete(String playlistId) => _change((c) => c.deletePlaylist(playlistId));

  Future<void> _change(Future<void> Function(SubsonicClient client) action) async {
    final client = _client;
    if (client == null) return;
    await action(client);
    _revision++;
    notifyListeners();
  }
}
