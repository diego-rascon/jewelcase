import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';
import '../api/subsonic_client.dart';

/// Owns the connection to the Navidrome server and the selected library.
class SessionController extends ChangeNotifier {
  /// [httpClient] creates the HTTP client for each connection; tests pass a fake.
  SessionController({this._httpClient});

  static const _credentialsKey = 'jewelcase.credentials';
  static const _libraryKey = 'jewelcase.libraryId';

  final _secure = const FlutterSecureStorage();
  final http.Client Function()? _httpClient;

  SubsonicClient? _client;
  String? _libraryId;
  List<MusicFolder> _libraries = const [];
  bool _restoring = true;

  bool get isRestoring => _restoring;
  bool get isSignedIn => _client != null;
  SubsonicClient get client => _client!;
  ServerCredentials? get credentials => _client?.credentials;
  List<MusicFolder> get libraries => _libraries;

  /// The library browsing is limited to; `null` means all libraries.
  String? get libraryId => _libraryId;

  MusicFolder? get library {
    final id = libraryId;
    if (id == null) return null;
    for (final l in _libraries) {
      if (l.id == id) return l;
    }
    return null;
  }

  SubsonicClient _connect(ServerCredentials creds) => SubsonicClient(creds, httpClient: _httpClient?.call());

  Future<void> restore() async {
    try {
      final raw = await _secure.read(key: _credentialsKey);
      if (raw != null) {
        final creds = ServerCredentials.fromJson(jsonDecode(raw) as Json);
        final prefs = await SharedPreferences.getInstance();
        _client = _connect(creds);
        _libraryId = prefs.getString(_libraryKey);
        // Library list is a nice-to-have; don't block startup if offline.
        unawaited(_loadLibraries());
      }
    } catch (e) {
      debugPrint('Could not restore session: $e');
    }
    _restoring = false;
    notifyListeners();
  }

  /// Validates the credentials against the server, then persists them.
  /// Without an explicit scheme, tries HTTPS first. Only servers on the local
  /// network fall back to plain HTTP: anywhere else a failed HTTPS attempt
  /// could be an attacker forcing the token onto an unencrypted connection.
  Future<void> signIn({required String url, required String username, required String password}) async {
    final trimmed = url.trim();
    final explicit = trimmed.startsWith(RegExp(r'https?://'));
    final candidates = explicit
        ? [trimmed]
        : ['https://$trimmed', if (isLocalNetworkHost(Uri.tryParse('https://$trimmed')?.host ?? '')) 'http://$trimmed'];
    late SubsonicClient client;
    for (final (i, candidate) in candidates.indexed) {
      final creds = ServerCredentials.fromPassword(baseUrl: candidate, username: username, password: password);
      client = _connect(creds);
      final last = i == candidates.length - 1;
      try {
        await client.ping();
        break;
      } on SubsonicException catch (e) {
        client.close();
        // A Subsonic error code means we reached the server (e.g. bad password).
        if (e.code != null) rethrow;
        if (last) {
          if (explicit || candidates.length > 1) rethrow;
          throw SubsonicException('${e.message}. If your server only supports HTTP, enter its address with http://');
        }
      } catch (_) {
        client.close();
        if (last) rethrow;
      }
    }
    final creds = client.credentials;
    await _secure.write(key: _credentialsKey, value: jsonEncode(creds.toJson()));
    _client?.close();
    _client = client;
    notifyListeners();
    unawaited(_loadLibraries());
  }

  Future<void> signOut() async {
    await _secure.delete(key: _credentialsKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_libraryKey);
    _client?.close();
    _client = null;
    _libraryId = null;
    _libraries = const [];
    notifyListeners();
  }

  /// `null` means "all libraries".
  Future<void> selectLibrary(String? id) async {
    if (_client == null || id == _libraryId) return;
    _libraryId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_libraryKey);
    } else {
      await prefs.setString(_libraryKey, id);
    }
  }

  Future<void> _loadLibraries() async {
    final requested = _client;
    if (requested == null) return;
    try {
      final libraries = await requested.getMusicFolders();
      // Dropped if the user signed out or switched servers meanwhile.
      if (!identical(requested, _client)) return;
      _libraries = libraries;
      notifyListeners();
    } catch (e) {
      debugPrint('Could not load libraries: $e');
    }
  }
}

/// Whether [host] is on a local network: localhost, private / link-local /
/// carrier-grade NAT (e.g. Tailscale) IPv4 ranges, IPv6 ULA and link-local
/// addresses, or a local-only domain name.
bool isLocalNetworkHost(String host) {
  final h = host.toLowerCase();
  if (h == 'localhost' || h.endsWith('.local') || h.endsWith('.lan') || h.endsWith('.home.arpa')) return true;
  if (h.contains(':')) return h == '::1' || h.startsWith('fc') || h.startsWith('fd') || h.startsWith('fe80');
  final parts = h.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.any((p) => p == null || p < 0 || p > 255)) return false;
  final [a, b, _, _] = parts.cast<int>();
  return a == 10 ||
      a == 127 ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168) ||
      (a == 169 && b == 254) ||
      (a == 100 && b >= 64 && b <= 127);
}
