import 'dart:async';
import 'dart:convert';

import 'package:jewelcase/state/session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _ok(Map<String, Object?> body) => http.Response(
  jsonEncode({
    'subsonic-response': {'status': 'ok', ...body},
  }),
  200,
);

/// A server reachable only on the given schemes; records every URL tried.
(SessionController, List<Uri>) _session({Set<String> reachable = const {'https'}}) {
  final tried = <Uri>[];
  final session = SessionController(
    httpClient: () => MockClient((req) async {
      tried.add(req.url);
      if (!reachable.contains(req.url.scheme)) throw http.ClientException('Connection refused', req.url);
      if (req.url.path.endsWith('/getMusicFolders')) {
        return _ok({
          'musicFolders': {
            'musicFolder': [
              {'id': 1, 'name': 'Music'},
              {'id': 2, 'name': 'Audiobooks'},
            ],
          },
        });
      }
      return _ok({});
    }),
  );
  return (session, tried);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('isLocalNetworkHost', () {
    test('accepts private, loopback, CGNAT and local names', () {
      for (final h in [
        'localhost',
        '127.0.0.1',
        '10.1.2.3',
        '172.16.0.1',
        '172.31.255.255',
        '192.168.1.10',
        '169.254.0.5',
        '100.101.102.103',
        'nas.local',
        'fd12::1',
        '::1',
      ]) {
        expect(isLocalNetworkHost(h), isTrue, reason: h);
      }
    });

    test('rejects public hosts', () {
      for (final h in ['music.example.com', '8.8.8.8', '172.32.0.1', '100.128.0.1', '2001:db8::1', '']) {
        expect(isLocalNetworkHost(h), isFalse, reason: h);
      }
    });
  });

  group('signIn', () {
    test('prefers HTTPS', () async {
      final (session, tried) = _session(reachable: {'https', 'http'});
      await session.signIn(url: '192.168.1.10:4533', username: 'jo', password: 'pw');
      expect(session.credentials!.baseUrl, 'https://192.168.1.10:4533');
      expect(tried.first.scheme, 'https');
    });

    test('falls back to HTTP on the local network', () async {
      final (session, _) = _session(reachable: {'http'});
      await session.signIn(url: '192.168.1.10:4533', username: 'jo', password: 'pw');
      expect(session.credentials!.baseUrl, 'http://192.168.1.10:4533');
    });

    test('never falls back to HTTP for public hosts', () async {
      final (session, tried) = _session(reachable: {'http'});
      await expectLater(
        session.signIn(url: 'music.example.com', username: 'jo', password: 'pw'),
        throwsA(isA<Exception>().having((e) => '$e', 'message', contains('http://'))),
      );
      expect(tried.map((u) => u.scheme), everyElement('https'));
      expect(session.isSignedIn, isFalse);
    });

    test('uses plain HTTP when asked to explicitly', () async {
      final (session, _) = _session(reachable: {'http'});
      await session.signIn(url: 'http://music.example.com', username: 'jo', password: 'pw');
      expect(session.credentials!.baseUrl, 'http://music.example.com');
    });

    test('stops at a server error such as a wrong password', () async {
      final tried = <Uri>[];
      final session = SessionController(
        httpClient: () => MockClient((req) async {
          tried.add(req.url);
          return http.Response(
            jsonEncode({
              'subsonic-response': {
                'status': 'failed',
                'error': {'code': 40, 'message': 'Wrong username or password'},
              },
            }),
            200,
          );
        }),
      );
      await expectLater(session.signIn(url: '10.0.0.2', username: 'jo', password: 'bad'), throwsA(isA<Exception>()));
      expect(tried, hasLength(1));
    });
  });

  test('persists the session and selected library across restarts', () async {
    final (session, _) = _session();
    await session.signIn(url: 'music.example.com', username: 'jo', password: 'pw');
    await session.selectLibrary('2');

    final (restored, _) = _session();
    await restored.restore();
    expect(restored.isSignedIn, isTrue);
    expect(restored.credentials!.username, 'jo');
    expect(restored.libraryId, '2');

    await restored.signOut();
    final (afterSignOut, _) = _session();
    await afterSignOut.restore();
    expect(afterSignOut.isSignedIn, isFalse);
    expect(afterSignOut.libraryId, isNull);
  });

  test('drops a library list that arrives after signing out', () async {
    final folders = Completer<http.Response>();
    final session = SessionController(
      httpClient: () => MockClient((req) async => req.url.path.endsWith('/getMusicFolders') ? folders.future : _ok({})),
    );
    await session.signIn(url: 'music.example.com', username: 'jo', password: 'pw');
    await session.signOut();
    folders.complete(
      _ok({
        'musicFolders': {
          'musicFolder': [
            {'id': 1, 'name': 'Music'},
            {'id': 2, 'name': 'Audiobooks'},
          ],
        },
      }),
    );
    await pumpEventQueue();
    expect(session.libraries, isEmpty);
  });
}
