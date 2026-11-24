import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/models.dart';
import '../api/subsonic_client.dart';

enum FavoriteKind { song, album, artist }

/// Single source of truth for what is starred (across all libraries), so every
/// heart icon in the app stays in sync. Toggles are optimistic and roll back
/// on failure.
class FavoritesController extends ChangeNotifier {
  SubsonicClient? _client;
  final _ids = <String>{};

  void attach(SubsonicClient? client) {
    if (identical(client, _client)) return;
    _client = client;
    _ids.clear();
    notifyListeners();
    if (client != null) {
      unawaited(
        refresh().catchError((Object e) {
          debugPrint('Could not load favorites: $e');
          return const SearchResults();
        }),
      );
    }
  }

  bool isFavorite(String id) => _ids.contains(id);

  Future<SearchResults> refresh() async {
    final client = _client;
    if (client == null) return const SearchResults();
    final starred = await client.getStarred();
    _ids
      ..clear()
      ..addAll(starred.songs.map((s) => s.id))
      ..addAll(starred.albums.map((a) => a.id))
      ..addAll(starred.artists.map((a) => a.id));
    notifyListeners();
    return starred;
  }

  Future<void> toggle(String id, FavoriteKind kind) async {
    final client = _client;
    if (client == null) return;
    final wasFavorite = _ids.contains(id);
    wasFavorite ? _ids.remove(id) : _ids.add(id);
    notifyListeners();
    try {
      final args = (
        songId: kind == FavoriteKind.song ? id : null,
        albumId: kind == FavoriteKind.album ? id : null,
        artistId: kind == FavoriteKind.artist ? id : null,
      );
      if (wasFavorite) {
        await client.unstar(songId: args.songId, albumId: args.albumId, artistId: args.artistId);
      } else {
        await client.star(songId: args.songId, albumId: args.albumId, artistId: args.artistId);
      }
    } catch (e) {
      wasFavorite ? _ids.add(id) : _ids.remove(id);
      notifyListeners();
      rethrow;
    }
  }
}
