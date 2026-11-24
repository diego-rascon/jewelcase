import 'dart:convert';

import 'package:jewelcase/api/models.dart';
import 'package:jewelcase/api/subsonic_client.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _ok(Map<String, Object?> body) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'subsonic-response': {'status': 'ok', 'version': '1.16.1', ...body},
    }),
  ),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('ServerCredentials', () {
    test('derives a salted md5 token instead of keeping the password', () {
      final c = ServerCredentials.fromPassword(baseUrl: 'music.example.com/', username: 'jo', password: 'secret');
      expect(c.baseUrl, 'https://music.example.com');
      expect(c.token, md5.convert(utf8.encode('secret${c.salt}')).toString());
      expect(jsonEncode(c.toJson()), isNot(contains('secret')));
    });

    test('keeps an explicit http scheme and strips trailing slashes', () {
      expect(ServerCredentials.normalizeUrl(' http://10.0.0.2:4533// '), 'http://10.0.0.2:4533');
    });
  });

  group('SubsonicClient', () {
    const creds = ServerCredentials(baseUrl: 'https://nd.test', username: 'jo', salt: 'abc', token: 'tok');

    test('sends auth params and parses albums', () async {
      late Uri seen;
      final client = SubsonicClient(
        creds,
        httpClient: MockClient((req) async {
          seen = req.url;
          return _ok({
            'albumList2': {
              'album': [
                {'id': 'al1', 'name': 'Blue', 'artist': 'Joni', 'songCount': 10, 'duration': 2160, 'year': 1971},
              ],
            },
          });
        }),
      );

      final albums = await client.getAlbumList(AlbumSort.newest, size: 5, musicFolderId: '2');
      expect(seen.path, '/rest/getAlbumList2');
      expect(seen.queryParameters, containsPair('u', 'jo'));
      expect(seen.queryParameters, containsPair('t', 'tok'));
      expect(seen.queryParameters, containsPair('s', 'abc'));
      expect(seen.queryParameters, containsPair('f', 'json'));
      expect(seen.queryParameters, containsPair('type', 'newest'));
      expect(seen.queryParameters, containsPair('musicFolderId', '2'));
      expect(albums.single.name, 'Blue');
      expect(albums.single.duration, const Duration(minutes: 36));
    });

    test('repeats list params (e.g. songIdToAdd)', () async {
      late Uri seen;
      final client = SubsonicClient(
        creds,
        httpClient: MockClient((req) async {
          seen = req.url;
          return _ok({});
        }),
      );
      await client.addToPlaylist('p1', ['s1', 's2']);
      expect(seen.queryParametersAll['songIdToAdd'], ['s1', 's2']);
    });

    test('flattens artist indexes', () async {
      final client = SubsonicClient(
        creds,
        httpClient: MockClient(
          (_) async => _ok({
            'artists': {
              'index': [
                {
                  'name': 'A',
                  'artist': [
                    {'id': '1', 'name': 'ABBA', 'albumCount': 8},
                  ],
                },
                {
                  'name': 'B',
                  'artist': [
                    {'id': '2', 'name': 'Björk', 'starred': '2024-01-01T00:00:00Z'},
                  ],
                },
              ],
            },
          }),
        ),
      );
      final artists = await client.getArtists();
      expect(artists.map((a) => a.name), ['ABBA', 'Björk']);
      expect(artists.last.starred, isTrue);
    });

    test('surfaces Subsonic errors with their message', () async {
      final client = SubsonicClient(
        creds,
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'subsonic-response': {
                'status': 'failed',
                'error': {'code': 40, 'message': 'Wrong username or password'},
              },
            }),
            200,
          ),
        ),
      );
      expect(
        client.ping(),
        throwsA(isA<SubsonicException>().having((e) => e.message, 'message', 'Wrong username or password')),
      );
    });

    test('pages through all songs with an empty search', () async {
      late Uri seen;
      final client = SubsonicClient(
        creds,
        httpClient: MockClient((req) async {
          seen = req.url;
          return _ok({
            'searchResult3': {
              'song': {'id': 's1', 'title': 'Only one'},
            },
          });
        }),
      );
      final songs = await client.getSongs(size: 50, offset: 100, musicFolderId: '2');
      expect(seen.path, '/rest/search3');
      expect(seen.queryParameters, containsPair('query', ''));
      expect(seen.queryParameters, containsPair('songCount', '50'));
      expect(seen.queryParameters, containsPair('songOffset', '100'));
      expect(seen.queryParameters, containsPair('albumCount', '0'));
      expect(seen.queryParameters, containsPair('musicFolderId', '2'));
      expect(songs.single.title, 'Only one');
    });

    test('leaves out the library filter when none is selected', () async {
      late Uri seen;
      final client = SubsonicClient(
        creds,
        httpClient: MockClient((req) async {
          seen = req.url;
          return _ok({'albumList2': {}});
        }),
      );
      await client.getAlbumList(AlbumSort.newest);
      expect(seen.queryParameters.containsKey('musicFolderId'), isFalse);
    });

    test('sorts by year newest first, with a year range only for that sort', () async {
      late Uri seen;
      final client = SubsonicClient(
        creds,
        httpClient: MockClient((req) async {
          seen = req.url;
          return _ok({'albumList2': {}});
        }),
      );
      await client.getAlbumList(AlbumSort.byYear);
      expect(seen.queryParameters, containsPair('type', 'byYear'));
      expect(seen.queryParameters, containsPair('fromYear', '9999'));
      expect(seen.queryParameters, containsPair('toYear', '0'));

      await client.getAlbumList(AlbumSort.newest);
      expect(seen.queryParameters.containsKey('fromYear'), isFalse);
    });

    test('keeps the auth token out of connection error messages', () async {
      final client = SubsonicClient(
        creds,
        httpClient: MockClient((req) async => throw http.ClientException('Connection refused', req.url)),
      );
      await expectLater(
        client.ping(),
        throwsA(
          isA<SubsonicException>()
              .having((e) => e.message, 'message', contains('Connection refused'))
              .having((e) => e.message, 'message', isNot(contains('tok'))),
        ),
      );
    });

    test('snaps cover sizes to a few buckets', () {
      final client = SubsonicClient(creds);
      expect(Uri.parse(client.coverUrl('c1', size: 88)).queryParameters['size'], '150');
      expect(Uri.parse(client.coverUrl('c1', size: 380)).queryParameters['size'], '400');
      expect(Uri.parse(client.coverUrl('c1', size: 3000)).queryParameters['size'], '800');
      expect(client.coverCacheKey('c1', 300), client.coverCacheKey('c1', 400));
    });

    test('fetches songs of many albums in order, a few at a time', () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final client = SubsonicClient(
        creds,
        httpClient: MockClient((req) async {
          final id = req.url.queryParameters['id']!;
          inFlight++;
          maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          inFlight--;
          return _ok({
            'album': {
              'id': id,
              'name': id,
              'song': [
                {'id': '$id-1', 'title': 'one'},
                {'id': '$id-2', 'title': 'two'},
              ],
            },
          });
        }),
      );
      final ids = [for (var i = 0; i < 10; i++) 'a$i'];
      final songs = await client.getSongsOfAlbums(ids, concurrency: 3);
      expect(songs.map((s) => s.id), [
        for (final id in ids) ...['$id-1', '$id-2'],
      ]);
      expect(maxInFlight, 3);
    });

    test('rejects non-Subsonic servers clearly', () async {
      final client = SubsonicClient(creds, httpClient: MockClient((_) async => http.Response('<html>', 200)));
      expect(client.ping(), throwsA(isA<SubsonicException>()));
    });
  });

  test('ArtistInfo strips Last.fm markup from bios', () {
    final info = ArtistInfo.fromJson({
      'biography': 'Great band. <a target="_blank" href="https://last.fm/x">Read more on Last.fm</a>',
    });
    expect(info.biography, 'Great band.');
  });
}
