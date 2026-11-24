import 'dart:convert';

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
}
