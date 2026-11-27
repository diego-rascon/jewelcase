import 'dart:convert';

import 'package:jewelcase/api/models.dart';
import 'package:jewelcase/api/subsonic_client.dart';
import 'package:jewelcase/audio/player_controller.dart';
import 'package:jewelcase/state/favorites.dart';
import 'package:jewelcase/state/playlists.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _creds = ServerCredentials(baseUrl: 'https://nd.test', username: 'jo', salt: 'abc', token: 'tok');

http.Response _ok([Map<String, Object?> body = const {}]) => http.Response(
  jsonEncode({
    'subsonic-response': {'status': 'ok', ...body},
  }),
  200,
);

http.Response _failed() => http.Response(
  jsonEncode({
    'subsonic-response': {
      'status': 'failed',
      'error': {'code': 50, 'message': 'Not allowed'},
    },
  }),
  200,
);

void main() {
  group('FavoritesController', () {
    test('loads starred ids and toggles optimistically', () async {
      final calls = <String>[];
      final favorites = FavoritesController();
      favorites.attach(
        SubsonicClient(
          _creds,
          httpClient: MockClient((req) async {
            calls.add(req.url.pathSegments.last);
            return _ok({
              'starred2': {
                'song': [
                  {'id': 's1', 'title': 'One'},
                ],
              },
            });
          }),
        ),
      );
      await favorites.refresh();
      expect(favorites.isFavorite('s1'), isTrue);

      final toggle = favorites.toggle('s1', FavoriteKind.song);
      expect(favorites.isFavorite('s1'), isFalse, reason: 'updated before the server answers');
      await toggle;
      expect(calls.last, 'unstar');
    });

    test('rolls back when the server rejects the change', () async {
      final favorites = FavoritesController()
        ..attach(SubsonicClient(_creds, httpClient: MockClient((req) async => _failed())));
      await expectLater(favorites.toggle('a1', FavoriteKind.album), throwsA(isA<SubsonicException>()));
      expect(favorites.isFavorite('a1'), isFalse);
    });

    test('survives failing to load at sign-in', () async {
      final favorites = FavoritesController();
      favorites.attach(
        SubsonicClient(_creds, httpClient: MockClient((req) async => throw http.ClientException('offline'))),
      );
      await Future<void>.delayed(Duration.zero);
      expect(favorites.isFavorite('x'), isFalse);
    });
  });

  group('PlaylistsController', () {
    test('bumps the revision after a successful change only', () async {
      var fail = false;
      final playlists = PlaylistsController()
        ..attach(SubsonicClient(_creds, httpClient: MockClient((req) async => fail ? _failed() : _ok())));
      var notified = 0;
      playlists.addListener(() => notified++);

      await playlists.create('Road trip');
      await playlists.removeSong('p1', 0);
      expect(playlists.revision, 2);

      fail = true;
      await expectLater(playlists.delete('p1'), throwsA(isA<SubsonicException>()));
      expect(playlists.revision, 2);
      expect(notified, 2);
    });
  });

  test('scrobbleThreshold: half the track, at most 4 minutes, never under 30 s', () {
    expect(scrobbleThreshold(const Duration(seconds: 29)), isNull);
    expect(scrobbleThreshold(const Duration(minutes: 3)), const Duration(seconds: 90));
    expect(scrobbleThreshold(const Duration(minutes: 20)), const Duration(minutes: 4));
  });

  group('unshuffledOrder', () {
    double id(double x) => x;

    test('carries on after the current song, then the unplayed ones before it', () {
      // Album tracks 0–9 played shuffled: 4 is on, 7 and 2 already played.
      expect(unshuffledOrder(<double>[9, 0, 5, 3, 8, 1, 6], id, 4), <double>[5, 6, 8, 9, 0, 1, 3]);
    });

    test('keeps songs queued with Play next right after the current one', () {
      expect(unshuffledOrder(<double>[7, 3.5, 5, 3.25], id, 3), <double>[3.25, 3.5, 5, 7]);
    });

    test('is empty for an empty queue', () {
      expect(unshuffledOrder(<double>[], id, 0), isEmpty);
    });
  });

  group('sortAlbums', () {
    final albums = [
      Album(id: 'a', name: 'beta', artist: 'Zed', year: 1999, created: DateTime(2024, 1, 1)),
      Album(id: 'b', name: 'Alpha', artist: 'amy', year: 2010, played: DateTime(2025, 6, 1)),
      Album(
        id: 'c',
        name: 'gamma',
        artist: 'Amy',
        year: 2001,
        created: DateTime(2025, 1, 1),
        played: DateTime(2025, 1, 1),
      ),
    ];
    List<String> ids(AlbumSort sort) => [for (final a in sortAlbums(albums, sort)) a.id];

    test('by title and artist, ignoring case', () {
      expect(ids(AlbumSort.alphabeticalByName), ['b', 'a', 'c']);
      // Same artist: oldest album first.
      expect(ids(AlbumSort.alphabeticalByArtist), ['c', 'b', 'a']);
    });

    test('by year, newest first', () => expect(ids(AlbumSort.byYear), ['b', 'c', 'a']));

    test('by date added and last played, missing dates last', () {
      expect(ids(AlbumSort.newest), ['c', 'a', 'b']);
      expect(ids(AlbumSort.recent), ['b', 'c', 'a']);
    });

    test('keeps the order for sorts with no local equivalent', () => expect(ids(AlbumSort.random), ['a', 'b', 'c']));
  });

  group('sortSongs', () {
    const songs = [
      Song(id: 'a', title: 'beta', artist: 'Zed', album: 'Two', track: 2, duration: Duration(seconds: 200)),
      Song(id: 'b', title: 'Alpha', artist: 'amy', album: 'one', track: 1, duration: Duration(seconds: 100)),
      Song(id: 'c', title: 'gamma', artist: 'Amy', album: 'One', track: 3, duration: Duration(seconds: 100)),
      Song(id: 'd', title: 'alpha', artist: 'Amy', album: 'One', track: 2, duration: Duration(seconds: 300)),
    ];
    List<String> ids(SongSortField field, {bool descending = false}) => [
      for (final (_, s) in sortSongs(songs, (field: field, descending: descending))) s.id,
    ];

    test('no sort keeps the order and positions', () {
      expect([for (final (i, s) in sortSongs(songs, null)) '$i${s.id}'], ['0a', '1b', '2c', '3d']);
    });

    test('by title, ignoring case, then artist', () => expect(ids(SongSortField.title), ['b', 'd', 'a', 'c']));

    test('by artist, then album track order', () => expect(ids(SongSortField.artist), ['b', 'd', 'c', 'a']));

    test('by album in track order', () => expect(ids(SongSortField.album), ['b', 'd', 'c', 'a']));

    test('descending reverses the order but ties keep theirs', () {
      expect(ids(SongSortField.duration), ['b', 'c', 'a', 'd']);
      expect(ids(SongSortField.duration, descending: true), ['d', 'a', 'b', 'c']);
    });

    test('keeps each song\'s original position', () {
      expect(
        [for (final (i, s) in sortSongs(songs, (field: SongSortField.title, descending: false))) '$i${s.id}'],
        ['1b', '3d', '0a', '2c'],
      );
    });
  });
}
