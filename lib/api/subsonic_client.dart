import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class SubsonicException implements Exception {
  SubsonicException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => message;
}

/// Credentials in the form Subsonic token auth expects. The plain password is
/// never stored: only the salt and `md5(password + salt)` token are kept.
class ServerCredentials {
  const ServerCredentials({required this.baseUrl, required this.username, required this.salt, required this.token});

  final String baseUrl;
  final String username;
  final String salt;
  final String token;

  factory ServerCredentials.fromPassword({
    required String baseUrl,
    required String username,
    required String password,
  }) {
    final rnd = Random.secure();
    final salt = List.generate(12, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final token = md5.convert(utf8.encode(password + salt)).toString();
    return ServerCredentials(baseUrl: normalizeUrl(baseUrl), username: username, salt: salt, token: token);
  }

  static String normalizeUrl(String url) {
    var u = url.trim();
    if (!u.startsWith(RegExp(r'https?://'))) u = 'https://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Json toJson() => {'baseUrl': baseUrl, 'username': username, 'salt': salt, 'token': token};

  factory ServerCredentials.fromJson(Json j) => ServerCredentials(
    baseUrl: j['baseUrl'] as String,
    username: j['username'] as String,
    salt: j['salt'] as String,
    token: j['token'] as String,
  );
}

class SubsonicClient {
  SubsonicClient(this.credentials, {http.Client? httpClient}) : _http = httpClient ?? http.Client();

  static const _apiVersion = '1.16.1';
  static const _clientName = 'Jewelcase';

  /// Cover sizes requested from the server. Snapping every request to one of
  /// these means a cover is resized, downloaded and cached at most 3 times.
  static const coverSizes = [150, 400, 800];

  static int coverSizeFor(num pixels) => coverSizes.firstWhere((s) => pixels <= s, orElse: () => coverSizes.last);

  final ServerCredentials credentials;
  final http.Client _http;

  Map<String, String> get _authParams => {
    'u': credentials.username,
    't': credentials.token,
    's': credentials.salt,
    'v': _apiVersion,
    'c': _clientName,
    'f': 'json',
  };

  Uri _uri(String endpoint, [Map<String, Object?> params = const {}]) {
    final query = <String, dynamic>{..._authParams};
    params.forEach((key, value) {
      if (value == null) return;
      query[key] = value is Iterable ? value.map((e) => '$e').toList() : '$value';
    });
    return Uri.parse('${credentials.baseUrl}/rest/$endpoint').replace(queryParameters: query);
  }

  Future<Json> _get(String endpoint, [Map<String, Object?> params = const {}]) async {
    final http.Response res;
    try {
      res = await _http.get(_uri(endpoint, params)).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw SubsonicException('The server took too long to respond');
    } on http.ClientException catch (e) {
      // Not `$e`: its toString includes the request URL, which carries the auth token.
      throw SubsonicException('Could not reach the server (${e.message})');
    } on Exception {
      throw SubsonicException('Could not reach the server');
    }
    if (res.statusCode != 200) {
      throw SubsonicException('Server responded with HTTP ${res.statusCode}');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw SubsonicException('That does not look like a Navidrome/Subsonic server');
    }
    final body = decoded is Map ? decoded['subsonic-response'] : null;
    if (body is! Map) throw SubsonicException('Unexpected response from server');
    if (body['status'] != 'ok') {
      final err = body['error'] as Map?;
      throw SubsonicException(err?['message']?.toString() ?? 'Request failed', code: (err?['code'] as num?)?.toInt());
    }
    return body.cast<String, dynamic>();
  }

  // ---- URLs -------------------------------------------------------------

  Uri streamUrl(String songId) => _uri('stream', {'id': songId});

  /// Cover art URL for at least [size] pixels, snapped to [coverSizes]. Stable
  /// for a given session (fixed salt), so it is safe to use for image caching
  /// together with [coverCacheKey].
  String coverUrl(String coverArtId, {num size = 400}) =>
      _uri('getCoverArt', {'id': coverArtId, 'size': coverSizeFor(size)}).toString();

  String coverCacheKey(String coverArtId, num size) => '${credentials.baseUrl}|$coverArtId|${coverSizeFor(size)}';

  // ---- System -----------------------------------------------------------

  Future<void> ping() => _get('ping');

  Future<List<MusicFolder>> getMusicFolders() async {
    final r = await _get('getMusicFolders');
    return jsonList((r['musicFolders'] as Map?)?['musicFolder']).map(MusicFolder.fromJson).toList();
  }

  // ---- Browsing ---------------------------------------------------------
  //
  // `musicFolderId` limits results to one library; `null` means all of them.

  Future<List<Album>> getAlbumList(AlbumSort sort, {int size = 40, int offset = 0, String? musicFolderId}) async {
    final r = await _get('getAlbumList2', {
      'type': sort.apiValue,
      // A reversed range makes Navidrome list newest years first.
      if (sort == AlbumSort.byYear) ...{'fromYear': 9999, 'toYear': 0},
      'size': size,
      'offset': offset,
      'musicFolderId': musicFolderId,
    });
    return jsonList((r['albumList2'] as Map?)?['album']).map(Album.fromJson).toList();
  }

  /// One page of the albums tagged [genre].
  Future<List<Album>> getAlbumsByGenre(String genre, {int size = 40, int offset = 0, String? musicFolderId}) async {
    final r = await _get('getAlbumList2', {
      'type': 'byGenre',
      'genre': genre,
      'size': size,
      'offset': offset,
      'musicFolderId': musicFolderId,
    });
    return jsonList((r['albumList2'] as Map?)?['album']).map(Album.fromJson).toList();
  }

  /// Every album, in pages of [pageSize] (Navidrome's maximum), sorted by
  /// name so pages don't overlap.
  Future<List<Album>> getAllAlbums({String? musicFolderId, int pageSize = 500}) async {
    final albums = <Album>[];
    while (true) {
      final page = await getAlbumList(
        AlbumSort.alphabeticalByName,
        size: pageSize,
        offset: albums.length,
        musicFolderId: musicFolderId,
      );
      albums.addAll(page);
      if (page.length < pageSize) return albums;
    }
  }

  Future<Album> getAlbum(String id) async {
    final r = await _get('getAlbum', {'id': id});
    return Album.fromJson(r['album'] as Json);
  }

  /// Songs of several albums, in order. Fetches a few albums at a time so a
  /// large discography doesn't flood the server.
  Future<List<Song>> getSongsOfAlbums(List<String> albumIds, {int concurrency = 4}) async {
    final songs = <Song>[];
    for (var i = 0; i < albumIds.length; i += concurrency) {
      final batch = await Future.wait(albumIds.skip(i).take(concurrency).map(getAlbum));
      for (final album in batch) {
        songs.addAll(album.songs);
      }
    }
    return songs;
  }

  Future<List<Artist>> getArtists({String? musicFolderId}) async {
    final r = await _get('getArtists', {'musicFolderId': musicFolderId});
    final indexes = jsonList((r['artists'] as Map?)?['index']);
    return [for (final i in indexes) ...jsonList(i['artist']).map(Artist.fromJson)];
  }

  Future<Artist> getArtist(String id) async {
    final r = await _get('getArtist', {'id': id});
    return Artist.fromJson(r['artist'] as Json);
  }

  Future<ArtistInfo> getArtistInfo(String id) async {
    final r = await _get('getArtistInfo2', {'id': id, 'count': 12});
    return ArtistInfo.fromJson((r['artistInfo2'] as Json?) ?? const {});
  }

  Future<List<Song>> getTopSongs(String artistName, {int count = 10}) async {
    final r = await _get('getTopSongs', {'artist': artistName, 'count': count});
    return jsonList((r['topSongs'] as Map?)?['song']).map(Song.fromJson).toList();
  }

  Future<List<Song>> getRandomSongs({int size = 100, String? musicFolderId}) async {
    final r = await _get('getRandomSongs', {'size': size, 'musicFolderId': musicFolderId});
    return jsonList((r['randomSongs'] as Map?)?['song']).map(Song.fromJson).toList();
  }

  Future<SearchResults> search(String query, {String? musicFolderId}) async {
    final r = await _get('search3', {
      'query': query,
      'artistCount': 12,
      'albumCount': 18,
      'songCount': 30,
      'musicFolderId': musicFolderId,
    });
    return SearchResults.fromJson((r['searchResult3'] as Json?) ?? const {});
  }

  /// One page of every song. Subsonic has no "list songs" call; Navidrome
  /// answers an empty `search3` query with the whole library.
  Future<List<Song>> getSongs({int size = 100, int offset = 0, String? musicFolderId}) async {
    final r = await _get('search3', {
      'query': '',
      'artistCount': 0,
      'albumCount': 0,
      'songCount': size,
      'songOffset': offset,
      'musicFolderId': musicFolderId,
    });
    return SearchResults.fromJson((r['searchResult3'] as Json?) ?? const {}).songs;
  }

  // ---- Favorites --------------------------------------------------------

  Future<SearchResults> getStarred({String? musicFolderId}) async {
    final r = await _get('getStarred2', {'musicFolderId': musicFolderId});
    return SearchResults.fromJson((r['starred2'] as Json?) ?? const {});
  }

  Future<void> star({String? songId, String? albumId, String? artistId}) =>
      _get('star', {'id': songId, 'albumId': albumId, 'artistId': artistId});

  Future<void> unstar({String? songId, String? albumId, String? artistId}) =>
      _get('unstar', {'id': songId, 'albumId': albumId, 'artistId': artistId});

  // ---- Playlists --------------------------------------------------------

  Future<List<Playlist>> getPlaylists() async {
    final r = await _get('getPlaylists');
    return jsonList((r['playlists'] as Map?)?['playlist']).map(Playlist.fromJson).toList();
  }

  Future<Playlist> getPlaylist(String id) async {
    final r = await _get('getPlaylist', {'id': id});
    return Playlist.fromJson(r['playlist'] as Json);
  }

  Future<void> createPlaylist(String name, {List<String> songIds = const []}) =>
      _get('createPlaylist', {'name': name, 'songId': songIds});

  Future<void> addToPlaylist(String playlistId, List<String> songIds) =>
      _get('updatePlaylist', {'playlistId': playlistId, 'songIdToAdd': songIds});

  Future<void> removeFromPlaylist(String playlistId, int index) =>
      _get('updatePlaylist', {'playlistId': playlistId, 'songIndexToRemove': index});

  Future<void> deletePlaylist(String id) => _get('deletePlaylist', {'id': id});

  // ---- Playback reporting ----------------------------------------------

  Future<void> scrobble(String songId, {required bool submission}) => _get('scrobble', {
    'id': songId,
    'submission': submission,
    if (submission) 'time': DateTime.now().millisecondsSinceEpoch,
  });

  void close() => _http.close();
}
